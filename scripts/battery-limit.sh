#!/usr/bin/env bash
# ============================================================================
# battery-limit.sh — batasi pengisian baterai 60-80% supaya HP tidak kembung.
#
# INI BAGIAN TERPENTING DARI SELURUH PROYEK.
# HP yang dicolok 24/7 dan terus di 100% akan mengalami pengendapan litium dan
# baterai mengembung dalam hitungan bulan. Baterai kembung bisa merusak layar
# dan berisiko terbakar. Batas 60-80% memperpanjang umur baterai berkali-kali.
#
# Pemakaian:
#   ./scripts/battery-limit.sh status          # lihat kondisi & dukungan
#   ./scripts/battery-limit.sh detect          # cari node kernel yang tersedia
#   ./scripts/battery-limit.sh set 80          # batasi di 80%
#   ./scripts/battery-limit.sh off             # matikan batas
#
# Syarat: ROOT. Tanpa root, pakai aplikasi seperti AccA/ACC (lihat docs/battery).
# Status: 🧪 PERLU DIUJI — butuh HP nyata. Node kernel berbeda-beda per merek,
# jadi skrip ini mencari, bukan menebak.
# ============================================================================
set -u

B=$(printf '\033[1m'); N=$(printf '\033[0m'); D=$(printf '\033[2m')
G=$(printf '\033[32m'); Y=$(printf '\033[33m'); R=$(printf '\033[31m'); C=$(printf '\033[36m')

die()  { printf '%s\n' "${R}ERROR:${N} $*" >&2; exit 1; }
info() { printf '%s\n' "${C}→${N} $*"; }
ok()   { printf '%s\n' "${G}✓${N} $*"; }
warn() { printf '%s\n' "${Y}!${N} $*"; }

need_root() {
  [ "$(id -u 2>/dev/null)" = "0" ] || die "Butuh root. Jalankan dengan 'su -c' atau 'sudo'.
Tanpa root: pakai aplikasi ACC/AccA (lihat docs/id/baterai.md)."
}

batt_dir() {
  for b in /sys/class/power_supply/battery /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
    [ -d "$b" ] && { echo "$b"; return 0; }
  done
  return 1
}

# Node-node pengendali cas. Urutan berdasarkan seberapa umum & seberapa baik
# bekerja. Format: "path|nilai_untuk_MATIKAN_CAS|nilai_untuk_NYALAKAN_CAS"
CANDIDATES="
/sys/class/power_supply/battery/input_suspend|1|0
/sys/class/power_supply/battery/charging_enabled|0|1
/sys/class/power_supply/battery/charge_enable|0|1
/sys/class/power_supply/battery/batt_slate_mode|1|0
/sys/class/power_supply/battery/store_mode|1|0
/sys/class/power_supply/battery/charge_disable|1|0
/sys/class/power_supply/battery/input_current_limited|1|0
/sys/devices/platform/mtk_charger/charging_enabled|0|1
/proc/mtk_battery_cmd/en_power_path|0|1
"

cmd_status() {
  BD=$(batt_dir) || die "Tidak menemukan baterai di /sys/class/power_supply/.
Kalau ini HP/tablet Android tanpa root, coba skrip ini setelah root."
  printf '%s\n' "${B}Status baterai: $BD${N}"
  for f in capacity status health temp voltage_now technology cycle_count charge_full charge_full_design; do
    if [ -r "$BD/$f" ]; then
      V=$(cat "$BD/$f" 2>/dev/null)
      case "$f" in
        temp)               [ "$V" -gt 1000 ] 2>/dev/null && V="$((V/10))°C" || V="${V}°C" ;;
        voltage_now)        [ "$V" -gt 1000000 ] 2>/dev/null && V="$(awk -v v="$V" 'BEGIN{printf "%.2f V", v/1000000}')" ;;
        charge_full|charge_full_design) V="$(awk -v v="$V" 'BEGIN{printf "%.0f mAh", v/1000}')" ;;
        capacity)           V="${V}%" ;;
      esac
      printf '  %-20s %s\n' "$f" "$V"
    fi
  done

  # Skor kesehatan: kapasitas sekarang vs kapasitas desain
  if [ -r "$BD/charge_full" ] && [ -r "$BD/charge_full_design" ]; then
    F=$(cat "$BD/charge_full"); Dsn=$(cat "$BD/charge_full_design")
    if [ "${Dsn:-0}" -gt 0 ]; then
      awk -v f="$F" -v d="$Dsn" 'BEGIN{
        p = f*100/d;
        printf "\n  %sKesehatan baterai: %.1f%%%s\n", "", p, "";
        if (p < 60) print "  ! Baterai sudah lemah — sebaiknya diganti sebelum jadi server";
        else if (p < 80) print "  ! Mulai menurun, masih layak untuk server";
        else print "  ✓ Masih sehat";
      }'
    fi
  fi
  echo
}

