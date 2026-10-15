#!/usr/bin/env bash
# validate-docs.sh — periksa kualitas dokumen & skrip di repo ini.
#
# Untuk kontributor: jalankan sebelum membuka PR.
#
# Yang diperiksa:
#   1. Setiap .sh bisa dibaca bash (bash -n)
#   2. Setiap halaman punya penanda status (✅/📖/⚠️/🧪)
#   3. Semua link relatif antar-dokumen menunjuk file yang ada
#   4. Pasangan ID/EN seimbang (jumlah baris mirip)
#   5. Perintah kritis ada di kedua bahasa
#
# Status: ✅ TERUJI — dijalankan penulis sebelum rilis pertama.
# ============================================================================
set -u

B=$(printf '\033[1m'); N=$(printf '\033[0m'); G=$(printf '\033[32m')
Y=$(printf '\033[33m'); R=$(printf '\033[31m'); D=$(printf '\033[2m')

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

FAIL=0
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$*"; FAIL=$((FAIL + 1)); }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }

printf '%s\n' "${B}1. Sintaks skrip shell${N}"
for s in scripts/*.sh; do
  if bash -n "$s" 2>/dev/null; then ok "$s"; else bad "$s — sintaks salah"; fi
done

printf '\n%s\n' "${B}2. Penanda status di setiap halaman${N}"
while IFS= read -r f; do
  if head -12 "$f" | grep -qE '✅|📖|⚠️|🧪'; then
    ok "$f"
  else
    bad "$f — tidak ada penanda status (✅/📖/⚠️/🧪)"
  fi
done < <(find docs -name '*.md' | sort)

printf '\n%s\n' "${B}3. Link relatif antar-dokumen${N}"
LINKFAIL=0
while IFS= read -r f; do
  d=$(dirname "$f")
  # Ambil target .md dari markdown link, abaikan http/absolut/anchor
  grep -o '](\([^)]*\.md\)[^)]*)' "$f" 2>/dev/null | sed 's/](//; s/)$//; s/#.*//' | while read -r l; do
    [ -z "$l" ] && continue
    case "$l" in http*|/*) continue ;; esac
    if [ ! -f "$d/$l" ]; then
      printf '  %s✗%s %s → %s (tidak ada)\n' "$R" "$N" "$f" "$l"
    fi
  done
done < <(find docs -name '*.md' | sort)
# grep dalam subshell tidak bisa menaikkan counter; hitung ulang di sini
BROKEN=$(while IFS= read -r f; do
  d=$(dirname "$f")
  grep -o '](\([^)]*\.md\)[^)]*)' "$f" 2>/dev/null | sed 's/](//; s/)$//; s/#.*//' | while read -r l; do
    [ -z "$l" ] && continue
    case "$l" in http*|/*) continue ;; esac
    [ ! -f "$d/$l" ] && echo "x"
  done
done < <(find docs -name '*.md') | wc -l | tr -d ' ')
if [ "${BROKEN:-0}" -eq 0 ]; then ok "semua link lokal valid"; else bad "$BROKEN link rusak"; fi

printf '\n%s\n' "${B}4. Pasangan Bahasa Indonesia ↔ Inggris${N}"
for pair in "baterai.md:battery.md" "tunnel.md:tunnel.md" "autostart.md:autostart.md" \
            "hardening.md:hardening.md" "benchmark.md:benchmark.md" "hardware.md:hardware.md" \
            "jalur-a-tanpa-root.md:path-a-nonroot.md" "jalur-b1-magisk.md:path-b1-magisk.md" \
            "jalur-b2-postmarketos.md:path-b2-postmarketos.md"; do
  idf="docs/id/${pair%%:*}"; enf="docs/en/${pair##*:}"
  if [ ! -f "$idf" ]; then bad "$idf hilang"; continue; fi
  if [ ! -f "$enf" ]; then bad "$enf hilang (pasangan dari $idf)"; continue; fi
  a=$(wc -l < "$idf"); b=$(wc -l < "$enf")
  ratio=$((b * 100 / (a > 0 ? a : 1)))
  if [ "$ratio" -ge 85 ] && [ "$ratio" -le 118 ]; then
    ok "$(basename "$idf") ↔ $(basename "$enf") ($a/$b baris)"
  else
    warn "$(basename "$idf") ↔ $(basename "$enf") tidak seimbang ($a/$b baris)"
  fi
done

printf '\n%s\n' "${B}5. Perintah kritis ada di kedua bahasa${N}"
CMDS="pmbootstrap init|pmbootstrap install|fastboot flash boot|docker compose version|apk add openssh docker|acc -s pc=80|cloudflared tunnel|rc-update add|systemctl enable|nftables|termux-wake-lock|udocker|proot-distro install|charge_full_design|sys.boot_completed|docker.service|restart: unless-stopped|fail2ban|tailscale"
IFS='|'
for c in $CMDS; do
  nid=$(grep -rlF -- "$c" docs/id/ 2>/dev/null | wc -l | tr -d ' ')
  nen=$(grep -rlF -- "$c" docs/en/ 2>/dev/null | wc -l | tr -d ' ')
  if [ "$nid" -gt 0 ] && [ "$nen" -gt 0 ]; then
    ok "$c (ID:$nid EN:$nen)"
  elif [ "$nid" -gt 0 ]; then
    bad "$c ada di ID tapi TIDAK di EN"
  else
    warn "$c tidak ditemukan di ID (mungkin sudah usang)"
  fi
done
unset IFS

printf '\n%s\n' "${B}6. Tabel isi repo di README${N}"
for s in scripts/benchmark.sh scripts/healthcheck.sh scripts/expose-tunnel.sh scripts/battery-limit.sh; do
  if grep -q "$(basename "$s")" README.md; then ok "$(basename "$s") terdaftar"; else warn "$(basename "$s") tidak disebut di README"; fi
done

echo
if [ "$FAIL" -gt 0 ]; then
  printf '%sHASIL: %s masalah harus diperbaiki%s\n' "$R" "$FAIL" "$N"
  exit 1
fi
printf '%sHASIL: semua pemeriksaan lulus%s\n' "$G" "$N"
exit 0
