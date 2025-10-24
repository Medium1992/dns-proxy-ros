FROM alpine:latest AS builder

# Install apk
RUN apk add --no-cache curl ca-certificates

# Introduce ARGs
ARG VERSION
ARG TARGETARCH
ARG TARGETVARIANT

# Get orginal binary AdguardTeam/dnsproxy
RUN case "${TARGETARCH}${TARGETVARIANT}" in \
    amd64) ARCH="amd64" ;; \
    arm64) ARCH="arm64" ;; \
    armv7) ARCH="arm7" ;; \
    armv6) ARCH="arm6" ;; \
    armv5) ARCH="arm5" ;; \
    *) echo "Unsupported architecture: ${TARGETARCH}${TARGETVARIANT}"; exit 1 ;; \
    esac && \
    curl -sSL "https://github.com/AdguardTeam/dnsproxy/releases/download/${VERSION}/dnsproxy-linux-${ARCH}-${VERSION}.tar.gz" | \
    tar -xz -C /tmp && \
    mv /tmp/linux-${ARCH}/dnsproxy /dnsproxy && \
    chmod +x /dnsproxy

# Final
FROM scratch
COPY --from=builder /dnsproxy /dnsproxy
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENTRYPOINT ["/dnsproxy"]