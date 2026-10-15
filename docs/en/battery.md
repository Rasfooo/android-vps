# Battery: don't let the phone get damaged

> 📖 **RESEARCH** — The values and kernel nodes are taken from the ACC,
> SmartBypass documentation and community discussions. Not yet tested by the
> author on a real device.

**This is the most important part of the whole project.** If you forget
everything else, remember this one: **a phone that is plugged in forever at
100 % will make its battery swell.**

---

## Why a swollen battery is serious

A lithium battery held at full voltage continuously undergoes lithium plating
and builds up gas inside the cell. The result:

- The battery swells → presses on the screen → **the screen can crack from the inside**
- Capacity drops sharply (you can lose 40 % in a year)
- **Fire** risk — damaged lithium can go into thermal runaway

This is not theory. It is the number one cause of death for the "phone as a
server" project. Many people get the setup working, then the phone dies 3
months later.

**Safe range for permanent use: 60–80 %.** Just by staying under 80 %, battery
life can be many times longer than always being at 100 %.

---

## How to limit it — from the easiest

### 1. App, requires root (most practical)

**ACC (Advanced Charging Controller)** — the most mature, supports hundreds of
devices, works with Magisk/KernelSU/APatch.

```bash
# After root + Magisk are installed
# Install through Magisk, then:
acc -s pc=80 mcc=500        # pause charge at 80%, limit current to 500 mA
acc -s pc=75                # or a 60-75% range for maximum lifespan
acc -r                      # read the full documentation
```

- Source: `github.com/VR-25/acc`
- Version with a GUI: **AccA** (AccA-ACC app), easier for beginners
- Advantage: it determines the kernel node itself via `acc -t`, so it is more
  robust against each brand's quirks
- `battery idle mode` (a.k.a. bypass charging): the device runs directly from
  the charger, the battery as if unplugged — this is **ideal** if your device
  supports it. There is an emulation mode for devices that don't.

**SmartBypass** — an alternative with many hardware detection engines:

```
BYPASS_TARGET=80        # hold at 80%
BYPASS_BAND=2           # charge again if it drops 2%
BYPASS_TEMP_TRIGGER=38  # enable bypass if it gets hot, 38°C
```
- Source: `github.com/mrk9091/SmartBypass`
- Has an `EMULATED` fallback that works on any device

### 2. Kernel node directly (this repo's script)

```bash
./scripts/battery-limit.sh detect      # find an available node
./scripts/battery-limit.sh set 80      # set the limit + run the daemon
./scripts/battery-limit.sh status      # check
```

Use this if you don't want to install an app. Its limitation: some devices
**turn charging back on by themselves** a few seconds after the daemon turns it
off — if that's the case, ACC is more reliable because it handles that case.

### 3. No root, no app

- **Remove the battery**, supply power directly to the board (requires
  soldering — only for those who understand electronics)
- **Alternating charge:** charge ~2 hours, unplug, repeat. Tedious but free and
  effective. Use a smart plug + schedule to automate it.
- **Check your phone's firmware:** some brands have a built-in "battery care" /
  "protect battery" that limits to 80–85 %. Look in Settings → Battery.

---

## How to verify the limit actually works

Don't just trust it — measure:

```bash
# 1. Check the current level
cat /sys/class/power_supply/battery/capacity

# 2. Check the charging status
cat /sys/class/power_supply/battery/status
# It should be "Not charging" or "Discharging" while above the limit

# 3. Check whether charging turns itself back on (a common problem)
while true; do date; cat /sys/class/power_supply/battery/status; sleep 30; done
```

**If the status flips back and forth between Charging ↔ Not charging every few
seconds:** your limit is unstable. Move to ACC with `battery idle mode`.

The health script in this repo checks this automatically:

```bash
./scripts/healthcheck.sh
# Will warn: "baterai 100% & terus Charging — INI YANG BIKIN KEMBUNG"
```

---

## Monitor battery health

```bash
# Current capacity vs design capacity
cat /sys/class/power_supply/battery/charge_full          # mAh now
cat /sys/class/power_supply/battery/charge_full_design   # mAh when new
cat /sys/class/power_supply/battery/cycle_count          # number of cycles
```

Health = `charge_full / charge_full_design × 100 %`. Below 60 % means it is
already weak — replace the battery before turning it into a server.

`./scripts/battery-limit.sh status` calculates this for you.

---

## Temperature matters too

A hot battery ages much faster. Aim for **below 35 °C**.

- Don't put the phone in a closed drawer with no airflow
- Don't put it on a surface that traps heat (a mattress, a carpet)
- Stand the phone up (don't lay it down) so heat can escape
- If you can, add a small heatsink or a USB fan — the difference is big

`./scripts/healthcheck.sh` warns above 40 °C and gives a critical status above
45 °C.

---

## Summary of the rules

1. **Limit to 60–80 %.** Full stop. Don't skip this.
2. **Use ACC** if your device is supported — most reliable.
3. **Verify** with `healthcheck.sh`, don't assume.
4. **Keep the temperature below 35 °C** — provide ventilation.
5. **Check battery health** every few months; replace it if < 60 %.
