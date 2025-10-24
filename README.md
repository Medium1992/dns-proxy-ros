# Minimal Docker Image from AdGuard DNSProxy

This repository builds a minimal Docker image from https://github.com/AdguardTeam/dnsproxy for popular CPU architectures

## 🧩 Usage Example

All available CMD arguments are described in the official documentation https://github.com/AdguardTeam/dnsproxy?tab=readme-ov-file#usage

### Example 1 — fastest_addr mode and many servers DoH
CMD
```bash
--cache --ipv6-disabled --upstream https://dns.google/dns-query --upstream https://cloudflare-dns.com/dns-query --upstream https://dns.quad9.net/dns-query --upstream-mode=fastest_addr
```

> **Description**: The fastest_addr mode returns the IP address of the resource whose resolver responds the fastest. However, it may take slightly longer overall since the proxy waits for responses from all specified DNS servers before selecting the fastest one.

### Example 2 — parallel mode
CMD
```bash
--cache --ipv6-disabled --upstream https://dns.google/dns-query --upstream https://cloudflare-dns.com/dns-query --upstream https://dns.quad9.net/dns-query --upstream-mode=parallel
```

> **Description**: The parallel mode queries all specified DNS servers simultaneously and returns the fastest response to the client.

### Install on Mikrotik RouterOS

1. Create a container interface
```bash
/interface/veth/add name=dnsproxy address=192.168.255.14/30 gateway=192.168.255.13
```
2. Assign the interface address to MikroTik
```bash
/ip/address/add address=192.168.255.13/30 interface=dnsproxy
```
3. Pull and run the container
```bash
/container/add remote-image="ghcr.io/medium1992/dns-proxy-ros" interface=dnsproxy cmd="--cache --ipv6-disabled --upstream https://dns.google/dns-query --upstream https://cloudflare-dns.com/dns-query --upstream https://dns.quad9.net/dns-query --upstream-mode=parallel" root-dir=Containers/dnsproxy dns=192.168.89.13 start-on-boot=yes
```
or
```bash
/container/add remote-image="registry-1.docker.io/medium1992/dns-proxy-ros" interface=dnsproxy cmd="--cache --ipv6-disabled --upstream https://dns.google/dns-query --upstream https://cloudflare-dns.com/dns-query --upstream https://dns.quad9.net/dns-query --upstream-mode=parallel" root-dir=Containers/dnsproxy dns=192.168.89.13 start-on-boot=yes
```
> **Note**: You need to add a rule in the IP → Firewall → Filter Rules section and make sure it is positioned above the rule that blocks traffic in chain "input".
```bash
/ip/firewall/filter/add chain=input in-interface=dnsproxy protocol=udp dst-port=53
```