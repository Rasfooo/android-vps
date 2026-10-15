# Jalur B2 — postmarketOS: Linux asli di HP ⭐

> 🧪 **PERLU DIUJI** — halaman ini ditulis dari dokumentasi resmi postmarketOS
> dan sumber komunitas, **belum dijalankan penulis** karena belum ada HP uji.
> Ikuti dengan sadar risiko. Kalau kamu menjalankannya, laporkan hasilnya!

**Ini jalur yang paling mendekati "VPS sungguhan."** Kamu mengganti Android
dengan Linux betulan: `systemd`, `docker`, `docker compose`, `systemctl` — semua
yang kamu harapkan dari VPS.

**Waktu:** 2–4 jam untuk pemula · **Risiko:** ⚠️ tinggi (flashing bisa brick)

---

## Kenapa postmarketOS, bukan Android + Magisk?

| | Android + Magisk (B1) | postmarketOS (B2) |
|---|---|---|
| Linux asli | ✗ (Android, bukan Linux biasa) | ✓ |
| `systemd` / `systemctl` | ✗ | ✓ |
| Docker resmi | ~ (butuh modul, sering rusak) | ✓ kalau kernel mendukung cgroup |
| Update OS | lewat ROM | `apk upgrade` biasa |
| Layar & UI | Android | headless XFCE/terminal |
| Risiko brick | sedang | tinggi saat flashing pertama |
| Cocok untuk server | cukup | **terbaik** |

Kalau tujuanmu server headless, postmarketOS lebih tepat: tidak ada Android
yang membunuh proses di belakang, tidak ada batasan "systemless", tidak ada
baterai yang dipaksa UI.

---

## Langkah 0 — Pilih perangkat dengan benar (JANGAN dilewati)

Ini penentu berhasil/gagal. **Porting HP yang tidak didukung adalah proyek
berbulan-bulan, bukan pekerjaan akhir pekan.**

