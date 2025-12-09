FROM --platform=linux/amd64 golang:alpine AS build-linux-amd64
FROM --platform=linux/arm64 golang:alpine AS build-linux-arm64
FROM --platform=linux/arm/v7 golang:alpine AS build-linux-armv7
FROM --platform=linux/arm/v6 golang:alpine AS build-linux-armv6
FROM --platform=linux/arm/v5 debian:trixie-slim AS build-linux-armv5

FROM build-${TARGETOS}-${TARGETARCH}${TARGETVARIANT} AS build

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
        "linux/amd64" | "linux/arm64") \
            apk add --no-cache curl ca-certificates ;; \
        "linux/arm/v7" | "linux/arm/v6") \
            mkdir -p /usr/bin /usr/sbin && \
            ln -sf /bin/busybox /usr/bin/busybox && \
            ln -sf /bin/busybox /usr/sbin/busybox && \
            apk add --no-cache curl ca-certificates || \
            (echo "Trigger failed, forcing busybox symlinks" && \
             /bin/busybox --install -s && \
             apk add --no-cache curl ca-certificates) ;; \
        "linux/arm/v5") \
            apt update && apt install -y curl ca-certificates && apt clean -y && rm -rf /var/lib/apt/lists/* ;; \
        *) echo "Unsupported platform for package installation: $TARGETPLATFORM"; exit 1 ;; \
    esac && \
    curl -sSL "https://github.com/AdguardTeam/dnsproxy/releases/download/${VERSION}/dnsproxy-linux-${ARCH}-${VERSION}.tar.gz" | \
    tar -xz -C /tmp && \
    mv /tmp/linux-${ARCH}/dnsproxy /dnsproxy
RUN mkdir -p /final
RUN mkdir -p /final/etc/ssl/certs
RUN mv /dnsproxy /final/dnsproxy
RUN mv /etc/ssl/certs/ca-certificates.crt /final/etc/ssl/certs/ca-certificates.crt
COPY hosts /final/hosts
RUN chmod +x /final/dnsproxy

FROM scratch
COPY --from=build /final /
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENTRYPOINT ["/dnsproxy"]
