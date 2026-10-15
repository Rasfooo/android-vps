# Jalur B1 — Android + Magisk (+ Docker/udocker)

> 🧪 **PERLU DIUJI** — Alur rooting dan Docker-on-Android belum dijalankan
> penulis. Rooting berbeda-beda per merek; verifikasi langkah untuk **device-mu**
> di komunitas XDA sebelum mulai.

**Jalan tengah:** tetap pakai Android, tapi dengan hak root. Kamu dapat
kebebasan lebih tanpa harus mengganti OS.

| | |
|---|---|
| ⏱️ Waktu | 1–2 jam (termasuk unlock bootloader) |
| ⚠️ Risiko | sedang–tinggi — **unlock bootloader menghapus semua data** |
| ✅ Dapat | Root, module Magisk, autostart andal, batas baterai |
| ⚠️ Docker asli | **kadang** jalan — tergantung kernel HP-mu |

---

## Kapan pilih B1 vs B2

| | B1 (Android + Magisk) | B2 (postmarketOS) |
|---|---|---|
| Masih bisa pakai sebagai HP | ✓ | ✗ |
| Docker asli | ⚠️ sering gagal (cgroup) | ✅ kalau kernel mendukung |
| systemd / systemctl | ✗ | ✓ |
| Risiko | sedang | tinggi |
| Android membunuh proses | ✓ (masih bisa, tapi lebih jarang) | ✗ tidak ada Android |

**Pilih B1 kalau:** kamu mau HP-nya masih bisa dipakai normal, atau HP-mu tidak
ada port postmarketOS.

---

## Langkah 1 — Cek kelayakan

**Wajib ada:**

- [ ] Bootloader **bisa di-unlock** (cek forum device-mu)
- [ ] Ada **metode root** untuk Android versimu (Magisk mendukung hampir semua)
- [ ] Kamu **siap kehilangan semua data** saat unlock
- [ ] **Backup** — Google Takeout, foto, chat, semua

**Sebelum lanjut, jawab ini:** kalau HP-mu jadi tidak bisa boot, apa yang
kamu kehilangan? Kalau jawabannya "banyak hal penting", berhenti dan pakai
Jalur A.

---

## Langkah 2 — Unlock bootloader

Prosesnya beda per merek:

| Merek | Cara | Catatan |
|---|---|---|
| **Google Pixel** | `fastboot flashing unlock` | paling mudah |
| **OnePlus** | `fastboot oem unlock` | mudah |
| **Xiaomi** | Mi Unlock Tool | ⚠️ **tunggu 7–30 hari** |
| **Samsung** | ⚠️ Knox trip permanen | **kehilangan garansi & beberapa fitur permanen** |
| **Huawei** | biasanya ✗ | tidak ada cara resmi |

```bash
# Pasang platform-tools di komputer
adb devices                   # HP harus muncul
adb reboot bootloader
fastboot devices
fastboot flashing unlock      # atau perintah khusus merek-mu
```

> ⚠️ **Verifikasi perintah untuk device-mu.** Salah perintah bisa brick.
> Jangan menebak.

---

## Langkah 3 — Pasang Magisk

