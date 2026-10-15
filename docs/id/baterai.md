# Baterai: jangan sampai HP-nya rusak

> 📖 **RISET** — Nilai dan node kernel diambil dari dokumentasi ACC, SmartBypass,
> dan diskusi komunitas. Belum diuji penulis di perangkat nyata.

**Ini bagian terpenting dari seluruh proyek.** Kalau kamu lupa yang lain, ingat
yang ini: **HP yang dicolok terus di 100 % akan membuat baterainya kembung.**

---

## Kenapa baterai kembung itu serius

Baterai lithium yang terus-menerus di tegangan penuh mengalami pengendapan
litium (lithium plating) dan menumpuk gas di dalam sel. Akibatnya:

- Baterai mengembung → menekan layar → **layar bisa retak dari dalam**
- Kapasitas turun drastis (bisa kehilangan 40 % dalam setahun)
- Risiko **terbakar** — litium yang rusak bisa mengalami thermal runaway

Ini bukan teori. Ini penyebab kematian nomor satu proyek "HP jadi server".
Banyak orang berhasil setup-nya lalu HP-nya rusak 3 bulan kemudian.

**Rentang aman untuk pemakaian permanen: 60–80 %.** Di bawah 80 % saja,
umur pakai baterai bisa berlipat dibanding selalu di 100 %.

---

## Cara membatasi — dari termudah

### 1. Aplikasi, butuh root (paling praktis)

**ACC (Advanced Charging Controller)** — paling matang, mendukung ratusan
perangkat, bekerja dengan Magisk/KernelSU/APatch.

```bash
# Setelah root + Magisk terpasang
# Pasang lewat Magisk, lalu:
acc -s pc=80 mcc=500        # pause charge di 80%, batasi arus 500 mA
acc -s pc=75                # atau rentang 60-75% untuk umur maksimum
acc -r                      # baca dokumentasi lengkap
```

- Sumber: `github.com/VR-25/acc`
- Versi dengan GUI: **AccA** (AccA-ACC app), lebih mudah untuk pemula
- Kelebihan: menentukan node kernel sendiri lewat `acc -t`, jadi lebih tahan
  terhadap kekhasan tiap merek
- `battery idle mode` (alias bypass charging): perangkat berjalan langsung dari
  charger, baterai seperti dicabut — ini **ideal** kalau perangkatmu mendukung.
  Ada mode emulasi untuk perangkat yang tidak mendukung.

**SmartBypass** — alternatif dengan banyak mesin hardware detection:

```
BYPASS_TARGET=80        # simpan di 80%
BYPASS_BAND=2           # cas lagi kalau turun 2%
BYPASS_TEMP_TRIGGER=38  # aktifkan bypass kalau panas 38°C
```
- Sumber: `github.com/mrk9091/SmartBypass`
- Punya fallback `EMULATED` yang bekerja di perangkat apa pun

### 2. Kernel node langsung (skrip repo ini)

```bash
./scripts/battery-limit.sh detect      # cari node yang tersedia
./scripts/battery-limit.sh set 80      # pasang batas + jalankan daemon
./scripts/battery-limit.sh status      # cek
```

Pakai ini kalau kamu tidak mau pasang aplikasi. Keterbatasannya: sebagian
perangkat **mengaktifkan cas kembali sendiri** beberapa detik setelah daemon
mematikannya — kalau begitu, ACC lebih handal karena dia menangani kasus itu.

### 3. Tanpa root, tanpa aplikasi

- **Lepas baterai**, suplai daya langsung ke board (perlu solder — hanya untuk
  yang paham kelistrikan)
- **Cas bergantian:** nyalakan ~2 jam, cabut, ulangi. Repot tapi gratis dan
  efektif. Pakai colokan pintar + jadwal untuk mengotomatiskan.
- **Cek firmware HP-mu:** beberapa merek punya "battery care" / "protect
  battery" bawaan yang membatasi di 80–85 %. Cari di Setelan → Baterai.

---

## Cara memverifikasi batas benar-benar bekerja

Jangan percaya begitu saja — ukur:

```bash
# 1. Cek level sekarang
cat /sys/class/power_supply/battery/capacity

# 2. Cek status cas
cat /sys/class/power_supply/battery/status
# Harus jadi "Not charging" atau "Discharging" saat di atas batas

# 3. Cek apakah casnya menyala sendiri kembali (masalah umum)
while true; do date; cat /sys/class/power_supply/battery/status; sleep 30; done
```

**Kalau status bolak-balik Charging ↔ Not charging setiap beberapa detik:**
batasmu tidak stabil. Pindah ke ACC dengan `battery idle mode`.

Skrip kesehatan di repo ini memeriksa ini otomatis:

```bash
./scripts/healthcheck.sh
# Akan memperingatkan: "baterai 100% & terus Charging — INI YANG BIKIN KEMBUNG"
```

---

## Pantau kesehatan baterai

```bash
# Kapasitas sekarang vs kapasitas desain
cat /sys/class/power_supply/battery/charge_full          # mAh sekarang
cat /sys/class/power_supply/battery/charge_full_design   # mAh saat baru
cat /sys/class/power_supply/battery/cycle_count          # jumlah siklus
```

Kesehatan = `charge_full / charge_full_design × 100 %`. Di bawah 60 % berarti
sudah lemah — ganti baterainya sebelum dijadikan server.

`./scripts/battery-limit.sh status` menghitung ini untukmu.

---

## Suhu juga penting

Baterai yang panas menua jauh lebih cepat. Targetkan **di bawah 35 °C**.

- Jangan taruh HP di laci tertutup tanpa aliran udara
- Jangan taruh di atas permukaan yang menahan panas (kasur, karpet)
- Berdirikan HP-nya (jangan ditidurkan) supaya panas keluar
- Kalau ada, pasang heatsink kecil atau kipas USB — perbedaannya besar

`./scripts/healthcheck.sh` memperingatkan di atas 40 °C dan memberi status
kritis di atas 45 °C.

---

## Ringkasan aturan

1. **Batasi 60–80 %.** Titik. Jangan dilewati.
2. **Pakai ACC** kalau perangkatmu didukung — paling andal.
3. **Verifikasi** dengan `healthcheck.sh`, jangan asumsi.
4. **Jaga suhu di bawah 35 °C** — beri ventilasi.
5. **Cek kesehatan baterai** tiap beberapa bulan; ganti kalau < 60 %.
