FROM caddy:2-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/lucaslorentz/caddy-docker-proxy/v2 \
    --with github.com/caddy-dns/porkbun \
    --with github.com/mholt/caddy-dynamicdns \
    --with github.com/mholt/caddy-events-exec \
    --with github.com/mietzen/caddy-dynamicdns-cmd-source

FROM caddy:2.10.2-alpine

RUN apk add --no-cache curl ca-certificates jq

COPY ./add_host_override /usr/sbin/add_host_override
COPY ./export_secrets /usr/sbin/export_secrets

RUN chmod +x /usr/sbin/add_host_override
RUN chmod +x /usr/sbin/export_secrets

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

ENTRYPOINT ["/usr/sbin/export_secrets"]

CMD ["caddy", "docker-proxy"]