Cek di [wiki.postmarketos.org/wiki/Devices](https://wiki.postmarketos.org/wiki/Devices):

1. Cari HP-mu. Kalau **tidak ada**, berhenti di sini — pilih HP lain atau
   pakai Jalur A/B1.
2. Lihat **tier**-nya:
   - `main` / `community` → **layak** jadi server
   - `testing` → untuk coba-coba, jangan untuk yang kamu andalkan
   - `unmaintained` / `main-with-caveats` → anggap testing atau lebih buruk
3. **Cek 4 baris fitur ini** — inilah yang sebenarnya menentukan di server
   headless, dan tier saja tidak menceritakannya:

| Yang dicek | Kenapa penting |
|---|---|
| **Wi-Fi** | Titik gagal paling umum. Banyak Qualcomm butuh firmware `ath10k`/`ath11k` khusus. |
| **USB networking / OTG** | Akses konsol saat layar mati, dan cadangan koneksi kabel. |
| **Storage** | eMMC HP bukan flash kelas server. Cek throughput & perilaku wear. |
| **Thermal headless** | Di laci tanpa aliran udara, throttle datang jauh lebih cepat daripada di kantong. |

**HP yang direkomendasikan komunitas 2026:**

- 🥇 **OnePlus 6 / 6T** (`enchilada` / `fajita`) — paling didukung, kernel
  mendekati mainline, GPU (Freedreno) & Wi-Fi jalan, harga bekas ~Rp 800rb–1,2jt.
- 🥈 **Google Pixel** (bootloader bisa dibuka) — dukungan panjang,
  dokumentasi rooting paling lengkap kalau kamu ke Jalur B1.
- ⚠️ **Hindari** MediaTek tanpa port, dan semua bootloader terkunci permanen.

---

## Langkah 1 — Kesiapan di komputer (bukan di HP)

`pmbootstrap` jalan di Linux x86_64 dan yang dibutuhkan:

```bash
# Debian/Ubuntu
sudo apt install python3 python3-pip git openssl

# Fedora
sudo dnf install python3 python3-pip git openssl

# Arch
sudo pacman -S python python-pip git openssl
```

Pasang pmbootstrap:

```bash
git clone --depth=1 https://gitlab.com/postmarketOS/pmbootstrap.git
cd pmbootstrap
mkdir -p ~/.local/bin
ln -s "$PWD/pmbootstrap.py" ~/.local/bin/pmbootstrap
export PATH="$HOME/.local/bin:$PATH"
pmbootstrap -V        # harus >= 3.2.0 untuk systemd
```

> ⚠️ Kalau `pmbootstrap -V` menunjukkan versi < 3.2.0, pakai instalasi dari git
> di atas (bukan dari paket distro) — versi lama tidak mendukung systemd.

---

## Langkah 2 — Inisialisasi

```bash
pmbootstrap init
```

Yang akan ditanya (jawaban untuk **server headless**):

| Pertanyaan | Jawaban | Alasan |
|---|---|---|
| Vendor / device | sesuaikan HP-mu | mis. `oneplus` / `enchilada` |
| UI | **`none`** | Kamu tidak butuh UI di server; hemat RAM & storage |
| systemd | **`always`** atau **ya** | Ini yang memberi `systemctl` — **wajib** untuk feel VPS |
| Hostname | `hp-vps` | terserah |
| Username | `user` | default aman |
| Kernel | pilih yang default | |
| Extra packages | kosongkan dulu | install nanti via `apk` |

**Penting:** UI `none` + systemd = server Linux murni. Kalau kamu pilih UI
grafis, kamu membuang ~500 MB RAM untuk sesuatu yang tidak akan kamu lihat.

---

## Langkah 3 — Bangun image

```bash
pmbootstrap install
```

Kalau kamu mau langsung ada Docker tanpa install manual:

```bash
# Tambahkan docker ke paket yang dipasang saat build
pmbootstrap install --add docker
# Kalau paket 'docker' tidak ada di repo Alpine, dia akan gagal —
# dalam hal itu lanjut saja, install lewat apk setelah boot.
```

> ⚠️ **Apakah Docker benar-benar jalan?** postmarketOS bisa menjalankan Docker
> **hanya kalau kernel perangkatmu mengaktifkan cgroup** dan opsi kernel yang
> relevan. Untuk perangkat dengan kernel vendor (bukan mainline), ini sering
> tidak tersedia. Cek setelah boot:
> ```bash
> cat /proc/cgroups
> docker info      # kalau error soal cgroup → Docker tidak akan jalan
> ```
> Kalau gagal, postmarketOS **bukan** solusi untukmu; kembali ke Jalur B1
> dengan udocker.

---

## Langkah 4 — Masukkan ke HP (⚠️ bagian paling berisiko)

**Sebelum mulai:**

- [ ] Baterai HP **> 50%**
- [ ] Sudah **backup semua data** — flashing menghapus segalanya
- [ ] Sudah tahu cara masuk **fastboot mode** untuk HP-mu (biasanya
      `Volume Down` + `Power`)
- [ ] Sudah **unlock bootloader** (proses berbeda per merek; Xiaomi butuh
      tunggu 7 hari, Google & OnePlus lebih cepat). **Unlock menghapus semua data.**
- [ ] Sudah catat/backup **partisi asli** kalau tersedia tool-nya
- [ ] Sadar: **bisa brick permanen.** Kalau ini satu-satunya HP-mu, jangan.

```bash
# Masukkan HP ke fastboot, lalu:
fastboot devices        # harus muncul serial HP-mu
pmbootstrap flasher flash_rootfs
pmbootstrap flasher flash_kernel
```

> ⚠️ **Verifikasi nama partisi untuk device-mu di halaman wiki device-mu
> sebelum menjalankan perintah flash.** Perintah generik di atas bisa salah
> target pada device tertentu. Jangan pernah menebak.

Setelah boot pertama, login lewat terminal USB (atau SSH kalau Wi-Fi sudah
tersambung).

---

## Langkah 5 — Jadikan server

Semua perintah di bawah dijalankan **di HP**, setelah boot ke postmarketOS.

### 5a. Update dasar

```bash
sudo apk update && sudo apk upgrade -a
sudo apk add openssh docker docker-cli-compose curl nano htop
```

### 5b. Autostart SSH (kalau UI `none`, tidak ada yang menyalakannya)

```bash
sudo rc-update add sshd default      # kalau init-nya OpenRC
sudo systemctl enable --now sshd     # kalau init-nya systemd
```

### 5c. Docker

```bash
sudo rc-update add docker default    # OpenRC
sudo systemctl enable --now docker   # systemd
docker run --rm hello-world          # harus sukses
```

### 5d. Uji cepat — inilah momen "ini benar-benar VPS"

```bash
docker compose version
docker run -d --name web -p 8080:80 nginx
curl -I localhost:8080      # harus HTTP 200
```

Kalau ini jalan, kamu sudah punya **Docker Compose asli di HP** — inilah yang
tidak bisa kamu dapat di Jalur A.

---

## Langkah 6 — Batasi pengisian baterai

Jangan lewatkan. Detail: [baterai.md](baterai.md)

Di postmarketOS, batas cas kadang tersedia lewat sysfs yang sama dengan Android:

```bash
./scripts/battery-limit.sh detect
./scripts/battery-limit.sh set 80
```

Kalau tidak ada node yang bisa ditulis (umum di kernel mainline), alternatifnya
**cabut baterai** dan suplai daya langsung, atau pakai perangkat yang punya
dukungan `battery idle mode` di kernel.

---

## Langkah 7 — Akses dari internet

Lanjut ke [tunnel.md](tunnel.md) — Cloudflare Tunnel bekerja baik di sini
karena `cloudflared` tersedia untuk arm64/aarch64.

---

## Langkah 8 — Amankan

Wajib. Kamu baru saja menaruh perangkat di internet:
[hardening.md](hardening.md)

---

## Kalau gagal

| Gejala | Kemungkinan penyebab |
|---|---|
| `fastboot devices` kosong | Driver USB / kabel data (bukan kabel cas) / mode salah |
| Bootloop setelah flash | Partisi salah target — cek halaman device |
| Tidak ada Wi-Fi | Firmware tidak ada di image; kernel vendor butuh blob |
| `docker info` error cgroup | Kernel tidak dukung — tidak bisa diperbaiki tanpa kernel baru |
| Baterai kembung dalam 2 bulan | Batas cas tidak dipasang |
| Mati sendiri random | OOM (RAM kecil) atau thermal shutdown |

---

## Laporkan hasilmu

Ini yang paling kami butuhkan — repo ini dibangun dengan asumsi jujur bahwa
banyak bagian belum diuji. Format laporan:

```
Perangkat : OnePlus 6 (enchilada)
OS        : postmarketOS 25.12, systemd, UI none
Jalur     : B2
Hasil     : berhasil / gagal di langkah N
Docker    : jalan / tidak (cgroup: ya/tidak)
Catatan   : ...
```

Buka [issue](../../../issues) dengan format di atas, atau PR ke
[CONTRIBUTING.md](../../CONTRIBUTING.md).
