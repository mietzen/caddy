# Custom Caddy Docker Image

A customized Caddy web server Docker image with additional plugins and utilities for dynamic DNS management and OPNsense integration.

## Features

### Caddy Plugins
- **caddy-docker-proxy/v2** - Docker container discovery and proxy configuration
- **caddy-dns/porkbun** - Porkbun DNS provider for ACME DNS challenges
- **caddy-dynamicdns** - Dynamic DNS updates
- **caddy-events-exec** - Execute commands on Caddy events
- **caddy-dynamicdns-cmd-source** - Custom dynamic DNS command source

### Additional Tools
- **curl** - HTTP client for API calls
- **jq** - JSON processor for API responses
- **ca-certificates** - SSL certificate bundle

### Custom Scripts
- **add_host_override** - OPNsense Unbound DNS host override management
- **export_secrets** - Docker secrets to environment variables converter

## Usage

### Basic Docker Run
```bash
docker run -d \
  --name caddy-custom \
  -p 80:80 -p 443:443 \
  -v caddy_data:/data \
  -v caddy_config:/config \
  your-registry/caddy-custom:latest
```

### Docker Compose with Secrets
```yaml
services:
  caddy:
    image: your-registry/caddy-custom:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - caddy_data:/data
      - caddy_config:/config
      - ./Caddyfile:/etc/caddy/Caddyfile
    secrets:
      - opnsense_api_key
      - opnsense_api_secret
      - porkbun_api_key

secrets:
  opnsense_api_key:
    external: true
  opnsense_api_secret:
    external: true
  porkbun_api_key:
    external: true

volumes:
  caddy_data:
  caddy_config:
```

## OPNsense Integration

The `add_host_override` script manages DNS host overrides in OPNsense Unbound DNS resolver.

### Required Environment Variables
- `OPNSENSE_API_KEY` - OPNsense API key
- `OPNSENSE_API_SECRET` - OPNsense API secret
- `OPNSENSE_INSECURE=true` - Optional: Skip SSL verification for self-signed certificates

### Usage Example
```bash
add_host_override opnsense.local.domain example.com 192.168.1.100
```

This creates a DNS override for `example.com` pointing to `192.168.1.100` via the OPNsense API.

## Dynamic DNS Configuration

Example Caddyfile snippet for dynamic DNS with Porkbun:
```
example.com {
    tls {
        dns porkbun {env.PORKBUN_API_KEY} {env.PORKBUN_SECRET_API_KEY}
    }
    
    dynamic_dns {
        domains {
            example.com subdomain.example.com
        }
        resolver 1.1.1.1
        interval 300s
        cmd_source /usr/sbin/add_host_override opnsense.example.com {domain} {ip}
    }
    
    reverse_proxy backend:8080
}
```

## Secrets Management

The container automatically exports Docker secrets from `/run/secrets/` as uppercase environment variables at startup. For example:
- `/run/secrets/opnsense_api_key` → `OPNSENSE_API_KEY`
- `/run/secrets/porkbun_secret` → `PORKBUN_SECRET`
