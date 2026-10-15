# Uji performa: apakah HP-mu cukup kuat?

> ✅ **TERUJI** — `scripts/benchmark.sh` sudah dijalankan penulis di Debian 13
> (hasil contoh di bawah adalah keluaran nyata). Bagian perbandingan HP adalah
> estimasi dan akan diperbarui dengan laporan kontributor.

Pertanyaan sebenarnya bukan "HP saya cukup kuat?" tapi
**"cukup kuat untuk apa?"** Skrip ini memberi angka supaya keputusannya
berbasis data.

---

## Jalankan

```bash
chmod +x scripts/benchmark.sh
./scripts/benchmark.sh

# Simpan hasilnya untuk dibandingkan / dilaporkan
./scripts/benchmark.sh > hasil-$(uname -m).txt
```

Tidak butuh dependensi apa pun — hanya `bash` dan `/proc` (Linux apa pun,
termasuk di dalam Termux/proot).

---

## Apa yang diukur, dan kenapa itu penting

| Bagian | Kenapa relevan untuk server |
|---|---|
| **CPU (bilangan prima)** | Kinerja single-thread — yang menentukan untuk API, bot, web |
| **Tulis disk (dengan fsync)** | Yang paling sering mengecewakan di eMMC HP tua |
| **RAM & swap** | HP RAM kecil tanpa swap akan OOM saat container jalan |
| **Suhu** | Di laci tanpa ventilasi, throttle datang cepat |
| **Jenis disk** | eMMC = wear nyata, jangan disk berat-tulis |
| **Capability** | Menentukan kamu bisa `root`/`docker` atau tidak |

---

## Contoh keluaran (host uji penulis)

Ini keluaran **nyata**, dijalankan di server pengembangan (bukan HP):

```
2. CPU
Model      : Intel(R) Xeon(R) W-2145 CPU @ 3.70GHz
Core logis : 14

3. RAM
Total      : 235.9 GB
Tersedia   : 107.7 GB
Swap       : 0.0 GB

4. PENYIMPANAN
Uji tulis disk (64 MB):
Kecepatan  : 793.9 MB/s (0.08 detik)

5. UJI BEBAN CPU
Menghitung bilangan prima sampai 30.000 (single-thread)...
Waktu      : 0.12 detik
Penilaian  : sangat cepat
```

**Gunakan ini sebagai titik acuan.** HP bekas yang bagus biasanya:

| Metrik | HP bekas layak | VPS $5 | Server di atas |
|---|---|---|---|
| Prima 30k | 0,5–2 detik | 1–3 detik | 0,1 detik |
| Tulis disk | 30–150 MB/s | 100–400 MB/s | 800+ MB/s |
| RAM | 4–12 GB | 1–2 GB | — |

Kalau HP-mu **lebih cepat dari VPS $5**, memakai HP masuk akal secara ekonomi.
Kalau lebih lambat, pertimbangkan ulang.

---

## Tafsir hasilnya

Skrip memberi penilaian otomatis:

| Hasil | Artinya |
|---|---|
| **sangat cepat** (< 1 s) | Bisa menjalankan apa saja |
| **cepat** (1–3 s) | Setara VPS menengah, aman untuk banyak service |
| **sedang** (3–8 s) | Service ringan, batasi jumlah container |
| **lambat** (8–20 s) | Cron, bot, tugas ringan saja |
| **sangat lambat** (> 20 s) | Pertimbangkan HP lain |

**Perhatikan angka tulis disk.** Kalau di bawah 20 MB/s, database akan terasa
sangat lambat dan flash wear menjadi masalah nyata.

---

## Uji tambahan yang berguna

### 1. Suhu saat beban penuh (throttling)

Ini yang tidak terlihat dari skor sintetis: apakah HP-mu throttle?

```bash
# Catat suhu awal
for z in /sys/class/thermal/thermal_zone*/temp; do
  awk -v f="$z" 'BEGIN{}{printf "%s: %.1f°C\n", f, $1/1000}' "$z" 2>/dev/null
done

# Beri beban 10 menit dengan 4 proses
for i in 1 2 3 4; do
  (timeout 600 sh -c 'while :; do :; done') &
done

# Setiap 30 detik, catat suhu dan frekuensi
while true; do
  date '+%H:%M:%S'
  cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -3 | awk '{printf "%.1f°C ", $1/1000}'
  echo
  sleep 30
done
```

Kalau suhu naik melewati 70–80 °C dan frekuensi turun, HP-mu **throttle**.
Artinya performa puncak hanya sebentar — penting untuk beban berkepanjangan.

### 2. Uji tulis berkepanjangan (flash wear)

```bash
# Tulis 2 GB dan lihat apakah kecepatan turun drastis (cache habis)
dd if=/dev/zero of=/tmp/big.bin bs=1M count=2048 conv=fsync
rm /tmp/big.bin
```

Kecepatan yang jatuh dari 100 MB/s ke 5 MB/s menunjukkan cache habis dan itu
kecepatan asli eMMC-nya.

### 3. Uji jaringan

```bash
# Latensi & throughput ke internet
ping -c 10 1.1.1.1
curl -o /dev/null -s -w 'Download: %{speed_download} B/s\n' \
  https://speed.cloudflare.com/__down?bytes=100000000
```

---

## Kalau hasilnya jelek

1. **Panas?** Beri ventilasi. Perbedaan suhu 15 °C bisa mengubah performa
   berkepanjangan.
2. **Disk lambat?** Pindahkan data ke microSD, atau kurangi penulisan log.
3. **RAM habis?** Matikan Android (kalau di jalur B1), atau postmarketOS dengan
   UI `none` (jalur B2).
4. **CPU lambat?** Batasi ke tugas ringan: cron, bot, sinkronisasi. Jangan
   jalankan database besar.

---

## Laporkan hasilmu

Kami ingin membangun tabel perbandingan perangkat nyata. Kirim:

```
Perangkat : OnePlus 6 (enchilada)
RAM       : 8 GB
Prima 30k : 0.8 detik
Tulis disk: 120 MB/s
Suhu idle : 32°C
Suhu beban: 68°C (throttle: ya/tidak)
OS        : postmarketOS 25.12
```

`./scripts/benchmark.sh` sudah mencetak hampir semua ini.
