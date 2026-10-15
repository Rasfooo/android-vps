#!/usr/bin/env bash
# ============================================================================
# expose-tunnel.sh — bikin service di HP bisa diakses dari internet
# TANPA perlu IP publik / buka port di router.
#
# Kenapa perlu: operator seluler hampir semua pakai CGNAT, jadi HP-mu tidak
# punya IPv4 publik dan port 80/443 masuk diblokir. Tunnel menyelesaikan ini:
# HP keluar (outbound) ke Cloudflare, Cloudflare yang meneruskan trafik masuk.
#
# Pemakaian:
#   ./scripts/expose-tunnel.sh check                 # cek kesiapan
#   ./scripts/expose-tunnel.sh install               # pasang cloudflared
#   ./scripts/expose-tunnel.sh quick 8080            # tunnel cepat (tanpa akun)
#   ./scripts/expose-tunnel.sh named example.com 8080 # tunnel permanen
#
# Status: 🧪 PERLU DIUJI di perangkat nyata. Alur cloudflared adalah API resmi
# Cloudflare, tapi penulis belum menjalankannya di HP. Laporan sangat dihargai.
# ============================================================================
set -u

B=$(printf '\033[1m'); N=$(printf '\033[0m'); D=$(printf '\033[2m')
G=$(printf '\033[32m'); Y=$(printf '\033[33m'); R=$(printf '\033[31m'); C=$(printf '\033[36m')

die() { printf '%s\n' "${R}ERROR:${N} $*" >&2; exit 1; }
info() { printf '%s\n' "${C}→${N} $*"; }
ok()   { printf '%s\n' "${G}✓${N} $*"; }
warn() { printf '%s\n' "${Y}!${N} $*"; }

detect_arch() {
  case "$(uname -m)" in
    aarch64|arm64) echo "arm64" ;;
    armv7l|armv6l|arm) echo "arm" ;;
    x86_64|amd64) echo "amd64" ;;
    *) echo "unknown" ;;
  esac
}

cmd_check() {
  printf '%s\n' "${B}Pemeriksaan kesiapan tunnel${N}"
  echo

  # Arsitektur: menentukan nama file rilis yang harus diunduh
  ARCH=$(detect_arch)
  if [ "$ARCH" = "unknown" ]; then
    warn "Arsitektur $(uname -m) tidak dikenali oleh cloudflared"
  else
    ok "Arsitektur: $ARCH"
  fi

  # cloudflared terpasang?
  if command -v cloudflared >/dev/null 2>&1; then
    ok "cloudflared terpasang: $(cloudflared --version 2>&1 | head -1)"
  else
    warn "cloudflared BELUM terpasang — jalankan: $0 install"
  fi

  # Koneksi keluar (tunnel butuh outbound, bukan inbound)
  if ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; then
    ok "Internet keluar OK"
  else
    warn "Tidak ada internet keluar — tunnel tidak akan bisa jalan"
  fi

  # Apakah punya IP publik? Kalau ya, tunnel sebenarnya opsional.
  PUBIP=$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || echo "")
  if [ -n "$PUBIP" ]; then
    printf '  IP publik terlihat: %s\n' "$PUBIP"
    printf '  %s\n' "${D}Catatan: kalau ini IP CGNAT (operator), port masuk tetap diblokir.${N}"
  fi

  # Cek apakah IP-nya CGNAT: rentang 100.64.0.0/10 = pasti CGNAT
  LOCALIP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
  if [ -n "${LOCALIP:-}" ]; then
    case "$LOCALIP" in
      100.6[4-9].*|100.[7-9][0-9].*|100.1[0-1][0-9].*|100.12[0-7].*)
        warn "IP lokal $LOCALIP ada di rentang CGNAT → kamu WAJIB pakai tunnel" ;;
      *)
        printf '  IP lokal: %s\n' "$LOCALIP" ;;
    esac
  fi
  echo
}

cmd_install() {
  ARCH=$(detect_arch)
  [ "$ARCH" = "unknown" ] && die "Arsitektur tidak didukung: $(uname -m)"

  if command -v cloudflared >/dev/null 2>&1; then
    ok "cloudflared sudah terpasang"
    return 0
  fi

  info "Mengunduh cloudflared untuk $ARCH..."
  URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"

  DEST="${PREFIX:-/usr/local}/bin"
  if [ ! -w "$DEST" ] && [ ! -w "$(dirname "$DEST")" ]; then
    DEST="$HOME/.local/bin"
  fi
  mkdir -p "$DEST"

  if command -v curl >/dev/null 2>&1; then
    curl -fL --progress-bar "$URL" -o "$DEST/cloudflared" || die "unduh gagal dari $URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$DEST/cloudflared" "$URL" || die "unduh gagal"
  else
    die "butuh curl atau wget"
  fi

  chmod +x "$DEST/cloudflared"
  ok "Terpasang di $DEST/cloudflared"

  case ":$PATH:" in
    *":$DEST:"*) : ;;
    *) warn "Tambahkan ke PATH: export PATH=\"$DEST:\$PATH\"" ;;
  esac
}

cmd_quick() {
  PORT="${1:-8080}"
  command -v cloudflared >/dev/null 2>&1 || die "cloudflared belum ada — jalankan: $0 install"

  printf '%s\n' "${B}Tunnel cepat${N} (URL acak, hilang saat proses berhenti)"
  info "Meneruskan http://localhost:$PORT ke URL publik..."
  echo
  printf '%s\n' "${Y}Tekan Ctrl+C untuk berhenti. Catat URL trycloudflare.com yang muncul.${N}"
  echo
  # --no-autoupdate: di HP, update otomatis saat runtime bisa gagal karena izin
  exec cloudflared tunnel --no-autoupdate --url "http://localhost:$PORT"
}

cmd_named() {
  DOMAIN="${1:-}"; PORT="${2:-8080}"
  [ -z "$DOMAIN" ] && die "Pemakaian: $0 named <domain> <port>"
  command -v cloudflared >/dev/null 2>&1 || die "cloudflared belum ada — jalankan: $0 install"

  printf '%s\n' "${B}Tunnel permanen untuk $DOMAIN → port $PORT${N}"
  echo
  printf '%s\n' "Langkah manual yang perlu kamu lakukan (sekali saja):"
  echo "  1. cloudflared tunnel login          # buka URL di browser, pilih domain"
  echo "  2. cloudflared tunnel create hp-vps"
  echo "  3. cloudflared tunnel route dns hp-vps $DOMAIN"
  echo "  4. cloudflared tunnel run hp-vps"
  echo
  printf '%s\n' "${D}Kenapa tidak otomatis? Login butuh browser & interaksi manusia,"
  printf '%s\n' "jadi tidak boleh dilakukan skrip tanpa kamu sadari.${N}"
  echo
  printf '%s\n' "Setelah itu, bikin service supaya jalan otomatis saat boot:"
  echo "  lihat docs/id/autostart.md"
  echo
  printf 'Config contoh untuk domain %s → port %s:\n' "$DOMAIN" "$PORT"
  cat <<YAML

# ~/.cloudflared/config.yml
tunnel: hp-vps
credentials-file: $HOME/.cloudflared/<tunnel-id>.json
ingress:
  - hostname: $DOMAIN
    service: http://localhost:$PORT
  - service: http_status:404
YAML
}

case "${1:-}" in
  check)   cmd_check ;;
  install) cmd_install ;;
  quick)   shift; cmd_quick "$@" ;;
  named)   shift; cmd_named "$@" ;;
  ""|-h|--help)
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *) die "Perintah tidak dikenal: $1 (coba: check | install | quick | named)" ;;
esac
