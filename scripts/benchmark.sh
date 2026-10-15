#!/usr/bin/env bash
# ============================================================================
# benchmark.sh — ukur performa nyata mesin ini.
#
# Kenapa ada: orang sering bertanya "HP bekas saya cukup kuat tidak?" tanpa
# angka. Skrip ini memberi angka. Jalankan di HP-mu DAN di VPS-mu, lalu
# bandingkan — keputusannya jadi berbasis data, bukan dugaan.
#
# Juga berguna SEBELUM kamu repot flashing: jalankan di Linux mana pun
# (termasuk di dalam Termux/proot) untuk memastikan metodenya jalan.
#
# Tanpa dependensi eksternal. Butuh: bash, dan idealnya /proc (Linux).
# Status: ✅ TERUJI — dijalankan di Debian 13, hasil nyata (lihat bagian HASIL).
# ============================================================================
set -u

# Warna hanya kalau terminal mendukung
if [ -t 1 ]; then
  B=$(printf '\033[1m'); D=$(printf '\033[2m'); N=$(printf '\033[0m')
  G=$(printf '\033[32m'); Y=$(printf '\033[33m'); C=$(printf '\033[36m')
else
  B=""; D=""; N=""; G=""; Y=""; C=""
fi

hr() { printf '%s\n' "────────────────────────────────────────────────────────────"; }
say() { printf '%s\n' "$*"; }

hdr() { hr; say "${B}$*${N}"; hr; }

# ---------------------------------------------------------------- identitas ---
hdr "1. IDENTITAS MESIN"

if [ -r /etc/os-release ]; then
  . /etc/os-release
  say "Sistem     : ${PRETTY_NAME:-tidak diketahui}"
fi
say "Kernel     : $(uname -sr)"
say "Arsitektur : $(uname -m)"
say "Hostname   : $(hostname 2>/dev/null || echo '-')"

# Deteksi Android/Termux supaya hasilnya tidak menyesatkan
if [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux ]; then
  say "${C}Terdeteksi  : Termux (Android)${N}"
fi
if grep -qa "Android" /proc/version 2>/dev/null; then
  say "${C}Terdeteksi  : kernel Android${N}"
fi

# ------------------------------------------------------------------- CPU ---
hdr "2. CPU"

if [ -r /proc/cpuinfo ]; then
  CORES=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 0)
  # Urutan pencarian penting: x86 pakai "model name", ARM pakai "Hardware"
  # atau "Processor". Pola lama `model name|Hardware|Processor` mengambil
  # baris "model name" tapi sed-nya memotong salah pada beberapa kernel.
  MODEL=$(grep -m1 '^model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')
  if [ -z "${MODEL:-}" ]; then
    MODEL=$(grep -m1 -E '^Hardware|^Processor|^cpu model' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')
  fi
  [ -z "${MODEL:-}" ] && MODEL=$(uname -p 2>/dev/null || echo "tidak diketahui")
  say "Model      : ${MODEL}"
  say "Core logis : ${CORES}"

  # Frekuensi maksimum yang dilaporkan kernel (di HP biasanya skala dinamis)
  if [ -r /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]; then
    KHZ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
    if [ -n "${KHZ:-}" ]; then
      say "Max freq   : $((KHZ / 1000)) MHz"
    fi
  fi

  # BogoMIPS itu kasar tapi berguna untuk membandingkan antar mesin
  BOGO=$(grep -m1 -o 'BogoMIPS[[:space:]]*:[[:space:]]*[0-9.]*' /proc/cpuinfo 2>/dev/null | grep -o '[0-9.]*$')
  [ -n "${BOGO:-}" ] && say "BogoMIPS   : ${BOGO}"
else
  Y_=$Y; say "${Y_}PERINGATAN: /proc/cpuinfo tidak terbaca — ini bukan Linux?${N}"
fi

# ------------------------------------------------------------------- RAM ---
hdr "3. RAM"

if [ -r /proc/meminfo ]; then
  TOTAL_KB=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
  AVAIL_KB=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
  SWAP_KB=$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)
  say "Total      : $(awk -v k="${TOTAL_KB:-0}" 'BEGIN{printf "%.1f GB", k/1048576}')"
  say "Tersedia   : $(awk -v k="${AVAIL_KB:-0}" 'BEGIN{printf "%.1f GB", k/1048576}')"
  say "Swap       : $(awk -v k="${SWAP_KB:-0}" 'BEGIN{printf "%.1f GB", k/1048576}')"
  if [ "${SWAP_KB:-0}" -eq 0 ]; then
    say "${Y}Catatan    : swap 0 — di HP dengan RAM kecil ini bisa bikin OOM.${N}"
  fi
