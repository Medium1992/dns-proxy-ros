# Minimal Docker Image from AdGuard DNSProxy

This repository builds a minimal Docker image from https://github.com/AdguardTeam/dnsproxy for popular CPU architectures

## 🧩 Usage Example

All available CMD arguments are described in the official documentation https://github.com/AdguardTeam/dnsproxy?tab=readme-ov-file#usage

### Example 1 — fastest_addr mode and many servers DoH

```bash
--cache --ipv6-disabled --upstream https://dns.google/dns-query --upstream https://cloudflare-dns.com/dns-query --upstream https://dns.quad9.net/dns-query --upstream-mode=fastest_addr
```

> **Description**: The fastest_addr mode returns the IP address of the resource whose resolver responds the fastest. However, it may take slightly longer overall since the proxy waits for responses from all specified DNS servers before selecting the fastest one.

### Example 2 — parallel mode

```bash
--cache --ipv6-disabled --upstream https://dns.google/dns-query --upstream https://cloudflare-dns.com/dns-query --upstream https://dns.quad9.net/dns-query --upstream-mode=parallel
```

> **Description**: The parallel mode queries all specified DNS servers simultaneously and returns the fastest response to the client.