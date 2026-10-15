# Mengamankan HP-server

> 📖 **RISET** — Praktik standar keamanan Linux, belum dijalankan penulis di HP.

**Kamu baru saja menaruh sebuah HP di internet.** Tanpa langkah-langkah ini,
dalam 24 jam kamu akan dikirimi ribuan percobaan login dari bot. Ini bukan
teori — itu terjadi pada semua alamat IPv4 publik yang hidup.

HP-server punya risiko tambahan dibanding VPS: kalau disusupi, bukan cuma
datamu yang hilang, tapi HP-mu jadi bagian botnet.

---

## 0. Prinsip dasar

1. **Jangan ekspos SSH ke internet publik.** Pakai Tailscale/WireGuard. Ini
   satu aturan yang mencegah 95 % masalah.
2. **Ekspos sesedikit mungkin.** Kalau tidak perlu publik, jangan publik.
3. **Anggap HP ini akan mati** — jadi jangan simpan satu-satunya salinan data di situ.
4. **Update rutin.** Kernel HP jarang dapat patch keamanan; itu risiko yang
   kamu terima.

---

## 1. Update sistem

```bash
# postmarketOS / Alpine
sudo apk update && sudo apk upgrade -a

# Android + Termux
pkg update && pkg upgrade
```

Jadwalkan otomatis:

```bash
# systemd
sudo systemctl enable --now unattended-upgrades 2>/dev/null || true

# OpenRC: pakai cron
echo '0 4 * * * apk update && apk upgrade -a' | sudo crontab -
```

---

## 2. SSH aman

### Nonaktifkan login password — pakai kunci saja

Di komputer-mu (bukan di HP):

```bash
ssh-keygen -t ed25519 -C "hp-vps"      # kalau belum punya kunci
ssh-copy-id user@<alamat-hp>            # salin kunci publik
```

Di HP, edit `/etc/ssh/sshd_config` (atau `$PREFIX/etc/ssh/sshd_config` di Termux):

```
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 20
X11Forwarding no
AllowAgentForwarding no
```

```bash
sudo systemctl restart sshd     # atau: sudo rc-service sshd restart
```

> ⚠️ **Uji kunci-mu bekerja di terminal lain SEBELUM menutup sesi ini.**
> Kalau tidak, kamu bisa terkunci di luar HP-mu.

### Kalau SSH terpaksa publik

```bash
sudo apk add fail2ban          # postmarketOS
# atau
pkg install fail2ban           # Termux

# /etc/fail2ban/jail.local
[sshd]
enabled = true
port = 22
maxretry = 3
bantime = 3600
```

Ganti juga port ke sesuatu di atas 1024 (banyak serangan otomatis hanya
menargetkan port <1024).

---

## 3. Firewall

Balik aturan: **tolak semua masuk, izinkan hanya yang kamu butuh.**

```bash
# postmarketOS
sudo apk add nftables

sudo tee /etc/nftables.d/hp-vps.nft >/dev/null <<'EOF'
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif lo accept
    ip protocol icmp accept
    # SSH hanya dari jaringan Tailscale (100.64.0.0/10) — sesuaikan
    ip saddr 100.64.0.0/10 tcp dport 22 accept
    # Web app (kalau diakses lewat Cloudflare Tunnel, ini bahkan tidak perlu)
    tcp dport 8080 accept
    drop
  }
}
EOF

sudo rc-service nftables restart     # atau: systemctl restart nftables
```

**Kalau kamu pakai Cloudflare Tunnel, kamu tidak perlu membuka port apa pun.**
Tunnel keluar dari HP, jadi firewall boleh `drop` semua masukan kecuali SSH
dari Tailscale. Ini kondisi paling aman.

---

## 4. Docker

```bash
# Jalankan container tanpa root di dalam
docker run --user 1000:1000 ...

# Batasi kemampuan (wajib untuk container dari image pihak ketiga)
docker run \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  --read-only \
  --tmpfs /tmp \
  ...
```

**Jangan pernah pasang socket Docker ke container:**

```yaml
# ❌ JANGAN
volumes:
  - /var/run/docker.sock:/var/run/docker.sock       # ini setara memberi root ke internet
```

Kalau butuh akses Docker dari container, pakai
[`docker-socket-proxy`](https://github.com/Tecnativa/docker-socket-proxy) yang
membatasi perintah yang diizinkan.

### Periksa container yang jalan sebagai root

```bash
docker ps --format '{{.Names}}' | while read n; do
  printf '%-24s %s\n' "$n" "$(docker inspect -f '{{.Config.User}}' "$n" | sed 's/^$/root(bahaya)/')"
done
```

---

## 5. Update otomatis untuk Docker

```bash
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower --cleanup --schedule "0 0 4 * * *"
```

⚠️ Watchtower butuh socket Docker — jadi jalankan **hanya kalau kamu sadar
risikonya**, dan jangan ekspos Watchtower ke internet. Alternatif lebih aman:
update manual terjadwal via cron.

---

## 6. Jangan simpan rahasia di repo atau image

```bash
# ❌ JANGAN
ENV DB_PASSWORD=rahasia123          # di Dockerfile — ikut ke image, bisa dilihat siapa pun

# ✅ Lakukan
docker run --env-file /root/.secrets/app.env ...
sudo chmod 600 /root/.secrets/app.env
```

`.gitignore` minimal:

```
.env
*.key
*.pem
credentials.json
```

---

## 7. Pantau apa yang terjadi

```bash
# Siapa yang login
last -n 20
who

# Percobaan login gagal
sudo grep 'Failed password' /var/log/auth.log | tail -20

# Koneksi keluar yang mencurigakan (HP jadi botnet?)
ss -tupn | grep ESTAB

# Container apa yang jalan
docker ps -a
```

Jalankan pemeriksaan di repo ini secara berkala:

```bash
./scripts/healthcheck.sh
```

---

## 8. Backup — HP ini akan rusak

Jangan simpan satu-satunya salinan data di HP bekas. Anggap perangkatnya bisa
mati kapan saja.

```bash
# Contoh: kirim backup ke tempat lain lewat rsync/rclone
rclone sync /home/user/data remote:hp-vps-backup --progress

# Atau tar + kirim ke server lain
tar czf - /home/user/data | ssh user@serverlain 'cat > backup-$(date +%F).tar.gz'
```

Jadwalkan harian via cron. **Uji restore-nya** — backup yang belum pernah
di-restore bukan backup.

---

## Daftar periksa keamanan

- [ ] SSH: login password dimatikan, hanya kunci
- [ ] SSH: tidak diekspos publik (atau fail2ban + port non-standar)
- [ ] Firewall: kebijakan `drop`, hanya port yang perlu dibuka
- [ ] Docker: tidak ada socket Docker di container
- [ ] Rahasia: tidak ada di image/repo, file `600`
- [ ] Update: terjadwal otomatis
- [ ] Backup: jalan harian, dan sudah pernah diuji restore
- [ ] Pantau: `healthcheck.sh` jalan rutin, log diperiksa
- [ ] `healthcheck.sh` lulus tanpa status kritis
