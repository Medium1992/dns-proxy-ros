[English](/README.md) | [Russian](/README_RU.md)

# dns-proxy-ros

Minimal multi-architecture Docker image built from the official [AdGuard dnsproxy](https://github.com/AdguardTeam/dnsproxy) release binary, packaged for MikroTik RouterOS containers.

The image is `FROM scratch` and contains only three files: the `dnsproxy` binary, a CA bundle, and a `hosts` file with the IP addresses of the popular DoH resolvers. The upstream version currently tracked is recorded in [`VERSIONS`](./VERSIONS).

[![Docker Pulls](https://img.shields.io/docker/pulls/medium1992/dns-proxy-ros?logo=docker&label=docker%20pulls)](https://hub.docker.com/r/medium1992/dns-proxy-ros)
[![Docker Image Size](https://img.shields.io/docker/image-size/medium1992/dns-proxy-ros/latest?logo=docker&label=image%20size)](https://hub.docker.com/r/medium1992/dns-proxy-ros)
[![License](https://img.shields.io/github/license/Medium1992/dns-proxy-ros)](./LICENSE)
![Platforms](https://img.shields.io/badge/arch-amd64%20%7C%20arm64%20%7C%20armv7%20%7C%20armv6%20%7C%20armv5-blue)

## Features

- Multi-architecture images: `amd64`, `arm64`, `arm/v7`, `arm/v6`, `arm/v5`.
- `FROM scratch` — no shell, no package manager, no OS layer.
- CA bundle included, so DoH and DoT upstreams validate correctly out of the box.
- Bundled `/hosts` file resolves the DoH hostnames without a bootstrap resolver, which avoids a DNS loop when the container is the router's own upstream.
- A daily workflow rebuilds and republishes the image when AdGuard publishes a new dnsproxy release.

## Image tags

Images are published to `ghcr.io/medium1992/dns-proxy-ros` and `medium1992/dns-proxy-ros`.

| Tag | Purpose |
|---|---|
| `latest` | Latest image built for this project. |
| `vX.Y.Z` | Image built from the matching upstream dnsproxy release tag. |

Pin `vX.Y.Z` in production; RouterOS re-pulls `latest` on container restart, which can change the binary under you unexpectedly.

## Bundled `/hosts`

| Hostname | Addresses |
|---|---|
| `dns.google` | `8.8.8.8`, `8.8.4.4` |
| `cloudflare-dns.com` | `104.16.248.249`, `104.16.249.249` |
| `dns.quad9.net` | `9.9.9.9`, `149.112.112.112` |
| `dns10.quad9.net` (unfiltered) | `9.9.9.10`, `149.112.112.10` |
| `dns.adguard-dns.com` (ad blocking) | `94.140.14.14`, `94.140.15.15` |
| `unfiltered.adguard-dns.com` | `94.140.14.140`, `94.140.14.141` |
| `dns.mullvad.net` | `194.242.2.2` |

Pass it with `--hosts-files=/hosts`. The alternative is `--bootstrap 9.9.9.9`, which lets dnsproxy resolve the DoH hostnames itself — use one or the other, not neither, or the container has no way to reach its own upstreams.

The file is a static snapshot of anycast addresses. It exists so you can switch `--upstream` between these providers without touching the image; if a provider ever moves, that entry goes stale and `--bootstrap` is the fix.

## Usage

All CLI arguments are documented upstream: <https://github.com/AdguardTeam/dnsproxy#usage>

### Example 1 — `fastest_addr` mode

```bash
--cache --ipv6-disabled --hosts-files=/hosts \
  --upstream https://dns.google/dns-query \
  --upstream https://cloudflare-dns.com/dns-query \
  --upstream https://dns.quad9.net/dns-query \
  --upstream-mode=fastest_addr
```

Returns the IP address of the host that answers fastest. Overall latency can be slightly higher, because the proxy waits for all upstreams before picking a winner.

### Example 2 — `parallel` mode

```bash
--cache --ipv6-disabled --hosts-files=/hosts \
  --upstream https://dns.google/dns-query \
  --upstream https://cloudflare-dns.com/dns-query \
  --upstream https://dns.quad9.net/dns-query \
  --upstream-mode=parallel
```

Queries all upstreams simultaneously and returns the first response received.

### Plain Docker

```bash
docker run -d --name dnsproxy -p 53:53/udp -p 53:53/tcp \
  ghcr.io/medium1992/dns-proxy-ros:latest \
  --cache --ipv6-disabled --hosts-files=/hosts \
  --upstream https://dns.google/dns-query \
  --upstream-mode=parallel
```

## RouterOS installation

Container support must be enabled first:

```routeros
/system/device-mode/print
/system/device-mode/update mode=advanced container=yes
```

Confirm the change by power-cycling the device or pressing its physical reset button when prompted.

1. Create a veth interface:

```routeros
/interface/veth/add name=dnsproxy address=192.168.255.14/30 gateway=192.168.255.13
```

2. Give the router an address on that link:

```routeros
/ip/address/add address=192.168.255.13/30 interface=dnsproxy
```

3. Pull and run the container:

```routeros
/container/add remote-image="ghcr.io/medium1992/dns-proxy-ros:latest" interface=dnsproxy cmd="--cache --ipv6-disabled --hosts-files=/hosts --upstream https://dns.google/dns-query --upstream https://cloudflare-dns.com/dns-query --upstream https://dns.quad9.net/dns-query --upstream-mode=parallel" root-dir=Containers/dnsproxy dns=192.168.89.13 start-on-boot=yes
```

or, from Docker Hub:

```routeros
/container/add remote-image="registry-1.docker.io/medium1992/dns-proxy-ros:latest" interface=dnsproxy cmd="--cache --ipv6-disabled --hosts-files=/hosts --upstream https://dns.google/dns-query --upstream https://cloudflare-dns.com/dns-query --upstream https://dns.quad9.net/dns-query --upstream-mode=parallel" root-dir=Containers/dnsproxy dns=192.168.89.13 start-on-boot=yes
```

Replace `dns=192.168.89.13` with the address the container should use to resolve its upstream hostnames — usually the router itself.

4. Allow DNS traffic from the container interface. The rule must sit **above** the drop rule in the `input` chain:

```routeros
/ip/firewall/filter/add chain=input in-interface=dnsproxy protocol=udp dst-port=53
```

### Using the container as the router's upstream

If MikroTik should resolve through the container, add static records for the DoH hostnames first — otherwise the container asks the router, the router asks the container, and the lookup loops.

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

## Building locally

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/arm/v5 \
  --build-arg VERSION=v0.84.1 \
  -t dns-proxy-ros:local .
```

`VERSION` is required and must be an existing tag of [AdguardTeam/dnsproxy](https://github.com/AdguardTeam/dnsproxy/releases). The binary is downloaded on the build host's architecture, so no QEMU emulation is needed.

## License

The files in this repository are MIT-licensed — see [LICENSE](./LICENSE). The `dnsproxy` binary shipped inside the image is distributed by AdGuard under the [Apache-2.0](https://github.com/AdguardTeam/dnsproxy/blob/master/LICENSE) license.
