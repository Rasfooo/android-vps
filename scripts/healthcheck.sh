#!/usr/bin/env bash
# ============================================================================
# healthcheck.sh — pemeriksaan kesehatan HP-server, cocok untuk cron.
#
# Kenapa ada: HP headless gagal dengan cara yang berbeda dari VPS. Baterai
# kembung, throttle, storage penuh, Wi-Fi putus. Semua itu tidak kelihatan
# kalau kamu tidak memeriksanya. Skrip ini memeriksa tepat hal-hal itu.
#
# Pemakaian:
#   ./scripts/healthcheck.sh              # cetak laporan manusiawi
#   ./scripts/healthcheck.sh --json       # keluaran JSON (untuk monitoring)
#   ./scripts/healthcheck.sh --quiet      # hanya cetak kalau ada masalah
#
# Exit code: 0 sehat · 1 ada peringatan · 2 kritis
# Status: 🧪 PERLU DIUJI di perangkat nyata (bagian baterai/suhu butuh Android
# atau kernel dengan sensor; di VPS akan dilewati dengan aman).
# ============================================================================
set -u

MODE="human"
for a in "$@"; do
  case "$a" in
    --json)  MODE="json" ;;
    --quiet) MODE="quiet" ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
  esac
done

WARN=0
CRIT=0
JSON_ITEMS=""

# Simpan temuan. Level: ok | warn | crit
record() {
  level="$1"; key="$2"; msg="$3"
  case "$level" in
    warn) WARN=$((WARN + 1)) ;;
    crit) CRIT=$((CRIT + 1)) ;;
  esac
  [ "$MODE" = "json" ] && JSON_ITEMS="${JSON_ITEMS}${JSON_ITEMS:+,}{\"level\":\"$level\",\"name\":\"$key\",\"message\":\"$msg\"}"
  if [ "$MODE" != "json" ]; then
    case "$level" in
      ok)   printf '  \033[32m✓\033[0m %-22s %s\n' "$key" "$msg" ;;
      warn) printf '  \033[33m!\033[0m %-22s %s\n' "$key" "$msg" ;;
      crit) printf '  \033[31m✗\033[0m %-22s %s\n' "$key" "$msg" ;;
    esac
  fi
}

[ "$MODE" = "human" ] && { echo "Pemeriksaan kesehatan — $(date '+%Y-%m-%d %H:%M:%S %Z')"; echo; }

# ------------------------------------------------------------------- suhu ---
# Ini pemeriksaan TERPENTING untuk HP. HP headless di laci tanpa aliran udara
# akan throttle; kalau dibiarkan, komponen bisa rusak.
FT=0
for z in /sys/class/thermal/thermal_zone*; do
  [ -r "$z/temp" ] || continue
  T=$(cat "$z/temp" 2>/dev/null)
  case "$T" in ''|*[!0-9-]*) continue ;; esac
  [ "$T" -gt 1000 ] && C=$((T / 1000)) || C=$T
  [ "$C" -gt -20 ] && [ "$C" -lt 130 ] || continue
  FT=1
  NAME=$(cat "$z/type" 2>/dev/null || echo zone)
  if   [ "$C" -ge 85 ]; then record crit "suhu:$NAME" "${C}°C — BAHAYA, matikan dan beri pendinginan"
  elif [ "$C" -ge 70 ]; then record warn "suhu:$NAME" "${C}°C — throttle aktif, tambah ventilasi"
  else                       record ok   "suhu:$NAME" "${C}°C"
  fi
done
[ "$FT" -eq 0 ] && record ok "suhu" "tidak ada sensor (normal di VPS)"

# ---------------------------------------------------------------- baterai ---
# Baterai kembung adalah penyebab kematian nomor satu proyek ini.
# Ambil dari sysfs Android; di Linux desktop/VPS biasanya tidak ada.
BATT=""
for b in /sys/class/power_supply/battery /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
  [ -d "$b" ] && { BATT="$b"; break; }
done

