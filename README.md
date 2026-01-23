# Caddy Docker Image

My customized Caddy Docker image with additional plugins for Docker service discovery, OPNsense local DNS management and Porkbun ACME integration.

...asciinema demo...

## Caddy Plugins

- [**caddy-dns-opnsense**](https://github.com/mietzen/caddy-dns-opnsense) - Update OPNsense local DNS overrides
- [**caddy-dns/porkbun**](https://github.com/caddy-dns/porkbun) - Porkbun DNS provider for ACME DNS challenges
- [**caddy-docker-proxy/v2**](https://github.com/lucaslorentz/caddy-docker-proxy) - Docker container discovery and proxy configuration
- [**caddy-dynamicdns**](https://github.com/mholt/caddy-dynamicdns) - Dynamic DNS updates
- [**libdns-opnsense-dnsmasq**](https://github.com/mietzen/libdns-opnsense-dnsmasq) - Dnsmasq DNS override provider
- [**libdns-opnsense-unbound**](https://github.com/mietzen/libdns-opnsense-unbound) - Unbound DNS override provider

## Perquisite: Obtaining a OPNsense API keys

1. Create a new API-User under **System** -> **Access** -> **Users**
    - Set `Scrambled Password` to `True` and make sure `Login shell` is `None`

        <img width="600" alt="OPNsense user create dialog" src="https://github.com/user-attachments/assets/7d574600-5f8b-401e-89a8-3fa5c67e18b5" />

      - Set the Permissions for Dnsmasq to: `Services: Dnsmasq DNS/DHCP: Settings`

         <img width="500" alt="OPNsense user permissions setting for Dnsmasq" src="https://github.com/user-attachments/assets/902d0c5e-d6fa-4254-ad56-2bc4e76b3582" />

      - Set the Permissions for Unbound to: `Services: Unbound (MVC)` & `Services: Unbound DNS: Edit Host and Domain Override`

      <img width="500" alt="OPNsense user permissions setting for Unbound" src="https://github.com/user-attachments/assets/a24c95e2-c857-4edb-9c21-d54417ed7799"/>

    - Click `Save`

2. Click the API-Key Symbol (Postage Stamp?) to create a API Key and click yes.

    <img width="600" alt="Screenshot of the button 'Create' that create a API-Key and looks some what like a Postage Stamp" src="https://github.com/user-attachments/assets/90ae8565-729b-451f-9a78-f61a18a6b05a" />

3. Open the downloaded file and copy the API key and secret

## Example

Create the `secrets` folder and populate it:

```bash
mkdir ./secrets
touch ./secrets/opnsense_api_key \
      ./secrets/opnsense_api_secret_key \
      ./secrets/porkbun_api_key \
      ./secrets/porkbun_api_secret_key
chmod 700 ./secrets
chmod 600 ./secrets/*
# chown -R root:root ./secrets
```

and add you api key / secrets. After testing you might want to set `root` as owner and run all `docker` commands with `sudo`.

Or even better use:

```yaml
secrets:
  opnsense_api_key:
    environment: OPNSENSE_API_KEY
  ...
```

to inject the secrets from the environment and delete the secrets folder with `rm -rf ./secrets`.

Now we can create a docker compose file like this:

```yaml
services:
  caddy:
    image: mietzen/caddy:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - caddy_data:/caddy/data
      # - ./Caddyfile:/caddy/Caddyfile # Optional if you need custom server settings
      # - ./conf.d/:/caddy/conf.d/ # Optional if you want to add server configs
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      ACME_EMAIL: 'contact@example.com'
      BASE_DOMAIN: 'example.com'
      CADDY_INGRESS_NETWORKS: caddy-ingress
      CADDY_SERVER_IP: '192.168.42.1'
      DOCKER_HOST_IP: '192.168.42.23'
      OPNSENSE_DNS_SERVICE: 'dnsmasq' # or 'unbound'
      OPNSENSE_HOSTNAME: 'opnsense' # you can add a port like 'opnsense:8443' or use a IP '192.168.42.1:8443' but it must be a https backend!
      OPNSENSE_INSECURE: 'true' # If your OPNsense instance uses a self signed cert
    networks:
      - ingress
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
  ingress:
    name: caddy-ingress
    driver: bridge
```

start it with `docker compose up -d`

Now you can create another docker compose stacks with a service you want to expose:

```yaml
services:
  whoami2:
    image: traefik/whoami
    networks:
      - ingress
    labels:
      caddy: whoami.example.com
      caddy.reverse_proxy: "{{upstreams 80}}"

networks:
  ingress:
    name: caddy-ingress
    external: true

```

and start it with `docker compose up`.

You will get a letsencrypt TLS cert and a OPNsense host override entry, so when you visit [whoami1.example.com](https://whoami1.example.com) you will be directed to `192.168.42.23`.

## Advanced Options

If you need some advanced options here are some hints

### Change default `caddy` configuration

The default `Caddyfile` sits in `/caddy/Caddyfile` and contains:

```caddy
{
    dynamic_dns {
        provider opnsense {
            host {$OPNSENSE_HOSTNAME}
            api_key {file./run/secrets/opnsense_api_key}
            api_secret_key {file./run/secrets/opnsense_api_secret_key}
            dns_service {$OPNSENSE_DNS_SERVICE}
            insecure {$OPNSENSE_INSECURE}
        }
        domains {
            {$BASE_DOMAIN}
        }
        dynamic_domains
        ip_source static {$DOCKER_HOST_IP}
        check_interval 120m
        ttl 1h
        versions ipv4
    }
    email {$ACME_EMAIL}
    acme_dns porkbun {
        api_key {file./run/secrets/porkbun_api_key}
        api_secret_key {file./run/secrets/porkbun_api_secret_key}
    }
    debug
    storage file_system {
        root /caddy/data
    }
}

import /caddy/conf.d/*.caddy
```

You can overwrite it using:

```yaml
    volumes:
      - ./Caddyfile:/caddy/Caddyfile
```

### Change default `docker-proxy` configuration

The docker file entrypoint is `["caddy", "docker-proxy", "--caddyfile-path", "/caddy/Caddyfile"]`

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

Or you can use the [environment variables](https://github.com/lucaslorentz/caddy-docker-proxy?tab=readme-ov-file#caddy-cli), checkout [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) for more information.

## Customizing & Forking

If you need a other DNS provider or additional modules you can fork this repo. The included GitHub workflows are generic and should work once you configure the following repository secrets:

```yml
APP_ID
APP_PRIVATE_KEY
DOCKER_HUB_DEPLOY_KEY
```

and var:

```yml
DOCKER_HUB_USERNAME
```

For the actions/create-github-app-token@v2 action you will need to create a GitHub App, see the [usage guide](https://github.com/actions/create-github-app-token?tab=readme-ov-file#usage) on how to do this.

The App will need these permissions:

```yml
Contents: Read/Write
Pull requests: Read/Write
```

Don't forget to activate the workflows after forking!

If you add / delete modules in the `xcaddy` build and want dependabot to work, you need to add / delete them in `.github/dependabot-hack/go.mod` as well.
