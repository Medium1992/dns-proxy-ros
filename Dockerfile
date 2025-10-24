FROM --platform=linux/amd64 alpine:latest AS builder-amd64
FROM --platform=linux/arm64 alpine:latest AS builder-arm64
FROM --platform=linux/arm/v7 alpine:latest AS builder-armv7
FROM --platform=linux/arm/v6 debian:trixie-slim AS builder-armv6
FROM --platform=linux/arm/v5 debian:trixie-slim AS builder-armv5

FROM builder-${TARGETOS}-${TARGETARCH}${TARGETVARIANT} AS builder

ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETOS
ARG TARGETVARIANT
ARG VERSION

WORKDIR /tmp

RUN echo "Building for platform: $TARGETPLATFORM" && \
    case "${TARGETARCH}${TARGETVARIANT}" in \
        amd64) ARCH="amd64" ;; \
        arm64) ARCH="arm64" ;; \
        armv7) ARCH="arm7" ;; \
        armv6) ARCH="arm6" ;; \
        armv5) ARCH="arm5" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}${TARGETVARIANT}"; exit 1 ;; \
    esac && \
    case "${TARGETPLATFORM}" in \
        "linux/amd64" | "linux/arm64" | "linux/arm/v7") \
            apk add --no-cache curl ca-certificates ;; \
        "linux/arm/v6" | "linux/arm/v5") \
            apt update && apt install -y curl ca-certificates && apt clean -y && rm -rf /var/lib/apt/lists/* ;; \
        *) echo "Unsupported platform for package installation: $TARGETPLATFORM"; exit 1 ;; \
    esac && \
    curl -sSL "https://github.com/AdguardTeam/dnsproxy/releases/download/${VERSION}/dnsproxy-linux-${ARCH}-${VERSION}.tar.gz" | \
    tar -xz -C /tmp && \
    mv /tmp/linux-${ARCH}/dnsproxy /dnsproxy && \
    chmod +x /dnsproxy

FROM scratch

COPY --from=builder /dnsproxy /dnsproxy
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENTRYPOINT ["/dnsproxy"]