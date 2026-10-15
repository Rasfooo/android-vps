# Jalur A — tanpa root (Termux + proot)

> 📖 **RISET** — Alur Termux/proot-distro berdasarkan wiki resmi Termux dan
> dokumentasi proot-distro. Belum dijalankan penulis.

**Jalur paling aman** (tidak menyentuh bootloader, tidak bisa brick) dan paling
cepat (15 menit). Tapi ada batas keras: **Docker asli tetap tidak bisa.**

| | |
|---|---|
| ⏱️ Waktu | ~15 menit |
| ⚠️ Risiko | rendah — tidak ada flashing |
| ✅ Dapat | Linux userspace penuh, `apt`/`apk`, Python, Node, service ringan |
| ❌ Tidak dapat | Docker asli, `docker compose`, port <1024, sebagian syscall |

Kalau kamu butuh Docker asli, langsung ke [Jalur B](jalur-b2-postmarketos.md).

---

## Kenapa Docker asli tidak bisa tanpa root

Docker butuh: (1) **daemon yang jalan sebagai root**, (2) **namespace** dan
**cgroup** untuk isolasi, (3) sebagian **system call** yang diblokir oleh
kernel Android untuk proses tanpa hak. Tanpa root kamu tidak bisa memenuhi itu.

Yang **bisa** dilakukan tanpa root: `udocker` dan `proot-distro` — keduanya
menjalankan userspace Linux lewat emulasi syscall (`ptrace`), bukan isolasi
kernel. Hasilnya jalan, tapi dengan biaya performa ~10–30 % dan tanpa
`docker compose`.

---

## Langkah 1 — Termux dari F-Droid

**Jangan dari Play Store** — versi di sana sudah usang dan tidak bisa
`pkg upgrade` dengan benar.

1. Pasang [F-Droid](https://f-droid.org/)
2. Dari F-Droid, pasang **Termux**
3. Buka Termux sekali, jalankan `pkg upgrade`

```bash
pkg update && pkg upgrade -y
pkg install -y proot-distro openssh termux-api
```

---

## Langkah 2 — Kunci Termux dari pembunuh proses Android

**Ini langkah paling penting di jalur ini.** Kalau dilewati, Termux akan mati
sendiri beberapa jam kemudian.

**Matikan optimasi baterai:**
Setelan → Aplikasi → Termux → Baterai → **Tanpa batas / Tidak dioptimalkan**

**Ambil wake lock supaya CPU tidak tidur:**

```bash
termux-wake-lock
```

**Kunci Termux di daftar recent apps** (ikon gembok / "Lock" di menu recent).

**Cek sudah benar:**

```bash
# Cek optimasi baterai (butuh termux-api)
termux-battery-status | head -20
```

Tanpa langkah ini, kamu akan mengalami hal seperti: service jalan, lalu 3 jam
kemudian mati sendiri tanpa error apa pun di log. Itu Android yang membunuhnya.

---

## Langkah 3 — Linux penuh dengan proot-distro

```bash
# Lihat distro yang tersedia
proot-distro list

# Pasang Debian
proot-distro install debian

# Masuk
proot-distro login debian
```

Sekarang kamu di dalam Debian. Pasang apa saja:

```bash
apt update && apt upgrade -y
apt install -y python3 python3-pip nodejs npm git curl nano htop
```

**Keluar** dari proot: `exit`

---

## Langkah 4 — Jalankan container dengan udocker

`udocker` menjalankan image OCI **tanpa daemon dan tanpa root**. Ini pengganti
Docker yang paling mendekati.

```bash
# Di Termux (bukan di dalam proot)
pkg install -y python3
pip install udocker

udocker --allow-root install      # pasang komponen bantu
udocker version
```

Uji:

```bash
udocker pull alpine
udocker create --name=uji alpine
udocker run uji echo "halo dari container"
udocker run uji cat /etc/os-release
```

Menjalankan service:

```bash
udocker run \
  --name=web \
  -p 8080:80 \
  -v /data/data/com.termux/files/home/app:/app \
  nginx
```

> `-p` di udocker bukan port forwarding kernel — dia memakai relay userspace.
> Jalan, tapi lebih lambat dari Docker asli.

**Batasan udocker yang harus kamu terima:**

| Fitur | Status |
|---|---|
| Jalankan image OCI | ✅ |
| Volume | ✅ |
| Port mapping | ✅ (lewat relay, lambat) |
| `docker compose` | ❌ **tidak ada** |
| Networking antar container | ⚠️ terbatas |
| Perf | ~10–30 % lebih lambat (proot) |

---

## Langkah 5 — SSH dari luar

```bash
# Di Termux
sshd
whoami        # ingat username ini
ifconfig 2>/dev/null | grep inet || ip addr show | grep inet
# catat IP lokal HP, misal 192.168.1.50
```

Dari komputer lain di Wi-Fi yang sama:

```bash
ssh -p 8022 user@192.168.1.50
```

Port default Termux adalah **8022** (bukan 22), karena port <1024 butuh root.

> Batasan: ini hanya jalan di jaringan lokal. Untuk akses dari internet, kamu
> butuh tunnel → [tunnel.md](tunnel.md)

---

## Langkah 6 — Autostart

Tanpa root, kamu butuh **Termux:Boot** dari F-Droid → [autostart.md](autostart.md)

---

## Langkah 7 — Batas baterai

Tanpa root kamu **tidak bisa** mengatur batas cas lewat kernel. Pilihan:

1. **Cas bergantian** pakai colokan pintar + jadwal (paling praktis tanpa root)
2. **Fitur bawaan HP** — beberapa merek punya "protect battery" di Setelan → Baterai
3. Root → pakai ACC → [baterai.md](baterai.md)

Jangan abaikan ini. Lihat [baterai.md](baterai.md) untuk kenapa.

---

## Apa yang realistis dijalankan dengan Jalur A

✅ **Cocok:**
- Bot sederhana (Telegram/Discord) — Python/Node
- Cron dan skrip terjadwal
- API kecil (Flask/Express/FastAPI)
- Sinkronisasi file (Syncthing, rclone)
- Reverse proxy ringan
- Endpoint webhook
- Monitoring (Uptime Kuma lewat Node langsung)

❌ **Tidak cocok:**
- Apa pun yang butuh `docker compose`
- Jellyfin/Plex transcoding (butuh akses hardware + performa)
- Database berat (proot memperlambat I/O)
- Home Assistant dengan banyak add-on (butuh Docker)
- Apa pun yang butuh port <1024 tanpa proxy

---

## Jebakan yang sering terjadi

| Masalah | Penyebab & solusi |
|---|---|
| Termux mati sendiri | Optimasi baterai — lihat Langkah 2 |
| `sshd` tidak jalan setelah reboot | Termux:Boot belum dipasang |
| `pip install` gagal | Beberapa paket butuh compiler: `pkg install build-essential` |
| proot sangat lambat | Normal — proot mengemulasi syscall. Jangan pakai untuk I/O berat |
| udocker "cannot execute" | Coba image yang lebih tua/kecil, atau pakai proot-distro langsung |
| Storage penuh | `proot-distro` + image memakan banyak GB. Cek `df -h .` |

---

## Naik ke Jalur B kalau…

- Kamu butuh `docker compose` untuk benar-benar jalan
- Kamu butuh port 80/443 langsung
- Termux tetap mati sendiri walau penghematan baterai sudah dimatikan
- Kamu butuh uptime yang serius

→ [jalur-b2-postmarketos.md](jalur-b2-postmarketos.md)
