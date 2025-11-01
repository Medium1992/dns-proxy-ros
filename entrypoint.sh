#!/bin/sh

cat > /hosts <<'HOSTS'
8.8.8.8         dns.google
8.8.4.4         dns.google
1.1.1.1         cloudflare-dns.com
1.0.0.1         cloudflare-dns.com
9.9.9.9         dns.quad9.net
149.112.112.112 dns.quad9.net
HOSTS

exec /dnsproxy ${CMD}