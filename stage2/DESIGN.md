# GoodGoose Stage 2 – ปรับสถาปัตยกรรมให้ปลอดภัยและเร็วขึ้น

Stage 2 เพิ่ม 3 ชั้นบนระบบเดิมโดยไม่มีค่าใช้จ่ายเพิ่ม:
(1) nginx เป็น reverse proxy พร้อม cache และ rate limit หน้า Apache
(2) ต่ออายุ HTTPS อัตโนมัติด้วย DNS-01 ผ่าน DuckDNS
(3) ใช้ AI (Gemini) สแกน log ทุก 10 นาที แล้วแสดงผลบน dashboard ตรวจการโจมตี
ด่าน 1–2 (SSH key-only, firewall เฉพาะ IP ไทย) ยังทำงานเหมือนเดิม

## สถาปัตยกรรมใหม่

```
ผู้ใช้ในไทย
   │ https://goodgoose.duckdns.org
   ▼
Azure NSG (22, 80, 443)
   ▼
iptables + ipset thai ──(ไม่ใช่ IP ไทย)──► LOG "GG-DROP" → DROP
   ▼
nginx :443  (TLS, cache, rate limit, security headers)          ← ใหม่
   │  /gg-dashboard/ → dashboard (basic auth)
   ▼  proxy_pass
Apache 127.0.0.1:8080 → PHP 8.3 → WordPress → MySQL 127.0.0.1    ← ไม่เปิดออกภายนอก

log: nginx access/error, auth.log, kern.log (GG-DROP)
   ▼ systemd timer ทุก 10 นาที
Python: นับ/จัดกลุ่มด้วยกฎ → ส่งสรุปให้ Gemini → latest.json → dashboard
```

## ทำไมไม่ใช้ Cloudflare

- Cloudflare ต้องย้าย nameserver ของโดเมน แต่ goodgoose.duckdns.org เป็นโดเมนย่อยของ DuckDNS ย้ายไม่ได้
- ถ้าผ่าน Cloudflare เซิร์ฟเวอร์จะเห็นแต่ IP ของ Cloudflare ทำให้ ipset thai บล็อกคนไทยไปด้วย
- nginx proxy_cache บน VM ให้ผล cache ใกล้เคียงกันโดยไม่ต้องซื้อโดเมน

## ชั้นที่ 1: nginx reverse proxy

| สิ่งที่ทำ | ได้อะไร |
|---|---|
| nginx รับ 80/443, Apache ย้ายไป 127.0.0.1:8080 | Apache/PHP ไม่ถูกเรียกจากภายนอกตรง ๆ |
| proxy_cache (ข้าม cache เมื่อ login, /wp-admin, /wp-login.php, POST) | หน้าเว็บเร็วขึ้น ดูได้จาก X-Cache-Status: HIT |
| limit_req ที่ wp-login.php ~5 ครั้ง/นาที/IP → 429 | กันการสุ่มรหัสแอดมิน |
| server_tokens off + HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy | ซ่อนเวอร์ชัน ป้องกันฝั่งเบราว์เซอร์ |
| บล็อก xmlrpc.php, .php ใน uploads, .env, .git ที่ nginx | ตัดตั้งแต่ชั้นหน้า |

ข้อควรระวัง: เปิด mod_remoteip ใน Apache (ไม่งั้นทุกคนเป็น 127.0.0.1) และให้ wp-config.php
ตั้ง HTTPS=on เมื่อ X-Forwarded-Proto เป็น https (ไม่งั้น wp-admin redirect วน)

## ชั้นที่ 2: HTTPS ต่ออายุอัตโนมัติ

ใช้ acme.sh โหมด dns_duckdns ยืนยันผ่าน TXT record แทนพอร์ต 80 จึงไม่ต้องเปิด firewall
ให้ต่างประเทศ แก้ข้อจำกัดของ stage 1 เรื่อง Let's Encrypt HTTP-01 ต่ออายุไม่ผ่าน
token ของ DuckDNS เก็บแบบ chmod 600 ไม่ขึ้น GitHub

## ชั้นที่ 3: AI scan log + dashboard

ทุก 10 นาที (systemd timer):
1. Python อ่าน log 10 นาทีล่าสุด: nginx access log, auth.log, GG-DROP ใน kern.log
2. นับและจัดกลุ่มด้วยกฎ: IP ที่โดน 429, path อย่าง /wp-login.php /.env /phpmyadmin,
   SSH login ล้มเหลว, พอร์ตที่ถูก DROP บ่อย
3. ส่งเฉพาะสรุปให้ Gemini ขอผลเป็น JSON: incidents[{type, severity, ips, evidence, recommendation}] + summary_th
4. เขียน latest.json + ไฟล์ย้อนหลัง → dashboard (HTML + Chart.js) อ่านไปแสดง

Dashboard แสดง: กราฟ DROP ตามเวลา, IP/path ที่โดนยิงบ่อย, จำนวน 429 ที่ wp-login, สรุปภาษาไทยจาก AI

หลักการออกแบบ:
- ตัวเลขมาจากกฎ AI แค่อธิบาย ถ้า Gemini ล่มหรือโควตาหมด dashboard ยังแสดงตัวเลขได้
- log เป็นข้อมูลไม่น่าเชื่อถือ ผู้โจมตีใส่ข้อความใน User-Agent/URL เพื่อหลอก AI ได้ (prompt injection)
  จึงไม่ให้ AI สั่งบล็อก IP เอง
- ตัดเลขท้าย IP ของผู้ใช้ปกติก่อนส่ง เพราะโควตาฟรีของ Gemini อาจนำข้อมูลไปฝึกโมเดล
- API key เก็บใน /etc/goodgoose/gemini.env (chmod 600) ไม่ขึ้น GitHub
- dashboard ป้องกันด้วย basic auth
- ทุก 10 นาที = 144 ครั้ง/วัน อยู่ในโควตาฟรี

## วัดผลก่อน/หลัง

| ตัววัด | วิธีวัด |
|---|---|
| ความเร็วหน้าแรก | curl -w "%{time_total}" 20 ครั้ง ก่อน/หลัง cache |
| cache ทำงาน | curl -I ครั้งที่ 2 ต้องขึ้น X-Cache-Status: HIT |
| rate limit | ยิง wp-login.php 10 ครั้ง ต้องได้ 429 |
| Apache ไม่เปิดออกภายนอก | ss -tlnp เห็น 127.0.0.1:8080 เท่านั้น |
| ด่าน 1–2 ยังผ่าน | ทดสอบ SSH และ VPN ต่างประเทศซ้ำ |
| HTTPS ต่ออายุได้ | acme.sh --renew --force ผ่าน |

## ความเสี่ยงและทางย้อนกลับ

- สลับไป nginx แล้วเว็บดับ: สำรอง config ก่อน ถ้าพัง `systemctl stop nginx`, คืน Listen 80, restart Apache (< 1 นาที)
- RAM ไม่พอ: ตรวจ `free -h` ถ้า 1 GB ให้เปิด swap

## ลำดับการลงมือ

1. ตรวจ VM และสำรอง config
2. ติดตั้ง nginx, ย้าย Apache ไป 127.0.0.1:8080, mod_remoteip, แก้ wp-config
3. cache, rate limit, headers แล้วทดสอบ
4. acme.sh DNS-01
5. iptables LOG (จำกัด 10 บรรทัด/นาที)
6. สคริปต์ log + Gemini
7. dashboard + timer 10 นาที
8. อัปเดต README และสไลด์
