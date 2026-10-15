# Autostart: biar hidup sendiri setelah reboot

> 🧪 **PERLU DIUJI** — perintah di sini standar, tapi belum dijalankan penulis
> di perangkat nyata.

HP-server yang tidak otomatis pulih setelah reboot bukan server. Ini yang
membedakan "proyek iseng" dari "VPS sungguhan".

---

## Pilih sesuai init system-mu

| Kondisi | Init | Cara autostart |
|---|---|---|
| postmarketOS | OpenRC | `rc-update add` |
| postmarketOS + systemd | systemd | `systemctl enable` |
| Android + Magisk | `magisk`/init.d | modul service |
| Termux (tanpa root) | ✗ | Termux:Boot |

Cek kamu pakai yang mana:

```bash
ps -p 1 -o comm=        # "init" = OpenRC/Android · "systemd" = systemd
```

---

## postmarketOS — OpenRC

```bash
# Service bawaan
sudo rc-update add sshd default
sudo rc-update add docker default

# Service bikinan sendiri: taruh skrip di /etc/init.d/
sudo nano /etc/init.d/hp-vps
```

```sh
#!/sbin/openrc-run
# /etc/init.d/hp-vps
name="hp-vps"
description="Layanan utama HP-VPS"
command="/usr/local/bin/hp-vps-start.sh"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/hp-vps.log"
error_log="/var/log/hp-vps.err"

depend() {
    need net
    after firewall docker
    use dns logger
}
```

```bash
sudo chmod +x /etc/init.d/hp-vps /usr/local/bin/hp-vps-start.sh
sudo rc-update add hp-vps default
sudo rc-service hp-vps start
sudo rc-service hp-vps status
```

---

## postmarketOS — systemd

```ini
# /etc/systemd/system/hp-vps.service
[Unit]
Description=Layanan utama HP-VPS
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=user
WorkingDirectory=/home/user/app
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=always
RestartSec=10
# Batasi supaya tidak menghabiskan RAM HP
MemoryMax=1G

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now hp-vps
systemctl status hp-vps
journalctl -u hp-vps -f        # lihat log
```

### Docker container punya restart policy sendiri

Untuk container, cara paling andal bukan systemd, tapi Docker sendiri:

```yaml
# docker-compose.yml
services:
  web:
    image: nginx
    restart: unless-stopped        # ← ini yang bikin hidup lagi setelah reboot
```

```bash
docker run -d --restart unless-stopped nginx
```

**Aturan:** kalau `docker.service` sudah autostart, container dengan
`restart: unless-stopped` akan otomatis jalan setelah reboot. Kamu tidak perlu
service systemd tambahan untuk itu.

---

## Android + Magisk

Magisk menjalankan skrip dari `service.d` saat boot:

```bash
su -c 'mkdir -p /data/adb/service.d'
su -c 'nano /data/adb/service.d/hp-vps.sh'
```

```sh
#!/system/bin/sh
# /data/adb/service.d/hp-vps.sh — jalan otomatis saat boot (Magisk)
# Tunggu boot selesai dulu
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 10

# Batas cas (lihat docs/baterai.md)
nohup sh /data/adb/battery-limit.sh >/dev/null 2>&1 &

# Jalankan service-mu di dalam proot/chroot
nohup /data/data/com.termux/files/usr/bin/cloudflared tunnel run hp-vps >/dev/null 2>&1 &
```

```bash
su -c 'chmod +x /data/adb/service.d/hp-vps.sh'
```

> ⚠️ `sleep 10` bukan hiasan. Tanpa itu, jaringan dan mount belum siap dan
> skrip-mu akan gagal diam-diam.

---

## Termux (tanpa root) — Termux:Boot

Termux **tidak** otomatis jalan setelah reboot. Kamu butuh aplikasi
**Termux:Boot** (dari F-Droid, bukan Play Store).

1. Pasang Termux:Boot, buka **sekali** (ini mendaftarkan boot receiver)
2. Matikan optimasi baterai untuk Termux **dan** Termux:Boot:
   Setelan → Aplikasi → Termux → Baterai → **Tanpa batas**
3. Buat skrip:

```bash
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/start-services.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
sshd
cloudflared tunnel run hp-vps
EOF
chmod +x ~/.termux/boot/start-services.sh
```

> ⚠️ **Kenyataan pahit:** tanpa root, Android tetap bisa membunuh Termux
> (pembaruan sistem, manajemen memori agresif). Untuk server yang kamu
> andalkan, root adalah jawabannya.

---

## Verifikasi autostart benar-benar bekerja

**Jangan berasumsi. Reboot dan buktikan.**

```bash
# 1. Catat uptime sebelum
cat /proc/uptime | awk '{printf "%.0f menit\n", $1/60}'

# 2. Reboot
sudo reboot        # atau: su -c reboot

# 3. Tunggu 2 menit, lalu dari perangkat lain:
ssh user@<alamat-hp>
systemctl status hp-vps        # atau: rc-service hp-vps status
docker ps                       # container harus jalan lagi

# 4. Cek uptime sudah reset
cat /proc/uptime | awk '{printf "%.0f menit\n", $1/60}'
```

Kalau setelah reboot layanan tidak jalan, cek log:

```bash
journalctl -b -u hp-vps --no-pager | tail -30     # systemd
cat /var/log/hp-vps.err                            # OpenRC
logcat | grep -i magisk                            # Android
```

**Uji ini secara berkala.** HP lebih sering mati mendadak (listrik, update,
thermal) daripada VPS. Autostart yang tidak diuji = autostart yang tidak ada.

---

## Anti-pattern yang harus dihindari

| ❌ Jangan | ✅ Lakukan |
|---|---|
| `nohup ./app &` tanpa autostart | service + `systemctl enable` |
| Andalkan Termux tanpa Termux:Boot | pasang Termux:Boot, atau root |
| `restart: no` di container penting | `restart: unless-stopped` |
| Taruh skrip di `/tmp` (hilang saat reboot) | `/usr/local/bin` atau `/data/adb` |
| Tidak ada log | arahkan ke file atau journal |
| Pakai `sleep` sebagai pengganti dependency | `After=`/`depend()` yang benar |

`sleep` tetap boleh dipakai sebagai **tambahan** untuk hardware Android yang
belum siap (lihat contoh Magisk di atas), bukan sebagai pengganti dependency
service.
