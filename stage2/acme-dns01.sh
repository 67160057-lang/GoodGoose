#!/usr/bin/env bash
# เปลี่ยนการต่ออายุ HTTPS เป็น DNS-01 ผ่าน DuckDNS (ไม่ต้องเปิดพอร์ต 80 ให้ต่างประเทศ)
# รันหลัง install.sh:  sudo bash acme-dns01.sh   แล้ววาง token จากหน้า duckdns.org
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "ต้องรันด้วย sudo"; exit 1; }
read -rsp "DuckDNS token: " DuckDNS_Token; echo
export DuckDNS_Token
[ -x /root/.acme.sh/acme.sh ] || curl -fsS https://get.acme.sh | sh
A=/root/.acme.sh/acme.sh
"$A" --issue --dns dns_duckdns -d goodgoose.duckdns.org --server letsencrypt --dnssleep 60
mkdir -p /etc/nginx/ssl && chmod 700 /etc/nginx/ssl
"$A" --install-cert -d goodgoose.duckdns.org \
  --key-file /etc/nginx/ssl/gg.key --fullchain-file /etc/nginx/ssl/gg.crt \
  --reloadcmd "systemctl reload nginx"
sed -i 's#/etc/letsencrypt/live/goodgoose.duckdns.org/fullchain.pem#/etc/nginx/ssl/gg.crt#; s#/etc/letsencrypt/live/goodgoose.duckdns.org/privkey.pem#/etc/nginx/ssl/gg.key#' \
  /etc/nginx/sites-available/goodgoose.conf
nginx -t && systemctl reload nginx
systemctl disable --now certbot.timer snap.certbot.renew.timer 2>/dev/null || true
echo "เสร็จ acme.sh จะต่ออายุเองทุก 60 วันผ่าน cron"