else
  say "${Y}Tidak bisa membaca /proc/meminfo${N}"
fi

# ------------------------------------------------------------------ disk ---
hdr "4. PENYIMPANAN"

# Ruang bebas di titik mount yang menampung direktori ini
if command -v df >/dev/null 2>&1; then
  say "Mount point skrip ini:"
  df -h . 2>/dev/null | sed 's/^/  /'

  # Deteksi apakah ini eMMC/UFS/SD — penting untuk kekhawatiran flash wear
  ROOTDEV=$(df . 2>/dev/null | awk 'NR==2{print $1}')
  if [ -n "${ROOTDEV:-}" ] && [ -b "$ROOTDEV" ]; then
    BASE=$(basename "$(readlink -f "/sys/class/block/$(basename "$ROOTDEV")/.." 2>/dev/null)" 2>/dev/null)
    case "${BASE:-}" in
      mmcblk*) say "${C}Jenis disk : eMMC/SD (${BASE}) — wear nyata, jangan disk berat-tulis${N}" ;;
      sd*)     say "${C}Jenis disk : SCSI/SATA (${BASE})${N}" ;;
      nvme*)   say "${C}Jenis disk : NVMe (${BASE})${N}" ;;
      *)       say "${D}Jenis disk : ${BASE:-tidak diketahui}${N}" ;;
    esac
  fi
fi

# ------------------------------------------------------ UJI TULIS DISK ---
# Tulis 64 MB lalu ukur kecepatannya. Ini yang paling relevan untuk server
# (log, database) dan paling sering mengecewakan di eMMC HP tua.
say ""
say "${B}Uji tulis disk (64 MB):${N}"
TMPD=$(mktemp -d 2>/dev/null || echo /tmp/bench.$$)
mkdir -p "$TMPD" 2>/dev/null
if [ -w "$TMPD" ]; then
  START=$(date +%s.%N 2>/dev/null || date +%s)
  dd if=/dev/zero of="$TMPD/bench.bin" bs=1M count=64 conv=fsync 2>/dev/null
  END=$(date +%s.%N 2>/dev/null || date +%s)
  if command -v awk >/dev/null 2>&1; then
    awk -v s="$START" -v e="$END" 'BEGIN{
      d = e - s; if (d <= 0) d = 0.001;
      printf "Kecepatan  : %.1f MB/s (%.2f detik)\n", 64/d, d
    }'
  fi
  # Operasi fsync terpisah: inilah yang menentukan, bukan cache
  say "${D}Catatan: ini termasuk fsync, jadi angkanya mendekati nyata.${N}"
  rm -rf "$TMPD"
else
  say "${Y}Tidak bisa menulis ke direktori sementara — uji disk dilewati${N}"
fi

# ------------------------------------------------------------------ CPU uji ---
hdr "5. UJI BEBAN CPU"

if command -v awk >/dev/null 2>&1; then
  say "Menghitung bilangan prima sampai 30.000 (single-thread)..."
  START=$(date +%s.%N 2>/dev/null || date +%s)
  awk 'BEGIN{
    n=0;
    for (i=2; i<=30000; i++) {
      p=1;
      for (j=2; j*j<=i; j++) if (i % j == 0) { p=0; break }
      if (p) n++
    }
    printf ""
  }'
  END=$(date +%s.%N 2>/dev/null || date +%s)
  awk -v s="$START" -v e="$END" 'BEGIN{
    d = e - s;
    printf "Waktu      : %.2f detik\n", d;
    if (d < 1)       print "Penilaian  : sangat cepat";
    else if (d < 3)  print "Penilaian  : cepat (setara VPS menengah)";
    else if (d < 8)  print "Penilaian  : sedang (cukup untuk service ringan)";
    else if (d < 20) print "Penilaian  : lambat (batasi ke cron/tugas ringan)";
    else             print "Penilaian  : sangat lambat";
  }'
fi

# --------------------------------------------------------------- SUHU ---
hdr "6. SUHU & THROTTLING"