if [ -n "$BATT" ]; then
  CAP=$(cat "$BATT/capacity" 2>/dev/null || echo "")
  HEALTH=$(cat "$BATT/health" 2>/dev/null || echo "")
  STATUS=$(cat "$BATT/status" 2>/dev/null || echo "")
  TEMP_B=$(cat "$BATT/temp" 2>/dev/null || echo "")

  if [ -n "$CAP" ]; then
    # Kalau selalu 100% dan Charging terus: itu pola yang merusak baterai
    if [ "$CAP" -ge 100 ] && [ "$STATUS" = "Charging" ]; then
      record crit "baterai" "${CAP}% & terus Charging — INI YANG BIKIN KEMBUNG. Pasang batas 60-80% (docs/battery)"
    elif [ "$CAP" -ge 95 ]; then
      record warn "baterai" "${CAP}% — terlalu tinggi untuk dipakai 24/7, targetkan 60-80%"
    else
      record ok "baterai" "${CAP}%"
    fi
  fi
  case "$HEALTH" in
    Good|good) : ;;
    "") : ;;
    *) record warn "kesehatan baterai" "$HEALTH" ;;
  esac
  # Suhu baterai dalam sepersepuluh derajat
  if [ -n "$TEMP_B" ] && [ "$TEMP_B" -gt 0 ] 2>/dev/null; then
    BT=$((TEMP_B / 10))
    if   [ "$BT" -ge 45 ]; then record crit "suhu baterai" "${BT}°C — berbahaya"
    elif [ "$BT" -ge 40 ]; then record warn "suhu baterai" "${BT}°C — panas"
    else                        record ok   "suhu baterai" "${BT}°C"
    fi
  fi
else
  record ok "baterai" "tidak ada power supply baterai (VPS/desktop)"
fi

# ------------------------------------------------------------ penyimpanan ---
USE=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
if [ -n "${USE:-}" ]; then
  if   [ "$USE" -ge 95 ]; then record crit "disk /" "${USE}% penuh — layanan akan gagal menulis"
  elif [ "$USE" -ge 85 ]; then record warn "disk /" "${USE}% — bersihkan"
  else                         record ok   "disk /" "${USE}%"
  fi
fi

# ------------------------------------------------------------------- RAM ---
if [ -r /proc/meminfo ]; then
  TA=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
  AV=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
  if [ "${TA:-0}" -gt 0 ]; then
    PCT=$((AV * 100 / TA))
    if   [ "$PCT" -le 5 ];  then record crit "RAM" "hanya ${PCT}% tersedia — risiko OOM"
    elif [ "$PCT" -le 15 ]; then record warn "RAM" "${PCT}% tersedia"
    else                         record ok   "RAM" "${PCT}% tersedia"
    fi
  fi
fi

# ---------------------------------------------------------------- uptime ---
if [ -r /proc/uptime ]; then
  UP=$(awk '{printf "%d", $1}' /proc/uptime)
  DAYS=$((UP / 86400))
  # HP yang reboot sendiri terus = tanda tidak stabil (kernel crash / OOM)
  if   [ "$DAYS" -lt 1 ]; then record warn "uptime" "kurang dari 1 hari — cek apakah reboot sendiri"
  else                          record ok   "uptime" "${DAYS} hari"
  fi
fi

# ---------------------------------------------------------------- docker ---
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    RUNNING=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    UNHEALTHY=$(docker ps --filter health=unhealthy -q 2>/dev/null | wc -l | tr -d ' ')
    record ok "docker" "$RUNNING container jalan"
    [ "${UNHEALTHY:-0}" -gt 0 ] && record warn "container" "$UNHEALTHY container tidak sehat"
  else
    record warn "docker" "daemon tidak jalan"
  fi
else
  record ok "docker" "tidak terpasang (normal untuk jalur non-root)"
fi

# ------------------------------------------------------------------ jaringan ---
if ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; then
  record ok "jaringan" "internet terjangkau"
else
  # Wi-Fi putus adalah kegagalan paling umum di HP-server
  record crit "jaringan" "TIDAK ada internet — cek Wi-Fi (penyebab paling umum)"
fi

# ------------------------------------------------------------------ keluaran ---
if [ "$MODE" = "json" ]; then
  STATUS="ok"
  [ "$WARN" -gt 0 ] && STATUS="warn"
  [ "$CRIT" -gt 0 ] && STATUS="crit"
  printf '{"status":"%s","warnings":%d,"criticals":%d,"checks":[%s]}\n' \
    "$STATUS" "$WARN" "$CRIT" "$JSON_ITEMS"
else
  echo
  if   [ "$CRIT" -gt 0 ]; then echo "HASIL: KRITIS ($CRIT kritis, $WARN peringatan)"
  elif [ "$WARN" -gt 0 ]; then echo "HASIL: ada peringatan ($WARN)"
  else                         echo "HASIL: sehat"
  fi
fi

[ "$CRIT" -gt 0 ] && exit 2
[ "$WARN" -gt 0 ] && exit 1
exit 0
