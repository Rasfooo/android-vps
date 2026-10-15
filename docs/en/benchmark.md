# Benchmark: is your phone good enough?

> ✅ **TESTED** — `scripts/benchmark.sh` has been run by the author on Debian 13
> (the sample output below is real output). The phone comparison section is an
> estimate and will be updated with contributor reports.

The real question isn't "is my phone good enough?" but
**"good enough for what?"** This script gives you numbers so the decision is
data-driven.

---

## Run it

```bash
chmod +x scripts/benchmark.sh
./scripts/benchmark.sh

# Save the result for comparison / reporting
./scripts/benchmark.sh > hasil-$(uname -m).txt
```

It needs no dependencies at all — just `bash` and `/proc` (any Linux,
including inside Termux/proot).

---

## What it measures, and why that matters

| Section | Why it's relevant for a server |
|---|---|
| **CPU (prime numbers)** | Single-thread performance — the thing that decides it for API, bots, web |
| **Disk write (with fsync)** | The most common disappointment on old eMMC phones |
| **RAM & swap** | A low-RAM phone without swap will OOM when containers run |
| **Temperature** | In a drawer with no ventilation, throttling kicks in fast |
| **Disk type** | eMMC = real wear, don't use it for write-heavy disks |
| **Capability** | Determines whether you can `root`/`docker` or not |

---

## Sample output (author's test host)

This is **real** output, run on a development server (not a phone):

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

**Use this as a reference point.** A good used phone is usually:

| Metric | Good used phone | $5 VPS | Server above |
|---|---|---|---|
| Primes 30k | 0.5–2 seconds | 1–3 seconds | 0.1 seconds |
| Disk write | 30–150 MB/s | 100–400 MB/s | 800+ MB/s |
| RAM | 4–12 GB | 1–2 GB | — |

If your phone is **faster than a $5 VPS**, using the phone makes economic sense.
If it's slower, reconsider.

---

## Interpreting the results

The script gives an automatic rating:

| Result | Meaning |
|---|---|
| **sangat cepat** (< 1 s) | Can run anything |
| **cepat** (1–3 s) | Equivalent to a mid-range VPS, safe for many services |
| **sedang** (3–8 s) | Light services, limit the number of containers |
| **lambat** (8–20 s) | Cron, bots, light tasks only |
| **sangat lambat** (> 20 s) | Consider another phone |

**Pay attention to the disk write number.** If it's below 20 MB/s, the database
will feel very slow and flash wear becomes a real problem.

---

## Other useful tests

### 1. Temperature under full load (throttling)

This is what a synthetic score won't show you: does your phone throttle?

```bash
# Record the starting temperature
for z in /sys/class/thermal/thermal_zone*/temp; do
  awk -v f="$z" 'BEGIN{}{printf "%s: %.1f°C\n", f, $1/1000}' "$z" 2>/dev/null
done

# Apply load for 10 minutes with 4 processes
for i in 1 2 3 4; do
  (timeout 600 sh -c 'while :; do :; done') &
done

# Every 30 seconds, record temperature and frequency
while true; do
  date '+%H:%M:%S'
  cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -3 | awk '{printf "%.1f°C ", $1/1000}'
  echo
  sleep 30
done
```

If the temperature rises past 70–80 °C and the frequency drops, your phone
**throttles**. That means peak performance is only brief — which matters for
sustained load.

### 2. Sustained write test (flash wear)

```bash
# Write 2 GB and see if the speed drops drastically (cache exhausted)
dd if=/dev/zero of=/tmp/big.bin bs=1M count=2048 conv=fsync
rm /tmp/big.bin
```

A speed that falls from 100 MB/s to 5 MB/s shows the cache is exhausted and that
is the true eMMC speed.

### 3. Network test

```bash
# Latency & throughput to the internet
ping -c 10 1.1.1.1
curl -o /dev/null -s -w 'Download: %{speed_download} B/s\n' \
  https://speed.cloudflare.com/__down?bytes=100000000
```

---

## If the results are bad

1. **Hot?** Give it ventilation. A 15 °C difference in temperature can change
   sustained performance.
2. **Slow disk?** Move data to a microSD, or reduce log writing.
3. **Out of RAM?** Turn off Android (if you're on path B1), or use postmarketOS with
   the `none` UI (path B2).
4. **Slow CPU?** Limit it to light tasks: cron, bots, syncing. Don't
   run a large database.

---

## Report your results

We want to build a table comparing real devices. Send:

```
Perangkat : OnePlus 6 (enchilada)
RAM       : 8 GB
Prima 30k : 0.8 detik
Tulis disk: 120 MB/s
Suhu idle : 32°C
Suhu beban: 68°C (throttle: ya/tidak)
OS        : postmarketOS 25.12
```

`./scripts/benchmark.sh` already prints almost all of this.