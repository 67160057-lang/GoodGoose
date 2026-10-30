#!/usr/bin/env bash
# คืนระบบเป็นแบบ stage 1 (Apache รับ 80/443 เอง):  sudo bash rollback.sh
set -u
B=/root/gg-stage2-backup-latest
[ -d "$B/apache2" ] || { echo "ไม่พบไฟล์สำรองที่ $B"; exit 1; }
systemctl disable --now nginx 2>/dev/null
systemctl disable --now gg-scan.timer 2>/dev/null
rm -rf /etc/apache2 && cp -a "$B/apache2" /etc/apache2
cp -a "$B/wp-config.php" /var/www/html/wp-config.php
apachectl configtest && systemctl restart apache2
echo "ย้อนกลับแล้ว เปิด https://goodgoose.duckdns.org ตรวจว่าเว็บใช้ได้"
