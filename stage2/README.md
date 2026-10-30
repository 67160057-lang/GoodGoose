# Stage 2 — reverse proxy, HTTPS อัตโนมัติ, AI scan log

แบบสถาปัตยกรรมและเหตุผล: [DESIGN.md](DESIGN.md)

| ไฟล์ | หน้าที่ |
|---|---|
| `install.sh` | ติดตั้งทั้งหมด สำรองไฟล์ก่อนแก้ และย้อนกลับเองถ้าพัง |
| `rollback.sh` | คืนระบบเป็นแบบ stage 1 |
| `acme-dns01.sh` | เปลี่ยนการต่ออายุ HTTPS เป็น DNS-01 ผ่าน DuckDNS |
| `nginx/` | reverse proxy + cache + rate limit + security headers |
| `apache/gg-backend.conf` | Apache ฟังเฉพาะ 127.0.0.1:8080 + mod_remoteip |
| `scanner/scan.py` | นับการโจมตีจาก log ด้วยกฎ แล้วให้ Gemini สรุป (ทดสอบ: `python3 scan.py --selftest`) |
| `systemd/` | timer รัน scan.py ทุก 10 นาที |
| `dashboard/index.html` | หน้า dashboard ที่ `/gg-dashboard/` (ต้องใส่รหัสผ่าน) |

## วิธีติดตั้งบน VPS

```bash
git clone https://github.com/67160057-lang/GoodGoose.git
cd GoodGoose/stage2
sudo bash install.sh
```

จากนั้นใส่ Gemini API key (สมัครฟรีที่ Google AI Studio):

```bash
sudo nano /etc/goodgoose/gemini.env      # GEMINI_API_KEY=...
sudo systemctl start gg-scan.service
```

เปลี่ยนการต่ออายุ HTTPS เป็น DNS-01 (ต้องใช้ token จาก duckdns.org):

```bash
sudo bash acme-dns01.sh
```

ถ้าเว็บมีปัญหา: `sudo bash rollback.sh`

## ความลับที่ห้ามขึ้น GitHub

Gemini API key (`/etc/goodgoose/gemini.env`), DuckDNS token, รหัส dashboard (`/root/gg-dashboard-password.txt`)
ทั้งหมดอยู่บน VPS เท่านั้น
