# Akses dari internet: CGNAT & tunnel

> 📖 **RISET** — Berdasarkan dokumentasi Cloudflare & Tailscale. Belum diuji
> penulis di perangkat nyata.

Ini penghalang nomor satu yang membuat orang menyerah. Kabar baiknya: ada
solusi gratis yang tidak butuh IP publik.

---

## Kenapa port masuk diblokir

Hampir semua paket internet seluler (dan banyak ISP rumah) memakai **CGNAT
(Carrier-Grade NAT)**. Artinya:

- Kamu **tidak punya IPv4 publik** — IP-mu dipakai bersama ratusan pelanggan
- **Port 80, 443, dan hampir semua port masuk diblokir** oleh operator
- Port forwarding di router **tidak akan menolong** — trafiknya tidak pernah
  sampai ke routermu

### Cek apakah kamu di CGNAT

```bash
# Metode 1: skrip di repo ini
./scripts/expose-tunnel.sh check

# Metode 2: manual
# Lihat IP yang dipakai keluar
ip route get 1.1.1.1 | awk '{print $7}'
# Lalu bandingkan dengan IP publik yang terlihat dari luar
curl -s https://api.ipify.org
```

Kalau IP lokal-mu berbeda jauh dari IP publik, atau IP lokal-mu ada di rentang
**`100.64.0.0/10`**, kamu di CGNAT. Rentang itu memang khusus untuk CGNAT.

> Catatan: IPv6 kadang menyelamatkan. Kalau operatormu memberi IPv6 publik
> (`curl -6 https://api64.ipify.org` berhasil), kamu **mungkin** bisa pakai port
> masuk lewat IPv6. Keberhasilannya beda-beda per operator — jangan diandalkan.

---

## Pilihan tunnel

| Solusi | Gratis | Butuh akun | Domain sendiri | Terbaik untuk |
|---|---|---|---|---|
| **Cloudflare Tunnel** | ✓ | ✓ (gratis) | ✓ (bisa) | Server web publik — **rekomendasi** |
| **Tailscale** | ✓ | ✓ | ✗ (pakai `*.ts.net`) | Akses pribadi antar perangkatmu |
| **ngrok** | ✓ (terbatas) | ✓ | ✗ (URL acak) | Tes cepat, demo |
| **WireGuard sendiri** | ✓ | ✗ | perlu VPS | Yang punya VPS kecil sebagai perantara |

---

## Cloudflare Tunnel (rekomendasi)

**Kenapa:** gratis, tidak buka port apa pun (HP-mu keluar koneksi, bukan
menerima), dapat HTTPS otomatis, bisa pakai domainmu sendiri, dan bisa jalan
sebagai service yang hidup setelah reboot.

### Cara cepat — buat tes (tanpa akun)

```bash
./scripts/expose-tunnel.sh install
./scripts/expose-tunnel.sh quick 8080
```

Akan muncul URL seperti `https://xxxx-xxxx.trycloudflare.com`. URL ini **acak
dan hilang** saat proses berhenti — bagus untuk tes, bukan untuk permanen.

### Cara permanen — pakai domainmu

Empat langkah, dilakukan sekali:

```bash
cloudflared tunnel login               # buka URL di browser, pilih domain
cloudflared tunnel create hp-vps       # bikin tunnel
cloudflared tunnel route dns hp-vps vps.domainmu.com
cloudflared tunnel run hp-vps
```

Konfigurasi `~/.cloudflared/config.yml`:

```yaml
tunnel: hp-vps
credentials-file: /root/.cloudflared/<tunnel-id>.json
ingress:
  - hostname: vps.domainmu.com
    service: http://localhost:8080
  - service: http_status:404        # wajib: aturan terakhir harus 404
```

> **Langkah `login` sengaja tidak diotomatiskan** oleh skrip di repo ini, karena
> butuh membuka browser dan memilih akun — itu keputusanmu, bukan keputusan
> skrip.

### Jalankan setelah reboot

Lihat [autostart.md](autostart.md). Contoh untuk systemd:

```ini
# /etc/systemd/system/cloudflared.service
[Unit]
Description=Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel run hp-vps
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now cloudflared
sudo systemctl status cloudflared
```

---

## Tailscale (kalau cuma untuk kamu sendiri)

**Kenapa:** lebih sederhana dari Cloudflare, tidak perlu domain, dan trafik
terenkripsi end-to-end lewat WireGuard. Tapi hanya perangkat di jaringan
Tailscale-mu yang bisa mengakses — bukan publik.

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4          # IP privat di jaringan tailscale
```

Setelah itu, dari laptopmu yang juga terpasang Tailscale:

```bash
ssh user@<ip-tailscale>
curl http://<ip-tailscale>:8080
```

**Cocok untuk:** SSH, dashboard admin, panel pribadi — apa pun yang tidak perlu
diakses orang lain. Ini pilihan paling aman karena tidak ada yang terekspos ke
internet publik.

**Bisa keduanya:** Cloudflare untuk hal publik, Tailscale untuk SSH/admin.
Justru ini yang ideal — jangan pernah buka SSH ke internet publik.

---

## ⚠️ Keamanan: jangan ekspos SSH ke internet

Kalau kamu meneruskan port 22 ke internet publik, kamu akan dikirimi ribuan
percobaan login setiap hari oleh bot. Yang boleh diekspos ke Cloudflare:

| ✅ Aman diekspos | ❌ Jangan pernah |
|---|---|
| Web app di balik autentikasi | SSH |
| Endpoint API publik | Dashboard admin tanpa login |
| File statis | Database (Postgres, MySQL, Redis) |
| Webhook | Docker socket |

Untuk SSH dan admin: **pakai Tailscale atau WireGuard saja.** Kalau terpaksa
ekspos SSH, minimal: nonaktifkan login password, pakai kunci saja, ganti port,
pasang fail2ban. Semua itu di [hardening.md](hardening.md).

---

## Kalau tunnel tidak jalan

| Gejala | Penyebab |
|---|---|
| `cloudflared` tidak mau start | Arsitektur salah — cek `uname -m`, unduh `arm64` untuk HP modern |
| URL muncul tapi 502 | Service lokal tidak jalan di port itu — cek `curl localhost:PORT` |
| Koneksi putus tiap beberapa menit | Wi-Fi HP dihemat daya — matikan penghematan Wi-Fi, atau pakai kabel |
| Lambat sekali | HP throttle (panas) atau Wi-Fi lemah — lihat [baterai.md](baterai.md) |
| Tunnel mati setelah reboot | Belum dipasang sebagai service — lihat [autostart.md](autostart.md) |
