FROM caddy:2-builder AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/porkbun \
    --with github.com/lucaslorentz/caddy-docker-proxy/v2 \
    --with github.com/mholt/caddy-dynamicdns \
    --with github.com/mietzen/caddy-dns-opnsense \
    --with github.com/mietzen/libdns-opnsense-dnsmasq \
    --with github.com/mietzen/libdns-opnsense-unbound

FROM caddy:2.10.2

RUN mkdir /caddy
COPY ./Caddyfile /etc/caddy/Caddyfile
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

ENTRYPOINT ["caddy", "docker-proxy"]
