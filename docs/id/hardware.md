# Memilih HP untuk dijadikan server

> 📖 **RISET** — Rekomendasi device berdasarkan wiki postmarketOS dan sumber
> komunitas. Belum diverifikasi penulis dengan perangkat nyata.

**Tier dukungan adalah segalanya.** HP flagship dengan port yang buruk akan
kalah dari HP kelas menengah yang port-nya `community`. Ini kesalahan paling
mahal yang dilakukan pemula.

---

## 4 baris yang benar-benar menentukan

Tier di wiki bagus sebagai penyaring awal, tapi **tidak** menceritakan apa yang
rusak di server headless. Cek empat hal ini di halaman device-mu:

| # | Yang dicek | Kenapa ini yang menentukan |
|---|---|---|
| 1 | **Wi-Fi** | Titik gagal nomor satu. Kalau Wi-Fi tidak jalan, server-mu tidak punya jaringan. Banyak Qualcomm butuh firmware `ath10k`/`ath11k` yang tidak tersedia. |
| 2 | **USB networking / OTG** | Ini akses konsol-mu saat layar mati, dan jalan keluar kalau Wi-Fi rusak. Tanpa ini, debugging jadi sangat sulit. |
| 3 | **Storage (throughput & wear)** | eMMC HP tua bisa 20–40 MB/s. Itu cukup untuk log, tidak cukup untuk database. |
| 4 | **Thermal headless** | Di laci tanpa aliran udara, throttle datang jauh lebih cepat. Flagship yang panas bisa jadi lebih buruk daripada HP kelas menengah yang dingin. |

**Kalau salah satu dari empat ini buruk, cari HP lain** — kecuali kamu memang
ingin berkontribusi memperbaikinya.

---

## Rekomendasi

### 🥇 OnePlus 6 / 6T — `enchilada` / `fajita`

**Pilihan terbaik yang bisa dibeli bekas.** Ini bukan soal spesifikasi, tapi
soal dukungan: kernelnya mendekati mainline, artinya bug cepat diperbaiki dan
fitur Linux modern tersedia.

- SoC: Snapdragon 845 (8 core, cepat)
- RAM: 6/8/10 GB
- Storage: 64–256 GB UFS
- Kernel: mendekati mainline
- Harga bekas: ~Rp 800rb–1,5jt
- Bootloader: mudah dibuka
- Dukungan GPU: ✓ (Freedreno) — artinya Wayland bisa jalan, meski tidak perlu

**Kenapa direkomendasikan:** paling sering muncul di dokumentasi postmarketOS,
jadi kalau kamu tersangkut, ada orang lain yang sudah mengalami hal yang sama.

### 🥈 Google Pixel (bootloader bisa dibuka)

Bagus untuk **Jalur B1** (Android + Magisk), dan punya port postmarketOS untuk
generasi tertentu.

- Rooting & unlock paling mulus dan paling terdokumentasi
- Dukungan update panjang (Pixel 6+ sampai 5 tahun)
- ⚠️ Cek dulu apakah generasi yang kamu incar ada port postmarketOS-nya

### 🥉 Alternatif lain yang layak dicari

- **Poco F1** (`beryllium`) — Snapdragon 845, RAM besar, populer di komunitas
- **Samsung Galaxy A-series tertentu** — ⚠️ Knox trip permanen saat unlock,
  dan Exynos sering lebih sulit
- **Fairphone** — etis, bisa diperbaiki, tapi mahal dan performa biasa

---

## Yang harus dihindari

| ❌ Hindari | Alasan |
|---|---|
| **MediaTek tanpa port** | Banyak tanpa dokumentasi kernel publik. Peluang berhasil sangat kecil. |
| **Huawei/Honor** | Bootloader biasanya terkunci permanen, tidak ada cara resmi |
| **Samsung flagship** | Knox trip permanen — kehilangan garansi & fitur, tidak bisa dibatalkan |
| **Perangkat "unmaintained"** | Tidak ada yang memperbaiki bug. Kamu sendirian. |
| **HP dengan baterai tidak bisa diganti** | Baterai adalah komponen yang paling dulu rusak |
| **RAM < 2 GB** | Tidak akan nyaman untuk container modern |
| **Bootloader terkunci tanpa metode unlock** | Tidak bisa lanjut ke jalur mana pun yang serius |

---

## Cara memasang target: lepaskan layar?

Banyak orang bertanya-tanya soal ini. Jawaban singkat:

✅ **Keuntungan:**
- Menghemat daya (layar adalah konsumen terbesar)
- Lebih sedikit panas → throttle lebih jarang
- Lebih sedikit titik kerusakan

⚠️ **Risiko:**
- Sebagian perangkat **tidak mau boot tanpa layar terpasang** (menunggu sinyal
  layar). Uji dulu sebelum membongkar permanen.
- Kamu kehilangan akses konsol visual — pastikan SSH/USB networking sudah jalan
  **sebelum** melepas layar.
- Butuh pembongkaran hati-hati; panel dan digitizer mudah retak.

**Rekomendasi:** jalankan dengan layar terpasang dulu minimal 1 minggu, pastikan
autostart dan remote access stabil, baru pertimbangkan melepasnya.

---

## Daftar periksa sebelum membeli

Lakukan ini **sebelum** membayar:

- [ ] Cari HP di [wiki.postmarketos.org/wiki/Devices](https://wiki.postmarketos.org/wiki/Devices)
- [ ] Tier-nya minimal `testing`, idealnya `community`/`main`
- [ ] Baca baris **Wi-Fi** di halaman device — kalau ada catatan masalah, waspada
- [ ] Cek **USB networking** ada
- [ ] Cari "[nama HP] XDA unlock bootloader" — ada metode untuk Android versimu?
- [ ] Cek **cara ganti baterai** — sulit/mahal? Berapa harga baterai penggantinya?
- [ ] Cari di GitHub: "`[nama HP] postmarketOS`" — apakah ada orang yang sudah
      berhasil dan membagikan catatannya?
- [ ] Pastikan **kabel datanya** bisa (bukan hanya kabel cas)
- [ ] Cek spesifikasi RAM & storage sesuai rencanamu

**Aturan praktis:** kalau kamu tidak menemukan minimal satu orang yang sudah
berhasil menjadikan HP itu server Linux, anggap kamu akan jadi orang pertama —
dan itu proyek berbulan-bulan, bukan pekerjaan akhir pekan.

---

## Kontribusi

Kalau kamu sudah berhasil, tambahkan barismu ke tabel di bawah dengan PR:

| Perangkat | SoC | RAM | OS | Docker asli | Suhu beban | Catatan |
|---|---|---|---|---|---|---|
| _(kosong — menunggu kontribusi)_ | | | | | | |

Format laporan:

```
Perangkat   : OnePlus 6 (enchilada)
SoC / RAM   : Snapdragon 845 / 8 GB
OS          : postmarketOS 25.12, UI none, systemd
Docker asli : ya (cgroup v2 tersedia)
Wi-Fi       : jalan (firmware tersedia)
USB net     : jalan
Suhu beban  : 68°C setelah 30 menit
Kendala     : ...
```