1. Unduh **Magisk** dari [github.com/topjohnwu/Magisk/releases](https://github.com/topjohnwu/Magisk/releases)
2. Ambil **boot.img** dari firmware device-mu (unduh factory image)
3. Di HP: Magisk → Install → **Select and Patch a File** → pilih `boot.img`
4. Salin hasil `magisk_patched-*.img` ke komputer
5. Flash:

```bash
fastboot flash boot magisk_patched-*.img
fastboot reboot
```

6. Buka aplikasi Magisk — harus menunjukkan **Installed**

Alternatif untuk device dengan recovery TWRP: flash ZIP Magisk lewat TWRP.

**Verifikasi root:**

```bash
adb shell
su
id        # harus menunjukkan uid=0(root)
```

---

## Langkah 4 — Docker di Android: uji dulu, jangan berharap

**Ini bagian paling sering mengecewakan.** Docker butuh cgroup dan namespace
yang **sering dinonaktifkan** di kernel HP.

### Uji apakah Docker mungkin jalan

```bash
su
# 1. Cek cgroup tersedia
cat /proc/cgroups
mount | grep cgroup

# 2. Cek namespace
ls /proc/self/ns/

# 3. Cek versi cgroup (v2 diharapkan untuk Docker modern)
cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null || echo "tidak ada cgroup v2"
```

**Kalau `/proc/cgroups` kosong atau cgroup tidak ter-mount → Docker asli
kemungkinan besar gagal.** Jangan buang waktu; lanjut ke udocker di Langkah 5.

### Kalau cgroup ada

Beberapa modul Magisk menyediakan Docker untuk Android (cari "docker" di repo
modul Magisk). Hasilnya **sangat bervariasi per device**.

```bash
docker info        # kalau ini error soal cgroup / iptables, Docker tidak akan jalan
```

Masalah yang paling sering muncul:

| Error | Sebab |
|---|---|
| `cgroup not mounted` | Kernel tidak menyediakan |
| `iptables: not permitted` | Kernel Android memblokir |
| Container start tapi langsung mati | SELinux menolak |
| Jalan tapi tanpa jaringan | Namespace net tidak lengkap |

> **Kesimpulan jujur:** Docker asli di Android **bukan hal yang bisa diandalkan**.
> Kalau kamu benar-benar butuh Docker Compose, postmarketOS (Jalur B2) jauh
> lebih mungkin berhasil. Kalau Docker di HP-mu kebetulan jalan, bagus — tapi
> jangan rencanakan proyekmu di atas asumsi itu.

---

## Langkah 5 — Fallback: udocker atau chroot

Kalau Docker gagal (kasus umum):

### Opsi 1: udocker di Termux

Lihat [jalur-a-tanpa-root.md](jalur-a-tanpa-root.md) — tapi dengan root, udocker
jadi lebih cepat dan lebih stabil.

### Opsi 2: chroot ke Linux penuh

Dengan root, kamu bisa chroot ke Debian/Ubuntu penuh:

```bash
su
mkdir -p /data/local/debian
# Pasang proot-distro di Termux dulu, lalu:
proot-distro install debian
# Lalu chroot ke situ (lebih cepat dari proot karena tanpa emulasi syscall)
```

Ini memberi Linux penuh tanpa emulasi — lebih cepat dari proot. Tapi masih
**bukan Docker**.

---

## Langkah 6 — Autostart (Magisk service.d)

Inilah keunggulan utama root: autostart yang andal.

```bash
su -c 'mkdir -p /data/adb/service.d'
su -c 'nano /data/adb/service.d/hp-vps.sh'
```

```sh
#!/system/bin/sh
# Jalan otomatis saat boot (Magisk)
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 10                              # tunggu jaringan & mount siap

nohup sh /data/adb/battery-limit.sh >/dev/null 2>&1 &
nohup /data/data/com.termux/files/usr/bin/sshd >/dev/null 2>&1 &
```

```bash
su -c 'chmod +x /data/adb/service.d/hp-vps.sh'
```

Detail lengkap: [autostart.md](autostart.md)

---

## Langkah 7 — Batas baterai

Dengan root, kamu sekarang **bisa** mengatur batas cas:

```bash
./scripts/battery-limit.sh detect
./scripts/battery-limit.sh set 80
```

Atau lebih baik, pakai **ACC/AccA** — lebih tahan terhadap kekhasan merek:

```bash
acc -s pc=80        # pause charge di 80%
```

Wajib dibaca: [baterai.md](baterai.md)

---

## Langkah 8 — Akses & keamanan

- [tunnel.md](tunnel.md) — akses dari internet
- [hardening.md](hardening.md) — jangan sampai HP-mu jadi botnet

Khusus untuk root: **jangan pernah** beri akses root ke aplikasi dari sumber
tidak jelas, dan jangan pakai sistem yang tidak menerima update keamanan Android
untuk hal yang sensitif.

---

## ⚠️ Risiko khusus Jalur B1

1. **Android versi lama tidak dapat patch keamanan.** Root + OS usang = kombinasi
   berisiko untuk apa pun yang menghadap internet.
2. **Magisk bisa terdeteksi** oleh aplikasi banking/DRM — beberapa akan menolak
   jalan.
3. **Unlock bootloader Samsung permanent** (Knox trip) — tidak bisa dibatalkan.
4. **Pembaruan OTA Android** akan menghapus root dan bisa membuat bootloop.
   Matikan update otomatis.

---

## Laporkan hasilmu

Yang paling berguna bagi orang lain:

```
Perangkat   : (merek + tipe)
Android     : (versi)
Magisk      : (versi)
Docker asli : jalan / gagal (error: ...)
cgroup      : v1 / v2 / tidak ada
Jalur akhir : B1 + udocker / B1 + Docker / pindah ke B2
```
