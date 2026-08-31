[English](/README.md) | [Russian](/README_RU.md)

# dns-proxy-ros

Минимальный мультиархитектурный Docker-образ на основе официального релизного бинаря [AdGuard dnsproxy](https://github.com/AdguardTeam/dnsproxy), собранный для контейнеров MikroTik RouterOS.

Образ собирается `FROM scratch` и содержит всего три файла: бинарь `dnsproxy`, набор корневых сертификатов и файл `hosts` с адресами популярных DoH-резолверов. Актуальная отслеживаемая версия апстрима записана в [`VERSIONS`](./VERSIONS).

[![Docker Pulls](https://img.shields.io/docker/pulls/medium1992/dns-proxy-ros?logo=docker&label=docker%20pulls)](https://hub.docker.com/r/medium1992/dns-proxy-ros)
[![Docker Image Size](https://img.shields.io/docker/image-size/medium1992/dns-proxy-ros/latest?logo=docker&label=image%20size)](https://hub.docker.com/r/medium1992/dns-proxy-ros)
[![License](https://img.shields.io/github/license/Medium1992/dns-proxy-ros)](./LICENSE)
![Platforms](https://img.shields.io/badge/arch-amd64%20%7C%20arm64%20%7C%20armv7%20%7C%20armv6%20%7C%20armv5-blue)

## Возможности

- Мультиарх: `amd64`, `arm64`, `arm/v7`, `arm/v6`, `arm/v5`.
- `FROM scratch` — ни шелла, ни пакетного менеджера, ни слоя ОС.
- Внутри лежат корневые сертификаты, поэтому DoH- и DoT-апстримы проходят проверку TLS «из коробки».
- Встроенный `/hosts` резолвит имена DoH-серверов без bootstrap-резолвера — это снимает петлю, когда контейнер сам является апстримом роутера.
- Ежедневный workflow пересобирает и публикует образ, как только AdGuard выпускает новый релиз dnsproxy.

## Теги образа

Образы публикуются в `ghcr.io/medium1992/dns-proxy-ros` и `medium1992/dns-proxy-ros`.

| Тег | Назначение |
|---|---|
| `latest` | Последний собранный образ проекта. |
| `vX.Y.Z` | Образ, собранный из одноимённого релиза dnsproxy. |

В продакшене лучше фиксировать `vX.Y.Z`: RouterOS перетягивает `latest` при рестарте контейнера, и бинарь может смениться неожиданно.

## Встроенный `/hosts`

| Хост | Адреса |
|---|---|
| `dns.google` | `8.8.8.8`, `8.8.4.4` |
| `cloudflare-dns.com` | `104.16.248.249`, `104.16.249.249` |
| `dns.quad9.net` | `9.9.9.9`, `149.112.112.112` |
| `dns10.quad9.net` (без фильтрации) | `9.9.9.10`, `149.112.112.10` |
| `dns.adguard-dns.com` (блокировка рекламы) | `94.140.14.14`, `94.140.15.15` |
| `unfiltered.adguard-dns.com` | `94.140.14.140`, `94.140.14.141` |
| `dns.mullvad.net` | `194.242.2.2` |

Подключается флагом `--hosts-files=/hosts`. Альтернатива — `--bootstrap 9.9.9.9`, тогда dnsproxy резолвит DoH-хосты сам. Нужно что-то одно из двух: без этого контейнеру нечем достучаться до собственных апстримов.

Файл — статический снимок anycast-адресов. Он нужен, чтобы переключать `--upstream` между этими провайдерами, не трогая образ; если провайдер сменит адреса, запись протухнет — лечится флагом `--bootstrap`.

## Примеры запуска

Все аргументы описаны в документации апстрима: <https://github.com/AdguardTeam/dnsproxy#usage>

### Пример 1 — режим `fastest_addr`

```bash
--cache --ipv6-disabled --hosts-files=/hosts \
  --upstream https://dns.google/dns-query \
  --upstream https://cloudflare-dns.com/dns-query \
  --upstream https://dns.quad9.net/dns-query \
  --upstream-mode=fastest_addr
```

Возвращает IP того хоста, который ответил быстрее всех. Общая задержка может быть чуть выше: прокси дожидается ответов от всех апстримов, прежде чем выбрать лучший.

### Пример 2 — режим `parallel`

```bash
--cache --ipv6-disabled --hosts-files=/hosts \
  --upstream https://dns.google/dns-query \
  --upstream https://cloudflare-dns.com/dns-query \
  --upstream https://dns.quad9.net/dns-query \
  --upstream-mode=parallel
```

Опрашивает все апстримы одновременно и отдаёт первый пришедший ответ.

### Обычный Docker

```bash
docker run -d --name dnsproxy -p 53:53/udp -p 53:53/tcp \
  ghcr.io/medium1992/dns-proxy-ros:latest \
  --cache --ipv6-disabled --hosts-files=/hosts \
  --upstream https://dns.google/dns-query \
  --upstream-mode=parallel
```

## Установка в RouterOS

Сначала нужно включить поддержку контейнеров:

```routeros
/system/device-mode/print
/system/device-mode/update mode=advanced container=yes
```

Подтвердите изменение перезагрузкой по питанию или физической кнопкой на устройстве.

1. Создаём veth-интерфейс:

```routeros
/interface/veth/add name=dnsproxy address=192.168.255.14/30 gateway=192.168.255.13
```

2. Назначаем адрес роутеру на этом линке:

```routeros
/ip/address/add address=192.168.255.13/30 interface=dnsproxy
```

3. Скачиваем и запускаем контейнер:

```routeros
/container/add remote-image="ghcr.io/medium1992/dns-proxy-ros:latest" interface=dnsproxy cmd="--cache --ipv6-disabled --hosts-files=/hosts --upstream https://dns.google/dns-query --upstream https://cloudflare-dns.com/dns-query --upstream https://dns.quad9.net/dns-query --upstream-mode=parallel" root-dir=Containers/dnsproxy dns=192.168.89.13 start-on-boot=yes
```

или из Docker Hub:

```routeros
/container/add remote-image="registry-1.docker.io/medium1992/dns-proxy-ros:latest" interface=dnsproxy cmd="--cache --ipv6-disabled --hosts-files=/hosts --upstream https://dns.google/dns-query --upstream https://cloudflare-dns.com/dns-query --upstream https://dns.quad9.net/dns-query --upstream-mode=parallel" root-dir=Containers/dnsproxy dns=192.168.89.13 start-on-boot=yes
```

`dns=192.168.89.13` замените на адрес, через который контейнер будет резолвить имена своих апстримов — обычно это сам роутер.

4. Разрешаем DNS-трафик с интерфейса контейнера. Правило должно стоять **выше** запрещающего правила в цепочке `input`:

```routeros
/ip/firewall/filter/add chain=input in-interface=dnsproxy protocol=udp dst-port=53
```

### Контейнер как апстрим самого роутера

Если MikroTik должен резолвить через контейнер, сначала добавьте статические записи для DoH-хостов — иначе контейнер спросит роутер, роутер спросит контейнер, и запрос зациклится.

```routeros
/ip dns static
add address=8.8.8.8 comment="DNS Google" name=dns.google type=A
add address=8.8.4.4 comment="DNS Google" name=dns.google type=A
add address=104.16.248.249 comment="DNS CloudFlare" name=cloudflare-dns.com type=A
add address=104.16.249.249 comment="DNS CloudFlare" name=cloudflare-dns.com type=A
add address=9.9.9.9 comment="DNS Quad9" name=dns.quad9.net type=A
add address=149.112.112.112 comment="DNS Quad9" name=dns.quad9.net type=A
/ip/dns/set servers=192.168.255.14
```

## Локальная сборка

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/arm/v5 \
  --build-arg VERSION=v0.84.1 \
  -t dns-proxy-ros:local .
```

`VERSION` обязателен и должен быть существующим тегом [AdguardTeam/dnsproxy](https://github.com/AdguardTeam/dnsproxy/releases). Бинарь скачивается на архитектуре хоста сборки, поэтому эмуляция QEMU не требуется.

## Лицензия

Здесь две лицензии на две разные вещи.

Файлы этого репозитория — Dockerfile, workflow, `hosts`, документация — это собственная работа, они под MIT: см. [LICENSE](./LICENSE).

Бинарь `dnsproxy` внутри образа — работа AdGuard, распространяется без изменений под [Apache-2.0](https://github.com/AdguardTeam/dnsproxy/blob/master/LICENSE) (`Copyright 2020 Adguard Software Ltd`). Apache-2.0 — пермиссивная лицензия, она не требует, чтобы этот репозиторий тоже был под ней, но пункт 4(a) требует, чтобы копия лицензии распространялась вместе с бинарём. Эта копия — [`LICENSE-dnsproxy`](./LICENSE-dnsproxy), и она же лежит внутри образа по пути `/LICENSE-dnsproxy`.
