#!/bin/sh
# Make a DNS choice really apply (run as root: pkexec dns-apply.sh …). The system file
# /etc/systemd/resolved.conf.d/dns-over-tls.conf has Domains=~. so its DNS= list wins over the per-network DNS;
# this rewrites that list (picked provider first, encrypted) and restarts systemd-resolved + flushes its cache.
#   dns-apply.sh restart                      only restart + flush
#   dns-apply.sh auto|google|cloudflare|quad9|adguard
#   dns-apply.sh custom 1.2.3.4 [2001:db8::1 …]
F=/etc/systemd/resolved.conf.d/dns-over-tls.conf
G="8.8.8.8#dns.google 8.8.4.4#dns.google 2001:4860:4860::8888#dns.google"
C="1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com"
case "$1" in
restart) list="" ;;
auto|google) list="$G 1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com" ;;   # Google first: Steam gets the Vietnam CDN node
cloudflare) list="$C" ;;
quad9) list="9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net" ;;
adguard) list="94.140.14.14#dns.adguard-dns.com 94.140.15.15#dns.adguard-dns.com" ;;
custom)
    shift; list=""
    for a in "$@"; do
        echo "$a" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$|^[0-9a-fA-F:]+:[0-9a-fA-F:]*$' || { echo "bad address: $a" >&2; exit 2; }
        list="$list $a"
    done
    [ -n "$list" ] || exit 2 ;;
*) echo "usage: dns-apply.sh restart|auto|google|cloudflare|quad9|adguard|custom ADDR…" >&2; exit 2 ;;
esac
[ -n "$list" ] && { sed -i "s|^DNS=.*|DNS=${list# }|" "$F" || exit 1; }
systemctl restart systemd-resolved && resolvectl flush-caches
