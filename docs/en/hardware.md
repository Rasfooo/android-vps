# Choosing a phone to turn into a server

> 📖 **RESEARCH** — Device recommendations based on the postmarketOS wiki and
> community sources. Not yet verified by the author with real hardware.

**Support tier is everything.** A flagship phone with a bad port will lose to a
mid-range phone whose port is `community`. This is the most expensive mistake a
beginner makes.

---

## The 4 lines that actually decide it

The wiki tier is good as an initial filter, but it does **not** tell you what
breaks on a headless server. Check these four things on your device's page:

| # | What to check | Why this is decisive |
|---|---|---|
| 1 | **Wi-Fi** | The number-one failure point. If Wi-Fi doesn't work, your server has no network. Many Qualcomm devices need `ath10k`/`ath11k` firmware that isn't available. |
| 2 | **USB networking / OTG** | This is your console access when the screen is off, and your way out if Wi-Fi breaks. Without it, debugging becomes very hard. |
| 3 | **Storage (throughput & wear)** | Old phone eMMC can do 20–40 MB/s. That's fine for logs, not enough for a database. |
| 4 | **Thermals when headless** | In a drawer with no airflow, throttling kicks in much sooner. A hot flagship can be worse than a cool mid-range phone. |

**If any of these four is bad, buy another phone** — unless you genuinely
want to contribute to fixing it.

---

## Recommendations

### 🥇 OnePlus 6 / 6T — `enchilada` / `fajita`

**The best choice you can buy used.** It's not about specs, but about
support: the kernel is close to mainline, meaning bugs get fixed quickly and
modern Linux features are available.

- SoC: Snapdragon 845 (8 cores, fast)
- RAM: 6/8/10 GB
- Storage: 64–256 GB UFS
- Kernel: mainline-adjacent
- Used price: ~Rp 800k–1.5M
- Bootloader: easy to unlock
- GPU support: ✓ (Freedreno) — meaning Wayland can run, though you don't need it

**Why it's recommended:** it appears most often in postmarketOS documentation,
so if you get stuck, someone else has already hit the same thing.

### 🥈 Google Pixel (bootloader can be unlocked)

Good for **Path B1** (Android + Magisk), and has postmarketOS ports for
certain generations.

- Smoothest and most documented rooting & unlock
- Long update support (Pixel 6+ up to 5 years)
- ⚠️ First check whether the generation you're eyeing has a postmarketOS port

### 🥉 Other alternatives worth seeking out

- **Poco F1** (`beryllium`) — Snapdragon 845, lots of RAM, popular in the community
- **Certain Samsung Galaxy A-series** — ⚠️ permanent Knox trip on unlock,
  and Exynos is often harder
- **Fairphone** — ethical, repairable, but expensive and ordinary performance

---

## What to avoid

| ❌ Avoid | Reason |
|---|---|
| **MediaTek without a port** | Many have no public kernel documentation. The chance of success is very small. |
| **Huawei/Honor** | The bootloader is usually permanently locked, with no official method |
| **Samsung flagship** | Permanent Knox trip — loss of warranty & features, irreversible |
| **"Unmaintained" devices** | Nobody is fixing bugs. You're on your own. |
| **Phones with a non-replaceable battery** | The battery is the component that fails first |
| **RAM < 2 GB** | It won't be comfortable for modern containers |
| **Locked bootloader with no unlock method** | You can't proceed to any serious path |

---

## How to mount the target: remove the screen?

Many people wonder about this. Short answer:

✅ **Benefits:**
- Saves power (the screen is the biggest consumer)
- Less heat → less throttling
- Fewer points of failure

⚠️ **Risks:**
- Some devices **won't boot without the screen attached** (they wait for a
  screen signal). Test first before permanently disassembling.
- You lose visual console access — make sure SSH/USB networking already works
  **before** removing the screen.
- It requires careful disassembly; the panel and digitizer crack easily.

**Recommendation:** run it with the screen attached for at least 1 week first,
make sure autostart and remote access are stable, then consider removing it.

---

## Pre-purchase checklist

Do this **before** paying:

- [ ] Find the phone on [wiki.postmarketos.org/wiki/Devices](https://wiki.postmarketos.org/wiki/Devices)
- [ ] Its tier is at least `testing`, ideally `community`/`main`
- [ ] Read the **Wi-Fi** line on the device page — if there are notes about problems, be wary
- [ ] Check that **USB networking** is present
- [ ] Search "[nama HP] XDA unlock bootloader" — is there a method for your Android version?
- [ ] Check **how to replace the battery** — difficult/expensive? How much does a replacement battery cost?
- [ ] Search GitHub: "`[nama HP] postmarketOS`" — has anyone
      already succeeded and shared their notes?
- [ ] Make sure the **data cable** works (not just a charging cable)
- [ ] Check that the RAM & storage specs match your plan

**Rule of thumb:** if you can't find at least one person who has already turned
that phone into a Linux server, assume you'll be the first — and that's a
multi-month project, not a weekend job.

---

## Contributing

If you've succeeded, add your row to the table below with a PR:

| Device | SoC | RAM | OS | Real Docker | Load temp | Notes |
|---|---|---|---|---|---|---|
| _(empty — awaiting contributions)_ | | | | | | |

Report format:

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