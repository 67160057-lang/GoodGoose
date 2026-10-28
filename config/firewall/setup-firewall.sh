#!/usr/bin/env bash
# Allow inbound connections only from Thailand (IPv4), drop everything else.
# Run as root from an SSH session: sudo bash setup-firewall.sh
set -euo pipefail

COUNTRY="th"
SETNAME="thai"
AZURE_PLATFORM_IP="168.63.129.16"
ADMIN_IP="${ADMIN_IP:-$(echo "${SSH_CLIENT:-}" | awk '{print $1}')}"

if [ -z "$ADMIN_IP" ]; then
  echo "ABORT: ไม่พบ IP ผู้ดูแล ให้ตั้งเอง เช่น ADMIN_IP=1.2.3.4 sudo -E bash $0"
  exit 1
fi

# 1) ติดตั้งเครื่องมือ
DEBIAN_FRONTEND=noninteractive apt-get install -y ipset iptables-persistent ipset-persistent

# 2) โหลดรายการ IP ประเทศไทยจาก ipdeny.com
curl -fsS "https://www.ipdeny.com/ipblocks/data/countries/${COUNTRY}.zone" -o /tmp/${COUNTRY}.zone
ipset create "$SETNAME" hash:net -exist
ipset flush "$SETNAME"
sed "s/^/add ${SETNAME} /" /tmp/${COUNTRY}.zone | ipset restore -exist
echo "entries: $(ipset list "$SETNAME" | grep 'Number of entries')"

# 3) ตัวย้อนกลับอัตโนมัติ 10 นาที (กันล็อกตัวเองออก)
systemd-run --unit=fw-rollback --on-active=10min /bin/sh -c 'iptables -P INPUT ACCEPT; iptables -F INPUT' || true

# 4) กฎ IPv4
iptables -F INPUT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -s "$AZURE_PLATFORM_IP" -j ACCEPT
iptables -A INPUT -p tcp -s "$ADMIN_IP" --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 22,80,443 -m set --match-set "$SETNAME" src -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -m set --match-set "$SETNAME" src -j ACCEPT
iptables -P INPUT DROP

# 5) กฎ IPv6 (ปิดทั้งหมดยกเว้น loopback/established)
ip6tables -F INPUT
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -P INPUT DROP

iptables -L INPUT -n -v --line-numbers
echo
echo "ทดสอบ SSH และเว็บจากหน้าต่างใหม่ก่อน ถ้าผ่านแล้วรัน:"
echo "  sudo systemctl stop fw-rollback.timer && sudo netfilter-persistent save"
