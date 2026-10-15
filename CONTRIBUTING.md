# Kontribusi / Contributing

Terima kasih sudah mau berkontribusi! Repo ini **secara desain bergantung pada
laporan perangkat nyata** — penulisnya belum punya HP uji, jadi laporanmu adalah
kontribusi paling berharga.

_(English below)_

---

## 🇮🇩 Yang paling kami butuhkan

### 1. Laporan perangkat (kontribusi nomor satu)

Kalau kamu menjalankan salah satu jalur di repo ini, laporkan hasilnya — baik
**berhasil maupun gagal**. Laporan gagal sama berharganya, karena mencegah orang
lain membuang waktu.

Buka [issue](../../issues) dengan format:

```
Perangkat   : OnePlus 6 (enchilada)
SoC / RAM   : Snapdragon 845 / 8 GB
Android     : 11 (kalau jalur B1)
OS dipakai  : postmarketOS 25.12, UI none, systemd (kalau B2)
Jalur       : A / B1 / B2
Docker asli : jalan / gagal (error: ...)
cgroup      : v1 / v2 / tidak ada
Wi-Fi       : jalan / gagal
USB net     : jalan / gagal
Suhu beban  : 68°C setelah 30 menit
Langkah gagal: (kalau gagal, nomor langkahnya)
Catatan     : ...
```

Kalau bisa, sertakan keluaran skrip kami:

```bash
./scripts/benchmark.sh > hasil.txt
./scripts/healthcheck.sh >> hasil.txt
# lampirkan hasil.txt ke issue
```

### 2. Node baterai baru

Kalau `./scripts/battery-limit.sh detect` tidak menemukan node yang bisa ditulis
di perangkatmu, cari manual:

```bash
find /sys -name '*charg*' -o -name '*input_suspend*' 2>/dev/null | head -40
```

Lalu tambahkan ke variabel `CANDIDATES` di `scripts/battery-limit.sh` lewat PR.
Sertakan hasil `detect` sebelum dan sesudah, sebagai bukti.

### 3. Halaman perangkat

Kalau kamu berhasil membuat server dari HP tertentu, buat
`docs/id/perangkat/<nama>.md` (dan versi Inggrisnya) berisi catatan spesifik
untuk perangkat itu: firmware yang dipakai, masalah yang ditemui, solusinya.

### 4. Terjemahan & perbaikan

- Terjemahan EN/ID harus **kembar**. Kalau kamu mengubah satu bahasa, ubah
  yang lain di PR yang sama.
- Perbaikan typo, link mati, atau perintah yang salah: sangat diterima.

---

## Aturan menulis (penting untuk repo ini)

### Jujur soal pengujian

Setiap halaman **wajib** diberi penanda status di baris pertama:

| Penanda | Kapan dipakai |
|---|---|
| ✅ **TERUJI** | Kamu sudah menjalankannya dan mencatat hasilnya |
| 📖 **RISET** | Dari dokumentasi resmi, belum kamu jalankan |
| ⚠️ **RISIKO** | Bisa brick / kehilangan data — sebutkan risikonya |
| 🧪 **PERLU DIUJI** | Butuh laporan dari perangkat nyata |

**Jangan pernah menghapus peringatan risiko**, dan jangan mengklaim sesuatu
sudah teruji kalau belum. Repo ini berguna justru karena jujur.

### Jangan mengarang perintah

Kalau kamu tidak yakin perintahnya benar untuk perangkat tertentu, tulis
demikian dan arahkan pembaca ke dokumentasi resmi. Lebih baik "verifikasi di
wiki device-mu" daripada perintah salah yang membrick HP orang.

### Gaya

- Tulis untuk pembaca yang **tidak akan membuka browser untuk tiap baris**
- Sebut **kenapa**, bukan cuma **bagaimana**
- Contoh nyata lebih baik daripada penjelasan abstrak
- Nada langsung, tanpa bahasa pemasaran

---

## Alur PR

1. Fork repo
2. Buat branch: `git checkout -b laporan-oneplus6`
3. Kalau mengubah skrip, uji dulu:
   ```bash
   bash -n scripts/*.sh        # cek sintaks
   ./scripts/benchmark.sh      # pastikan jalan
   ./scripts/healthcheck.sh    # pastikan jalan
   ```
4. Commit dengan pesan jelas (boleh Indonesia atau Inggris)
5. PR — jelaskan **perangkat apa** yang kamu pakai untuk menguji

### Yang membuat PR cepat di-merge

- Ada laporan perangkat nyata (untuk perubahan yang menyentuh hardware)
- Perintah sudah dijalankan, bukan disalin dari tempat lain
- Kedua bahasa diperbarui bersama
- Penanda status jujur

---

# 🇬🇧 Contributing

Thanks for helping! This repo **by design depends on real-device reports** — the
author had no test phone when it was written, so your report is the most
valuable contribution.

## What we need most

1. **Device reports** — whether it **worked or failed**. Failure reports matter
   just as much; they save other people time. Use the issue template above.
2. **New battery nodes** — if `battery-limit.sh detect` finds nothing writable
   on your device, run `find /sys -name '*charg*' -o -name '*input_suspend*'`
   and add the working node to the `CANDIDATES` variable via PR, with `detect`
   output before and after as evidence.
3. **Device pages** — a `docs/en/devices/<name>.md` note with firmware used,
   problems hit, and fixes.
4. **Translations** — EN and ID must stay **mirrored**. Change both in the same
   PR.

## Writing rules

- **Every page must carry a status marker** on its first line: ✅ TESTED ·
  📖 RESEARCHED · ⚠️ RISK · 🧪 NEEDS TESTING.
- **Never remove a risk warning**, and never claim something is tested that
  you have not run. This repo is useful precisely because it is honest.
- **Do not invent commands.** If unsure for a specific device, say so and point
  to the official docs. "Verify on your device wiki" beats a wrong command that
  bricks someone's phone.
- Write for a reader who **won't open a browser for every line**. Explain *why*,
  not just *how*. Direct tone, no marketing language.

## PR flow

1. Fork, branch (`git checkout -b report-oneplus6`)
2. If you touched scripts: `bash -n scripts/*.sh`, then run
   `./scripts/benchmark.sh` and `./scripts/healthcheck.sh`
3. Commit with a clear message (Indonesian or English)
4. Open the PR and state **which device** you tested on

## License

By contributing you agree your work is released under the [MIT License](LICENSE).
