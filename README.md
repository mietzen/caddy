# Custom Caddy Docker Image

My customized Caddy Docker image with additional plugins for Docker service discovery, OPNsense local DNS management and Porkbun ACME integration.

...asciinema demo...

## Caddy Plugins

- [**caddy-dns-opnsense**](https://github.com/mietzen/caddy-dns-opnsense) - Update OPNsense local DNS overrides
- [**caddy-dns/porkbun**](https://github.com/caddy-dns/porkbun) - Porkbun DNS provider for ACME DNS challenges
- [**caddy-docker-proxy/v2**](https://github.com/lucaslorentz/caddy-docker-proxy) - Docker container discovery and proxy configuration
- [**caddy-dynamicdns**](https://github.com/mholt/caddy-dynamicdns) - Dynamic DNS updates
- [**libdns-opnsense-dnsmasq**](https://github.com/mietzen/libdns-opnsense-dnsmasq) - Dnsmasq DNS override provider
- [**libdns-opnsense-unbound**](https://github.com/mietzen/libdns-opnsense-unbound) - Unbound DNS override provider

## Example

First we need to setup a OPNsense API User, look at the [docs of caddy-dns-opnsense](https://github.com/mietzen/caddy-dns-opnsense?tab=readme-ov-file#setting-up-opnsense-api-keys) on how to do that.

Now we create a docker compose file like this:

```yaml
services:
  caddy:
    image: mietzen/caddy:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - caddy_data:/caddy/data
      # - ./Caddyfile:/etc/caddy/Caddyfile # Optional if you need custom server settings
      # - ./conf.d/:/caddy/conf.d/ # Optional if you want to add server configs
    environment:
      ACME_EMAIL: 'contact@example.com'
      BASE_DOMAIN: 'example.com'
      DOCKER_HOST_IP: '192.168.42.23'
      OPNSENSE_DNS_SERVICE: 'dnsmasq' # or 'unbound'
      OPNSENSE_HOSTNAME: 'opnsense' # you can add a port like 'opnsense:8443' or use a IP '192.168.42.1:8443' but it must be a https backend!
      OPNSENSE_INSECURE: 'true' # If your OPNsense instance uses a self signed cert
    networks:
      - caddy
    secrets:
      - opnsense_api_key
      - opnsense_api_secret_key
      - porkbun_api_key
      - porkbun_api_secret_key

secrets:
  opnsense_api_key:
    file: ./secrets/opnsense_api_key
  opnsense_api_secret_key:
    file: ./secrets/opnsense_api_secret_key
  porkbun_api_key:
    file: ./secrets/porkbun_api_key
  porkbun_api_secret_key:
    file: ./secrets/porkbun_api_secret_key

volumes:
  caddy_data:

networks:
  caddy:
    driver: bridge
```

start it with `docker compose up -d`

Now you can create another docker compose stacks with a service you want to expose:

```yaml
services:
  whoami1:
    image: traefik/whoami
    networks:
      - caddy
    deploy:
      labels:
        caddy: whoami1.example.com
        caddy.reverse_proxy: "{{upstreams 80}}"
        # remove the following line when you have verified your setup
        # Otherwise you risk being rate limited by let's encrypt
        caddy.tls.ca: https://acme-staging-v02.api.letsencrypt.org/directory
```

and start it with `docker compose up -d`.

You will get a letsencrypt TLS cert and a OPNsense host override entry, so when you visit [whoami1.example.com](https://whoami1.example.com) you will be directed to `192.168.42.23`.


## Advanced Options

If you need some advanced options here are some hints

### Change default `caddy` configuration

The default `Caddyfile` sits in `/etc/caddy/Caddyfile` and contains:

```caddy
{
	dynamic_dns {
		provider opnsense {
			host {env.OPNSENSE_HOSTNAME}
			api_key {file./run/secrets/opnsense_api_key}
			api_secret_key {file./run/secrets/opnsense_api_secret_key}
			dns_service {env.OPNSENSE_DNS_SERVICE}
			insecure {env.OPNSENSE_INSECURE}
		}
		domains {env.BASE_DOMAIN}
		dynamic_domains
		ip_source static {env.DOCKER_HOST_IP}
		check_interval 5m
		ttl 1h
	}
	email {env.ACME_EMAIL}
	acme_dns porkbun {
		api_key {file./run/secrets/porkbun_api_key}
		api_secret_key {file./run/secrets/porkbun_api_secret_key}
	}
	storage file_system {
		root /caddy/data
	}
	log caddy {
		output file /caddy/data/logs/caddy.log {
			roll_size 10MiB
			roll_local_time
			roll_keep 5
			roll_keep_for 336h
		}
		format console {
			time_local
			time_format wall
		}
		level INFO
	}
}

import /caddy/conf.d/*.caddy
```

You can overwrite it using:

```yaml
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
```

### Change default `docker-proxy` configuration

The docker file entrypoint is `["caddy", "docker-proxy"]`

We can use the `command` attribute to add advanced customizations to `docker-proxy`:

```yaml
services:
  caddy:
  ...
  command: >
  --polling-interval 10s
  --label-prefix my_custom_prefix
```

Here is a overview of all options:

```shell
# caddy docker-proxy -h
Run caddy as a docker proxy

Usage:
  caddy docker-proxy <command> [flags]

Flags:
      --caddyfile-path string              Path to a base Caddyfile that will be extended with docker sites
      --controller-network string          Network allowed to configure caddy server in CIDR notation. Ex: 10.200.200.0/24
      --docker-apis-version string         Docker socket apis version comma separate
      --docker-certs-path string           Docker socket certs path comma separate
      --docker-sockets string              Docker sockets comma separate
      --envfile string                     Environment file with environment variables in the KEY=VALUE format
      --event-throttle-interval duration   Interval to throttle caddyfile updates triggered by docker events (default 100ms)
  -h, --help                               help for docker-proxy
      --ingress-networks string            Comma separated name of ingress networks connecting caddy servers to containers.
                                           When not defined, networks attached to controller container are considered ingress networks
      --label-prefix string                Prefix for Docker labels (default "caddy")
      --mode string                        Which mode this instance should run: standalone | controller | server (default "standalone")
      --polling-interval duration          Interval caddy should manually check docker for a new caddyfile (default 30s)
      --process-caddyfile                  Process Caddyfile before loading it, removing invalid servers (default true)
      --proxy-service-tasks                Proxy to service tasks instead of service load balancer (default true)
      --scan-stopped-containers            Scan stopped containers and use its labels for caddyfile generation
```

Checkout [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) for more information.