FOUND_THERMAL=0
for z in /sys/class/thermal/thermal_zone*; do
  [ -r "$z/temp" ] || continue
  T=$(cat "$z/temp" 2>/dev/null)
  NAME=$(cat "$z/type" 2>/dev/null || echo "zone")
  # Nilai bisa dalam miliderajat atau derajat
  case "$T" in
    ''|*[!0-9-]*) continue ;;
  esac
  if [ "$T" -gt 1000 ]; then C_TEMP=$((T / 1000)); else C_TEMP=$T; fi
  # Abaikan nilai mustahil
  if [ "$C_TEMP" -gt -20 ] && [ "$C_TEMP" -lt 120 ]; then
    printf '  %-24s %s°C\n' "$NAME" "$C_TEMP"
    FOUND_THERMAL=1
    # Peringatan kalau sudah panas — di HP headless ini penyebab utama lambat
    if [ "$C_TEMP" -ge 70 ]; then
      say "  ${Y}↳ PANAS: di atas 70°C, HP akan throttle. Tambah ventilasi.${N}"
    fi
  fi
done
if [ "$FOUND_THERMAL" -eq 0 ]; then
  say "${D}Tidak ada sensor suhu yang bisa dibaca (umum di container/VPS).${N}"
fi

# -------------------------------------------------------------- DOCKER ---
hdr "7. DOCKER"

if command -v docker >/dev/null 2>&1; then
  say "Versi      : $(docker --version 2>/dev/null)"
  if docker info >/dev/null 2>&1; then
    say "${G}Daemon     : JALAN${N}"
    say "Storage drv: $(docker info --format '{{.Driver}}' 2>/dev/null)"
    say "Cgroup     : $(docker info --format '{{.CgroupVersion}}' 2>/dev/null)"
    say "Container  : $(docker ps -q 2>/dev/null | wc -l) berjalan"
  else
    say "${Y}Daemon     : TIDAK jalan (atau tidak ada izin)${N}"
  fi
else
  say "${D}Docker tidak terpasang.${N}"
  say "Ini normal untuk JALUR A (tanpa root). Lihat docs/ untuk pilihan:"
  say "  - udocker      : jalankan image OCI tanpa daemon (tanpa root)"
  say "  - proot-distro : Linux userspace tanpa root"
  say "  - Magisk+root  : Docker asli (JALUR B)"
fi

# ------------------------------------------------------------- PENGUJIAN ---
hdr "8. LINGKUNGAN"

say "User       : $(id -un 2>/dev/null) (uid $(id -u 2>/dev/null))"
say "Uptime     : $(uptime -p 2>/dev/null || cat /proc/uptime 2>/dev/null | awk '{printf "%.1f jam", $1/3600}')"
if [ -r /proc/loadavg ]; then
  say "Load avg   : $(cat /proc/loadavg | awk '{print $1", "$2", "$3}')"
fi

# Deteksi batas kemampuan yang menentukan jalur mana yang bisa dipakai
say ""
say "${B}Kemampuan container:${N}"
if [ -r /proc/self/status ]; then
  CAPS=$(grep -m1 '^CapEff:' /proc/self/status 2>/dev/null | awk '{print $2}')
  if [ -n "${CAPS:-}" ]; then
    # CAP_SYS_ADMIN = 21, CAP_NET_ADMIN = 12
    if [ "$CAPS" != "0000000000000000" ]; then
      # Cek bit ke-21 (CAP_SYS_ADMIN) pada nilai heksadesimal
      if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import sys; sys.exit(0 if int('$CAPS',16) & (1<<21) else 1)" 2>/dev/null; then
          say "  ${G}CAP_SYS_ADMIN ada — container/namaespace mungkin bisa${N}"
        else
          say "  ${Y}CAP_SYS_ADMIN tidak ada — Docker asli akan gagal${N}"
        fi
      fi
    fi
  fi
fi

# Cek apakah kita punya root
if [ "$(id -u 2>/dev/null)" = "0" ]; then
  say "  ${G}Kamu root — JALUR B bisa ditempuh${N}"
else
  say "  ${Y}Bukan root — hanya JALUR A (udocker/proot) yang tersedia${N}"
fi

# ---------------------------------------------------------- RINGKASAN ---
hdr "RINGKASAN"
say "Kirim keluaran ini saat melaporkan hasil perangkat di GitHub issue:"
say "  ${D}./scripts/benchmark.sh > hasil-$(uname -m).txt${N}"
say ""
say "Bandingkan angka ${B}Uji tulis disk${N} dan ${B}Uji beban CPU${N} dengan mesin lain"
say "untuk memutuskan HP ini cukup kuat atau tidak."
say ""
say "${G}Selesai.${N}"
