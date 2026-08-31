# Бинарь dnsproxy уже собран апстримом под каждую платформу, поэтому качаем его
# на архитектуре раннера (BUILDPLATFORM) и не гоняем QEMU ради curl + tar.
FROM --platform=$BUILDPLATFORM alpine:latest AS build

ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETVARIANT
ARG VERSION

RUN apk add --no-cache ca-certificates curl tar

WORKDIR /tmp

RUN set -eu; \
    if [ -z "${VERSION:-}" ]; then echo "VERSION build-arg is required"; exit 1; fi; \
    echo "Building for platform: ${TARGETPLATFORM} (dnsproxy ${VERSION})"; \
    case "${TARGETARCH}${TARGETVARIANT}" in \
        amd64)  ARCH="amd64" ;; \
        arm64)  ARCH="arm64" ;; \
        arm64v8) ARCH="arm64" ;; \
        armv7)  ARCH="arm7" ;; \
        armv6)  ARCH="arm6" ;; \
        armv5)  ARCH="arm5" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}${TARGETVARIANT}"; exit 1 ;; \
    esac; \
    mkdir -p /final/etc/ssl/certs; \
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 \
        "https://github.com/AdguardTeam/dnsproxy/releases/download/${VERSION}/dnsproxy-linux-${ARCH}-${VERSION}.tar.gz" \
        | tar -xz -C /tmp; \
    mv "/tmp/linux-${ARCH}/dnsproxy" /final/dnsproxy; \
    chmod +x /final/dnsproxy; \
    cp /etc/ssl/certs/ca-certificates.crt /final/etc/ssl/certs/ca-certificates.crt

COPY hosts /final/hosts

# Apache-2.0 §4(a): распространяя бинарь, обязаны положить рядом копию лицензии.
COPY LICENSE-dnsproxy /final/LICENSE-dnsproxy

FROM scratch

ARG VERSION

LABEL org.opencontainers.image.title="dns-proxy-ros" \
      org.opencontainers.image.description="Minimal AdGuard dnsproxy image for MikroTik RouterOS containers" \
      org.opencontainers.image.source="https://github.com/Medium1992/dns-proxy-ros" \
      org.opencontainers.image.url="https://github.com/Medium1992/dns-proxy-ros" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.licenses="Apache-2.0"

COPY --from=build /final /

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

EXPOSE 53/udp 53/tcp

ENTRYPOINT ["/dnsproxy"]
