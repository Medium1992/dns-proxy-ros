# Базовый образ для сборки (нужен для скачивания и распаковки)
FROM alpine:latest AS builder

# Устанавливаем необходимые утилиты
RUN apk add --no-cache curl ca-certificates

# Указываем аргументы версии и архитектуры
ARG VERSION
ARG TARGETARCH
ARG TARGETVARIANT

# Определяем URL архива в зависимости от архитектуры
# Для arm/v7 используем arm7, для arm64 — arm64, для amd64 — amd64
RUN case "${TARGETARCH}${TARGETVARIANT}" in \
    amd64) ARCH="amd64" ;; \
    arm64) ARCH="arm64" ;; \
    armv7) ARCH="arm7" ;; \
    *) echo "Unsupported architecture: ${TARGETARCH}${TARGETVARIANT}"; exit 1 ;; \
    esac && \
    curl -sSL "https://github.com/AdguardTeam/dnsproxy/releases/download/${VERSION}/dnsproxy-linux-${ARCH}-${VERSION}.tar.gz" | \
    tar -xz -C /tmp && \
    mv /tmp/linux-${ARCH}/dnsproxy /dnsproxy && \
    chmod +x /dnsproxy

# Финальный образ на базе scratch
FROM scratch

# Копируем бинарник из builder
COPY --from=builder /dnsproxy /dnsproxy
# Копируем CA-сертификаты, установленные в builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
# Устанавливаем переменную окружения для явного указания пути (опционально, но надёжнее)
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
# Указываем точку входа
ENTRYPOINT ["/dnsproxy"]