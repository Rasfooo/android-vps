# Path B2 — postmarketOS: real Linux on a phone ⭐

> 🧪 **NEEDS TESTING** — this page is written from official postmarketOS
> documentation and community sources, **not yet run by the author** because
> there is no test phone yet.
> Proceed with awareness of the risk. If you run it, report the result!

**This is the path closest to a "real VPS."** You replace Android
with actual Linux: `systemd`, `docker`, `docker compose`, `systemctl` — everything
you'd expect from a VPS.

**Time:** 2–4 hours for a beginner · **Risk:** ⚠️ high (flashing can brick)

---

## Why postmarketOS instead of Android + Magisk?

| | Android + Magisk (B1) | postmarketOS (B2) |
|---|---|---|
| Real Linux | ✗ (Android, not ordinary Linux) | ✓ |
| `systemd` / `systemctl` | ✗ | ✓ |
| Official Docker | ~ (needs modules, often broken) | ✓ if the kernel supports cgroup |

| OS updates | via ROM | ordinary `apk upgrade` |
| Screen & UI | Android | headless XFCE/terminal |
| Brick risk | moderate | high during the first flash |
| Suitable for a server | adequate | **the best** |

If your goal is a headless server, postmarketOS fits better: there's no Android
killing background processes, no "systemless" restrictions, no UI forcing the
battery.

---

## Step 0 — Pick the right device (do NOT skip this)

This decides success or failure. **Porting an unsupported phone is a
months-long project, not a weekend job.**

Check [wiki.postmarketos.org/wiki/Devices](https://wiki.postmarketos.org/wiki/Devices):

1. Look up your phone. If it's **not there**, stop here — pick another phone or
   use Path A/B1.
2. Look at its **tier**:
   - `main` / `community` → **suitable** as a server
   - `testing` → for tinkering, not for something you rely on
   - `unmaintained` / `main-with-caveats` → treat it as testing or worse
3. **Check these 4 feature rows** — this is what actually matters for a headless
   server, and the tier alone doesn't tell you:

| What to check | Why it matters |
|---|---|
| **Wi-Fi** | The most common failure point. Many Qualcomm devices need specific `ath10k`/`ath11k` firmware. |
| **USB networking / OTG** | Console access when the screen is off, and a wired connection as a fallback. |
| **Storage** | Phone eMMC is not server-class flash. Check throughput & wear behavior. |
| **Headless thermals** | In a drawer with no airflow, throttling arrives far sooner than in a pocket. |

**Community-recommended phones 2026:**

- 🥇 **OnePlus 6 / 6T** (`enchilada` / `fajita`) — the best supported, kernel
  close to mainline, GPU (Freedreno) & Wi-Fi work, used price ~$50–80.
- 🥈 **Google Pixel** (unlockable bootloader) — long support,
  the most complete rooting documentation if you go to Path B1.
- ⚠️ **Avoid** MediaTek without a port, and anything with a permanently locked bootloader.

---

## Step 1 — Prepare on the computer (not on the phone)

`pmbootstrap` runs on Linux x86_64 and what it needs:

```bash
# Debian/Ubuntu
sudo apt install python3 python3-pip git openssl

# Fedora
sudo dnf install python3 python3-pip git openssl

# Arch
sudo pacman -S python python-pip git openssl
```

Install pmbootstrap:

```bash
git clone --depth=1 https://gitlab.com/postmarketOS/pmbootstrap.git
cd pmbootstrap
mkdir -p ~/.local/bin
ln -s "$PWD/pmbootstrap.py" ~/.local/bin/pmbootstrap
export PATH="$HOME/.local/bin:$PATH"
pmbootstrap -V        # must be >= 3.2.0 for systemd
```

> ⚠️ If `pmbootstrap -V` shows a version < 3.2.0, use the git installation
> above (not the distro package) — old versions don't support systemd.

---

## Step 2 — Initialize

```bash
pmbootstrap init
```

What you'll be asked (answers for a **headless server**):

| Question | Answer | Reason |
|---|---|---|
| Vendor / device | match your phone | e.g. `oneplus` / `enchilada` |
| UI | **`none`** | You don't need a UI on a server; saves RAM & storage |
| systemd | **`always`** or **yes** | This is what gives you `systemctl` — **required** for the VPS feel |
| Hostname | `hp-vps` | up to you |
| Username | `user` | safe default |
| Kernel | pick the default | |
| Extra packages | leave empty for now | install later via `apk` |

**Important:** UI `none` + systemd = a pure Linux server. If you choose a graphical
UI, you're wasting ~500 MB of RAM on something you'll never look at.

---

## Step 3 — Build the image

```bash
pmbootstrap install
```

If you want Docker available right away without a manual install:

```bash
# Add docker to the packages installed at build time
pmbootstrap install --add docker
# If the 'docker' package isn't in the Alpine repo, this will fail —
# in that case just continue, install it via apk after boot.
```

> ⚠️ **Does Docker actually work?** postmarketOS can run Docker
> **only if your device's kernel enables cgroup** and the relevant kernel
> options. For devices with a vendor kernel (not mainline), this is often
> unavailable. Check after boot:
> ```bash
> cat /proc/cgroups
> docker info      # if it errors about cgroup → Docker won't work
> ```
> If it fails, postmarketOS is **not** the solution for you; go back to Path B1
> with udocker.

---

## Step 4 — Flash it onto the phone (⚠️ the riskiest part)

**Before you start:**

- [ ] Phone battery **> 50%**
- [ ] You've **backed up all data** — flashing wipes everything
- [ ] You know how to enter **fastboot mode** for your phone (usually
      `Volume Down` + `Power`)
- [ ] You've **unlocked the bootloader** (the process differs by brand; Xiaomi requires
      a 7-day wait, Google & OnePlus are faster). **Unlocking wipes all data.**
