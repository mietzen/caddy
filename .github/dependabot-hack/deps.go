//go:build dependabot
// +build dependabot

package dependabot

import (
	_ "github.com/caddy-dns/porkbun"
	_ "github.com/caddyserver/caddy/v2"
	_ "github.com/libdns/libdns"
	_ "github.com/lucaslorentz/caddy-docker-proxy/v2"
	_ "github.com/mietzen/caddy-dns-opnsense"
	_ "github.com/mietzen/libdns-opnsense-dnsmasq"
	_ "github.com/mietzen/libdns-opnsense-unbound"
)
