#!/usr/bin/env bash
# GoodGoose stage 2 — รันบน VPS ในโฟลเดอร์ stage2:  sudo bash install.sh
# สำรองทุกอย่างก่อนแก้ ถ้าขั้นไหนพังจะย้อนกลับเองด้วย rollback.sh
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo "ต้องรันด้วย sudo"; exit 1; }
CERT=/etc/letsencrypt/live/goodgoose.duckdns.org
[ -f "$CERT/fullchain.pem" ] || { echo "ไม่พบใบรับรองที่ $CERT"; exit 1; }

B=/root/gg-stage2-backup-$(date +%Y%m%d-%H%M%S)
mkdir -p "$B"
cp -a /etc/apache2 "$B/apache2"
cp -a /var/www/html/wp-config.php "$B/wp-config.php"
iptables-save > "$B/iptables.rules"
ln -sfn "$B" /root/gg-stage2-backup-latest
echo "== สำรองไว้ที่ $B"
trap 'echo "!! ผิดพลาด กำลังย้อนกลับ"; bash ./rollback.sh' ERR

echo "== 1/7 โหลด nginx ไว้ก่อน (เว็บยังเปิดอยู่)"
apt-get update -qq
apt-get install -y -qq --download-only nginx

echo "== 2/7 ให้ WordPress รู้ว่าผู้ใช้มาทาง https ผ่าน proxy"
if ! grep -q HTTP_X_FORWARDED_PROTO /var/www/html/wp-config.php; then
python3 - <<'PY'
p = "/var/www/html/wp-config.php"
s = open(p).read()
m = s.find("That's all, stop editing")
if m < 0:
    raise SystemExit("ไม่พบบรรทัด That's all ใน wp-config.php")
i = s.rfind("\n", 0, m) + 1
snip = "if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') { $_SERVER['HTTPS'] = 'on'; }\n"
open(p, "w").write(s[:i] + snip + s[i:])  # เขียนทับไฟล์เดิม สิทธิ์ 640 www-data คงเดิม
PY
fi

echo "== 3/7 ย้าย Apache ไปฟังที่ 127.0.0.1:8080"
a2enmod -q remoteip
cp apache/gg-backend.conf /etc/apache2/sites-available/gg-backend.conf
for s in /etc/apache2/sites-enabled/*.conf; do a2dissite -q "$(basename "$s" .conf)"; done
a2ensite -q gg-backend
echo 'Listen 127.0.0.1:8080' > /etc/apache2/ports.conf
apachectl configtest
systemctl restart apache2

echo "== 4/7 ติดตั้ง nginx หน้า Apache"
apt-get install -y -qq nginx
rm -f /etc/nginx/sites-enabled/default
cp nginx/gg-headers.conf /etc/nginx/snippets/gg-headers.conf
cp nginx/goodgoose.conf /etc/nginx/sites-available/goodgoose.conf
ln -sfn /etc/nginx/sites-available/goodgoose.conf /etc/nginx/sites-enabled/goodgoose.conf
if [ ! -f /etc/nginx/.gg-htpasswd ]; then
  PW=$(openssl rand -base64 12)
  printf 'admin:%s\n' "$(openssl passwd -apr1 "$PW")" > /etc/nginx/.gg-htpasswd
  chown root:www-data /etc/nginx/.gg-htpasswd && chmod 640 /etc/nginx/.gg-htpasswd
  echo "$PW" > /root/gg-dashboard-password.txt && chmod 600 /root/gg-dashboard-password.txt
fi
nginx -t
systemctl enable -q nginx
systemctl restart nginx

echo "== 5/7 dashboard + ตัวสแกน log"
mkdir -p /var/www/gg-dashboard/data /opt/gg-scan /etc/goodgoose
cp dashboard/index.html /var/www/gg-dashboard/index.html
install -m 755 scanner/scan.py /opt/gg-scan/scan.py
[ -f /etc/goodgoose/gemini.env ] || printf 'GEMINI_API_KEY=\nGEMINI_MODEL=gemini-2.5-flash\n' > /etc/goodgoose/gemini.env
chmod 600 /etc/goodgoose/gemini.env
cp systemd/gg-scan.service systemd/gg-scan.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable -q --now gg-scan.timer

echo "== 6/7 iptables: LOG สิ่งที่จะถูก DROP (จำกัด 10 บรรทัด/นาที)"
LOGRULE=(INPUT -m limit --limit 10/min --limit-burst 20 -j LOG --log-prefix "GG-DROP " --log-level 4)
iptables -C "${LOGRULE[@]}" 2>/dev/null || iptables -A "${LOGRULE[@]}"
netfilter-persistent save >/dev/null

echo "== 7/7 สแกนรอบแรก"
systemctl start gg-scan.service
trap - ERR

echo
echo "=================== ผลตรวจ ==================="
ss -tlnp | grep -E ':(80|443|8080) ' || true
for i in 1 2; do
  curl -skI --resolve goodgoose.duckdns.org:443:127.0.0.1 https://goodgoose.duckdns.org/ | grep -iE '^(HTTP|server|x-cache-status)'
done
echo "dashboard: https://goodgoose.duckdns.org/gg-dashboard/  user: admin  รหัส: $(cat /root/gg-dashboard-password.txt)"
echo "ใส่ Gemini key: sudo nano /etc/goodgoose/gemini.env  แล้ว  sudo systemctl start gg-scan.service"
echo "ถ้าเว็บมีปัญหา: sudo bash rollback.sh"