- [ ] You've recorded/backed up the **original partitions** if the tool exists
- [ ] You're aware: **it can brick permanently.** If this is your only phone, don't.

```bash
# Put the phone into fastboot, then:
fastboot devices        # your phone's serial must appear
pmbootstrap flasher flash_rootfs
pmbootstrap flasher flash_kernel
```

> ⚠️ **Verify the partition names for your device on your device's wiki page
> before running the flash commands.** The generic commands above can target
> the wrong partition on certain devices. Never guess.

After the first boot, log in over the USB terminal (or SSH if Wi-Fi is
already connected).

---

## Step 5 — Turn it into a server

All the commands below are run **on the phone**, after booting into postmarketOS.

### 5a. Basic update

```bash
sudo apk update && sudo apk upgrade -a
sudo apk add openssh docker docker-cli-compose curl nano htop
```

### 5b. Autostart SSH (with the `none` UI, nothing starts it)

```bash
sudo rc-update add sshd default      # if the init is OpenRC
sudo systemctl enable --now sshd     # if the init is systemd
```

### 5c. Docker

```bash
sudo rc-update add docker default    # OpenRC
sudo systemctl enable --now docker   # systemd
docker run --rm hello-world          # must succeed
```

### 5d. Quick test — this is the "it's really a VPS" moment

```bash
docker compose version
docker run -d --name web -p 8080:80 nginx
curl -I localhost:8080      # must be HTTP 200
```

If this works, you now have **real Docker Compose on a phone** — that's what
you can't get on Path A.

---

## Step 6 — Limit battery charging

Don't skip this. Details: [battery.md](battery.md)

On postmarketOS, a charge limit is sometimes available through the same sysfs as on Android:

```bash
./scripts/battery-limit.sh detect
./scripts/battery-limit.sh set 80
```

If there's no writable node (common on mainline kernels), the alternative is
**removing the battery** and supplying power directly, or using a device that has
`battery idle mode` support in the kernel.

---

## Step 7 — Access from the internet

Continue to [tunnel.md](tunnel.md) — Cloudflare Tunnel works well here
because `cloudflared` is available for arm64/aarch64.

---

## Step 8 — Harden it

Mandatory. You just put a device on the internet:
[hardening.md](hardening.md)

---

## If it fails

| Symptom | Likely cause |
|---|---|
| `fastboot devices` empty | USB driver / data cable (not a charge cable) / wrong mode |
| Bootloop after flashing | Wrong partition targeted — check the device page |
| No Wi-Fi | Firmware missing from the image; vendor kernel needs blobs |
| `docker info` cgroup error | Kernel doesn't support it — can't be fixed without a new kernel |
| Battery swollen within 2 months | Charge limit not set up |
| Randomly shuts down | OOM (low RAM) or thermal shutdown |

---

## Report your result

This is what we need most — this repo is built on the honest assumption that
many parts haven't been tested. Report format:

```
Device    : OnePlus 6 (enchilada)
OS        : postmarketOS 25.12, systemd, UI none
Path      : B2
Result    : success / failed at step N
Docker    : works / doesn't (cgroup: yes/no)
Notes     : ...
```

Open an [issue](../../../issues) with the format above, or a PR to
[CONTRIBUTING.md](../../CONTRIBUTING.md).