cmd_detect() {
  need_root
  BD=$(batt_dir) || die "Tidak menemukan baterai"
  printf '%s\n' "${B}Mencari node pengendali cas di perangkat ini${N}"
  echo

  FOUND=""
  echo "$CANDIDATES" | while IFS='|' read -r path off_val on_val; do
    [ -z "$path" ] && continue
    if [ -w "$path" ]; then
      printf '  %s✓%s %s %s(bisa ditulis: matikan=%s, nyalakan=%s)%s\n' \
        "$G" "$N" "$path" "$D" "$off_val" "$on_val" "$N"
    elif [ -e "$path" ]; then
      printf '  %s!%s %s %s(ada tapi tidak bisa ditulis — izin?)%s\n' "$Y" "$N" "$path" "$D" "$N"
    fi
  done

  echo
  printf '%s\n' "Kalau tidak ada yang bisa ditulis, cari manual dengan:"
  echo "  ${D}find /sys -name '*charg*' -o -name '*input_suspend*' 2>/dev/null | head -40${N}"
  echo
  printf '%s\n' "Atau pakai ACC/AccA yang sudah menangani puluhan varian perangkat:"
  echo "  ${D}https://github.com/VR-25/acc${N}"
  echo
  warn "Skrip ini sengaja TIDAK menebak. Node yang salah bisa membuat cas tidak terkendali."
}

cmd_set() {
  TARGET="${1:-80}"
  case "$TARGET" in ''|*[!0-9]*) die "Batas harus angka persen, contoh: 80" ;; esac
  [ "$TARGET" -ge 20 ] && [ "$TARGET" -le 95 ] || die "Batas wajar antara 20-95"

  need_root
  BD=$(batt_dir) || die "Tidak menemukan baterai"
  HOLD=$((TARGET - 2))     # mulai cas lagi kalau turun 2% (histeresis)

  # Cari node yang bisa ditulis
  SWITCH=""; OFF_V=""; ON_V=""
  echo "$CANDIDATES" | while IFS='|' read -r path off_val on_val; do
    [ -z "$path" ] && continue
    if [ -w "$path" ] && [ -z "$SWITCH" ]; then
      SWITCH="$path"; OFF_V="$off_val"; ON_V="$on_val"
      printf '%s\n' "  → memakai node: $SWITCH"
      break
    fi
  done

  if [ -z "${SWITCH:-}" ]; then
    warn "Tidak ada node yang bisa ditulis otomatis di perangkat ini."
    echo "  Jalankan: $0 detect"
    echo "  Lalu daftarkan node-nya di variabel CANDIDATES skrip ini, dan kirim PR."
    exit 1
  fi

  SCRIPT="/data/adb/battery-limit.sh"
  if [ ! -d /data/adb ]; then
    SCRIPT="/usr/local/bin/battery-limit-loop.sh"
    mkdir -p /usr/local/bin
  fi

  info "Menulis daemon batas cas ke $SCRIPT"
  cat > "$SCRIPT" <<EOF
#!/system/bin/sh
# Dibuat oleh battery-limit.sh — batas cas ${TARGET}% (histeresis ${HOLD}%)
# Node: ${SWITCH}
# Target 60-80% untuk server 24/7. Lihat docs/baterai.md
SWITCH="${SWITCH}"
OFF_V="${OFF_V}"
ON_V="${ON_V}"
TARGET=${TARGET}
HOLD=${HOLD}

while true; do
  CAP=\$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
  if [ -n "\$CAP" ]; then
    if [ "\$CAP" -ge "\$TARGET" ]; then
      echo "\$OFF_V" > "\$SWITCH" 2>/dev/null
    elif [ "\$CAP" -le "\$HOLD" ]; then
      echo "\$ON_V" > "\$SWITCH" 2>/dev/null
    fi
  fi
  sleep 30
done
EOF
  chmod +x "$SCRIPT"
  ok "Daemon ditulis: $SCRIPT"

  info "Menjalankan sekarang (background)..."
  nohup sh "$SCRIPT" >/dev/null 2>&1 &
  sleep 2

  CAP=$(cat "$BD/capacity" 2>/dev/null || echo "?")
  ok "Batas aktif: ${TARGET}% (cas mulai lagi di ${HOLD}%) · baterai sekarang ${CAP}%"
  echo
  warn "Ini belum otomatis setelah reboot. Tambahkan ke autostart:"
  echo "  lihat docs/id/autostart.md"
  echo
  printf '%s\n' "${D}Catatan: sebagian perangkat mengaktifkan cas kembali sendiri setelah"
  printf '%s\n' "beberapa detik. Kalau begitu, pakai ACC/AccA yang lebih tahan lama.${N}"
}

cmd_off() {
  need_root
  BD=$(batt_dir) || die "Tidak menemukan baterai"
  echo "$CANDIDATES" | while IFS='|' read -r path off_val on_val; do
    [ -z "$path" ] && continue
    if [ -w "$path" ]; then
      echo "$on_val" > "$path" 2>/dev/null && ok "Cas diaktifkan kembali: $path"
    fi
  done
  # Hentikan daemon kalau ada
  pkill -f battery-limit 2>/dev/null && ok "Daemon batas cas dihentikan" || true
  rm -f /data/adb/battery-limit.sh /usr/local/bin/battery-limit-loop.sh 2>/dev/null
  ok "Selesai — cas kembali normal"
}

case "${1:-}" in
  status) cmd_status ;;
  detect) cmd_detect ;;
  set)    shift; cmd_set "$@" ;;
  off)    cmd_off ;;
  ""|-h|--help)
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *) die "Perintah tidak dikenal: $1 (coba: status | detect | set | off)" ;;
esac

