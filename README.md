<div align="center">

# 📱 → 🖥️ Android VPS

**Turn a retired Android phone into a real Linux server.**
**Ubah HP Android bekas jadi server Linux sungguhan.**

Root · Docker asli · akses publik · systemd — bukan sekadar mainan Termux.

[🇬🇧 English](#-english) · [🇮🇩 Bahasa Indonesia](#-bahasa-indonesia) · [Peta Jalan](#-peta-jalan) · [Berkas](docs/)

</div>

---

## ⚠️ Baca ini dulu / Read this first

Repo ini **jujur soal apa yang belum diuji**. Tidak semua perintah di sini sudah
diverifikasi end-to-end, karena penulis belum punya HP uji saat repo ini dibuat.

| Penanda | Arti |
|---|---|
| ✅ **Teruji** | Sudah dijalankan dan diverifikasi, hasilnya dicatat |
| 📖 **Riset** | Berdasarkan dokumentasi resmi + sumber, belum dijalankan penulis |
| ⚠️ **Risiko** | Bisa mengakibatkan brick / kehilangan data. Baca peringatannya |
| 🧪 **Perlu diuji** | Kami butuh kontribusi laporan dari perangkat nyata |

Setiap halaman menandai statusnya. Kalau kamu menjalankan salah satu bagian
bertanda 🧪 dan berhasil/gagal, buka [issue](../../issues) atau PR — laporan
perangkat nyata adalah kontribusi paling berharga di repo ini.

> **Dokumentasi sumber** tetap yang paling benar: [Termux Wiki](https://wiki.termux.com/),
> [postmarketOS Wiki](https://wiki.postmarketos.org/), [Magisk Docs](https://topjohnwu.github.io/Magisk/).

---

# 🇬🇧 English

## What this is

A practical guide to converting an old Android phone into a headless Linux
server — **with a real Docker daemon**, reachable from the internet, and able to
survive reboots without you babysitting it.

## Why bother? The honest comparison

An old phone is often **stronger than a cheap VPS**:

| | Old phone | $5 VPS |
|---|---|---|
| RAM / CPU | 4–12 GB, 8 cores | 1–2 GB, 1–2 vCPU |
| Storage | 64–256 GB eMMC | 20–50 GB SSD |
| Cost | ~$0 (electricity ≈ $0.5/mo) | ~$5/mo |
| Public IP | ✗ needs a tunnel | ✓ |
| Uptime | Fragile (power, updates, battery) | ~99.9% |
| Privileged ports (<1024) | ✗ usually blocked | ✓ |
| If it dies | No SLA | Provider support |
| **Best for** | self-hosting, workers, cron, learning | production you depend on |

**Verdict:** excellent for self-hosting, learning and personal services.
Do **not** run something business-critical on it.

## The 5 hard truths

These are what every "turn your phone into a server" blog post skips.

1. **Cellular carriers block inbound ports.** Almost all mobile plans use
   CGNAT, so you have no public IPv4. Port 80/443 inbound will not work.
   Every solution is a tunnel (Cloudflare Tunnel, Tailscale, ngrok) or running
   the server on Wi-Fi behind a router you control.
2. **A phone plugged in 24/7 will destroy its battery.** Swollen batteries are
   the #1 killer of this project. You must limit charging to 60–80 %.
3. **Privileged ports and some system calls are blocked** on unrooted Android.
   That is why "just install Docker" fails, and why root is the fork in the road.
4. **Phones throttle hard.** They assume a pocket, not a drawer with sustained
   100 % CPU. Expect thermal throttling under heavy load.
5. **eMMC is not an SSD.** Flash wear is real. Fine for logs and small
   databases; don't treat it as a write-heavy disk.

## Which path are you on?

```
                        Do you have root (or can you root it)?
                                    │
              ┌─────────────────────┴─────────────────────┐
              │ NO                                        │ YES
              ▼                                           ▼
   ┌──────────────────────┐                  ┌────────────────────────────┐
   │ PATH A — No Root     │                  │ PATH B — Root ⭐           │
   │                      │                  │                            │
   │ Termux + proot-distro│                  │ Real Linux. Real Docker.   │
   │ udocker for OCI      │                  │ Real systemd.              │
   │ images (no daemon)   │                  │                            │
   │                      │                  │ B1: Android + Magisk +     │
   │ ✅ Safe, no brick     │                  │     Docker/udocker         │
   │ ✅ 15 min setup       │                  │ B2: postmarketOS (best)    │
   │ ❌ No real Docker     │                  │                            │
   │ ❌ No docker compose  │                  │ ✅ docker compose works    │
   │                      │                  │ ✅ systemctl works         │
   └──────────────────────┘                  │ ⚠️ Can brick the phone     │
              │                              └────────────────────────────┘
              └──────────────┬───────────────────────────┘
                             ▼
                  Make it reachable (tunnel)
                             ▼
                  Make it survive reboots
                             ▼
                  Harden it (you just exposed a phone to the internet)
```

- **PATH A — no root:** [`docs/en/path-a-nonroot.md`](docs/en/path-a-nonroot.md) — 📖 Riset
- **PATH B — root (recommended):**
  - [`docs/en/path-b1-magisk.md`](docs/en/path-b1-magisk.md) — 🧪 Perlu diuji
  - [`docs/en/path-b2-postmarketos.md`](docs/en/path-b2-postmarketos.md) — 🧪 Perlu diuji
- **Access from the internet:** [`docs/en/tunnel.md`](docs/en/tunnel.md) — 📖 Riset
- **Battery: don't kill it:** [`docs/en/battery.md`](docs/en/battery.md) — 📖 Riset
- **Survive reboots:** [`docs/en/autostart.md`](docs/en/autostart.md) — 🧪 Perlu diuji
- **Hardening:** [`docs/en/hardening.md`](docs/en/hardening.md) — 📖 Riset
- **Benchmarks (run it yourself):** [`docs/en/benchmark.md`](docs/en/benchmark.md) — ✅ Teruji (script)

## Which phone should you buy?

If you're buying one specifically, **support tier is everything**:

- 🥇 **OnePlus 6 / 6T** (`enchilada` / `fajita`) — the best-supported
  postmarketOS device you can buy used. Mainline-adjacent kernel, working GPU
  and Wi-Fi, ~$50–70.
- 🥈 **Google Pixel** (recent, unlocked bootloader) — excellent Android + Magisk
  path, well-documented rooting, long support.
- ⚠️ **Avoid for servers:** devices with no postmarketOS port and no root method
  (many MediaTek phones), and anything with a locked bootloader you can't
  unlock.

**Before buying, check the device page for these four rows** — they are what
actually breaks on a headless server:
1. **Wi-Fi** (the most common failure point)
2. **USB networking / OTG** (your console access, and wired fallback)
3. **Storage throughput & wear**
4. **Thermals when headless**

See [`docs/en/hardware.md`](docs/en/hardware.md) for the full checklist.

## Quick start

```bash
# Verify the method works at all — run this on any Linux box, no phone needed
./scripts/benchmark.sh

# Then follow a path:
#   PATH A (no root), 15 minutes:  docs/en/path-a-nonroot.md
#   PATH B (root, real VPS):       docs/en/path-b2-postmarketos.md
```

## What's in here

```
docs/
  en/ · id/          mirrored bilingual guides
scripts/             runnable, tested-where-possible automation
  benchmark.sh       ✅ measures real CPU/RAM/disk — compare before you commit
  healthcheck.sh     🧪 uptime, temp, battery, disk, docker — for cron
  expose-tunnel.sh   🧪 Cloudflare Tunnel setup helper
  battery-limit.sh   🧪 set charge limit 60-80 %
  validate-docs.sh   ✅ checks scripts, status markers, links, ID/EN parity
CONTRIBUTING.md      how to report a device result
```

Run `./scripts/validate-docs.sh` before opening a PR.

## Should you actually do this?

**Yes, if:** you want to self-host (Nextcloud, Jellyfin, Syncthing, Home
Assistant, n8n, Uptime Kuma), run cron jobs, learn Linux/sysadmin, or reduce
cloud costs for personal services.

**No, if:** you need 99.9 % uptime, you can't limit battery charging, you need
privileged ports and can't tunnel, or you can't risk bricking the device.

---

# 🇮🇩 Bahasa Indonesia

## Ini repo apa

Panduan praktis mengubah HP Android bekas jadi **server Linux headless** —
dengan **Docker asli**, bisa diakses dari internet, dan otomatis hidup lagi
setelah reboot tanpa kamu awasi.

## Kenapa repot-repot? Perbandingan jujur

HP bekas sering **lebih kuat dari VPS murah**:

| | HP bekas | VPS $5 |
|---|---|---|
| RAM / CPU | 4–12 GB, 8 core | 1–2 GB, 1–2 vCPU |
| Penyimpanan | 64–256 GB eMMC | 20–50 GB SSD |
| Biaya | ~Rp 0 (listrik ≈ Rp 15rb/bln) | ~Rp 80rb/bln |
| IP publik | ✗ perlu tunnel | ✓ |
| Uptime | Rentan (listrik, update, baterai) | ~99,9% |
| Port <1024 | ✗ biasanya diblokir | ✓ |
| Kalau rusak | Tidak ada jaminan | Ada support |
| **Cocok untuk** | self-hosting, worker, cron, belajar | produksi yang tidak boleh mati |

**Kesimpulan:** sangat bagus untuk self-hosting, belajar, dan service pribadi.
Jangan pakai untuk sesuatu yang bisnis-kritis.

## 5 kenyataan pahit

Ini yang hampir selalu dilewatkan artikel "ubah HP jadi server".

1. **Operator seluler memblokir port masuk.** Hampir semua paket pakai CGNAT,
   jadi kamu tidak punya IPv4 publik. Port 80/443 masuk tidak akan jalan.
   Solusinya tunnel (Cloudflare Tunnel, Tailscale, ngrok) atau pasang server di
   Wi-Fi rumah lewat router yang kamu kuasai.
2. **HP yang dicolok 24/7 akan merusak baterainya.** Baterai kembung adalah
   pembunuh nomor satu proyek ini. Batasi pengisian 60–80 %.
3. **Port <1024 dan sebagian system call diblokir** kalau tidak root. Itu sebabnya
   "tinggal install Docker" gagal, dan kenapa root jadi persimpangan utama.
4. **HP throttle keras.** Dia dirancang untuk kantong, bukan laci dengan CPU
   100 % terus-menerus. Siap-siap kena thermal throttling.
5. **eMMC bukan SSD.** Flash wear nyata. Aman untuk log dan database kecil;
   jangan dijadikan disk yang berat tulis.

## Kamu di jalur mana?

```
                        Punya root (atau bisa di-root)?
                                    │
              ┌─────────────────────┴─────────────────────┐
              │ TIDAK                                     │ YA
              ▼                                           ▼
   ┌──────────────────────┐                  ┌────────────────────────────┐
   │ JALUR A — Tanpa Root │                  │ JALUR B — Root ⭐          │
   │                      │                  │                            │
   │ Termux + proot-distro│                  │ Linux asli. Docker asli.   │
   │ udocker untuk image  │                  │ systemd asli.              │
   │ OCI (tanpa daemon)   │                  │                            │
   │                      │                  │ B1: Android + Magisk +     │
   │ ✅ Aman, tanpa brick  │                  │     Docker/udocker         │
   │ ✅ Setup 15 menit     │                  │ B2: postmarketOS (terbaik) │
   │ ❌ Docker tidak asli  │                  │                            │
   │ ❌ docker compose ✗   │                  │ ✅ docker compose jalan    │
   │                      │                  │ ✅ systemctl jalan         │
   └──────────────────────┘                  │ ⚠️ Bisa brick HP           │
              │                              └────────────────────────────┘
              └──────────────┬───────────────────────────┘
                             ▼
               Bikin bisa diakses (tunnel)
                             ▼
               Bikin hidup lagi setelah reboot
                             ▼
               Amankan (kamu baru saja menaruh HP di internet)
```

- **JALUR A — tanpa root:** [`docs/id/jalur-a-tanpa-root.md`](docs/id/jalur-a-tanpa-root.md) — 📖 Riset
- **JALUR B — root (disarankan):**
  - [`docs/id/jalur-b1-magisk.md`](docs/id/jalur-b1-magisk.md) — 🧪 Perlu diuji
  - [`docs/id/jalur-b2-postmarketos.md`](docs/id/jalur-b2-postmarketos.md) — 🧪 Perlu diuji
- **Akses dari internet:** [`docs/id/tunnel.md`](docs/id/tunnel.md) — 📖 Riset
- **Baterai jangan sampai rusak:** [`docs/id/baterai.md`](docs/id/baterai.md) — 📖 Riset
- **Hidup lagi setelah reboot:** [`docs/id/autostart.md`](docs/id/autostart.md) — 🧪 Perlu diuji
- **Mengamankan:** [`docs/id/hardening.md`](docs/id/hardening.md) — 📖 Riset
- **Uji performa (jalankan sendiri):** [`docs/id/benchmark.md`](docs/id/benchmark.md) — ✅ Teruji (skrip)

## Sebaiknya beli HP apa?

Kalau memang mau beli khusus untuk ini, **tier dukungan adalah segalanya**:

- 🥇 **OnePlus 6 / 6T** (`enchilada` / `fajita`) — device postmarketOS terbaik
  yang bisa kamu beli bekas. Kernel mendekati mainline, GPU dan Wi-Fi jalan,
  sekitar Rp 800rb–1,2jt.
- 🥈 **Google Pixel** (generasi terbaru, bootloader bisa dibuka) — jalur
  Android + Magisk paling mulus dan terdokumentasi.
- ⚠️ **Hindari untuk server:** HP tanpa port postmarketOS dan tanpa metode root
  (banyak HP MediaTek), atau bootloader terkunci yang tidak bisa dibuka.

**Sebelum beli, cek 4 baris ini di halaman device** — inilah yang sebenarnya
rusak di server headless:
1. **Wi-Fi** (titik gagal paling umum)
2. **USB networking / OTG** (akses konsol, dan cadangan kabel)
3. **Throughput & wear penyimpanan**
4. **Suhu saat headless**

Detail lengkap: [`docs/id/hardware.md`](docs/id/hardware.md).

## Mulai cepat

```bash
# Buktikan metodenya jalan dulu — jalan di Linux apa pun, tanpa HP
./scripts/benchmark.sh

# Baru ikuti salah satu jalur:
#   JALUR A (tanpa root), 15 menit:  docs/id/jalur-a-tanpa-root.md
#   JALUR B (root, VPS sungguhan):   docs/id/jalur-b2-postmarketos.md
```

## Isi repo

```
docs/
  en/ · id/          panduan dua bahasa, kembar
scripts/             otomasi yang bisa dijalankan
  benchmark.sh       ✅ ukur CPU/RAM/disk sungguhan — bandingkan sebelum memutuskan
  healthcheck.sh     🧪 uptime, suhu, baterai, disk, docker — untuk cron
  expose-tunnel.sh   🧪 pembantu setup Cloudflare Tunnel
  battery-limit.sh   🧪 set batas cas 60-80 %
  validate-docs.sh   ✅ periksa skrip, penanda status, link, keseimbangan ID/EN
CONTRIBUTING.md      cara melaporkan hasil perangkat
```

Jalankan `./scripts/validate-docs.sh` sebelum membuka PR.

## Jadi, sebaiknya dilakukan?

**Ya, kalau:** kamu mau self-host (Nextcloud, Jellyfin, Syncthing, Home
Assistant, n8n, Uptime Kuma), menjalankan cron, belajar Linux/sysadmin, atau
menekan biaya cloud untuk service pribadi.

**Tidak, kalau:** kamu butuh uptime 99,9 %, tidak bisa membatasi pengisian
baterai, butuh port <1024 tapi tidak mau tunnel, atau tidak siap HP-nya rusak.

---

## 🗺️ Peta Jalan / Roadmap

- [x] Struktur repo dua bahasa
- [x] Skrip benchmark ✅ teruji
- [ ] Laporan uji perangkat nyata (butuh kontributor)
- [ ] Skrip odroid/lxc (Proxmox di arm64)
- [ ] Terjemahan lengkap semua halaman
- [ ] Benchmark perbandingan: Nokia N900 → Snapdragon flagship

## Kontribusi / Contributing

Laporan paling berharga: **"HP X, Android Y, jalur Z, berhasil/gagal pada
langkah N"**. Lihat [CONTRIBUTING.md](CONTRIBUTING.md).

## Lisensi / License

MIT — lihat [LICENSE](LICENSE). Pakai dengan risiko sendiri; flashing bisa
membuat HP tidak bisa dipakai.
