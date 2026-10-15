# Path A — no root (Termux + proot)

> 📖 **RESEARCH** — The Termux/proot-distro flow is based on the official Termux wiki and
> proot-distro documentation. Not yet run by the author.

**The safest path** (doesn't touch the bootloader, can't brick) and the
fastest (15 minutes). But there's a hard limit: **real Docker still won't work.**

| | |
|---|---|
| ⏱️ Time | ~15 minutes |
| ⚠️ Risk | low — no flashing |
| ✅ You get | Full Linux userspace, `apt`/`apk`, Python, Node, lightweight services |
| ❌ You don't get | Real Docker, `docker compose`, ports <1024, some syscalls |

If you need real Docker, go straight to [Path B](path-b2-postmarketos.md).

---

## Why real Docker isn't possible without root

Docker needs: (1) a **daemon running as root**, (2) **namespaces** and
**cgroups** for isolation, (3) some **system calls** that the Android
kernel blocks for unprivileged processes. Without root you can't meet that.

What you **can** do without root: `udocker` and `proot-distro` — both run
Linux userspace through syscall emulation (`ptrace`), not kernel isolation.
The result works, but at a cost of ~10–30 % performance and without
`docker compose`.

---

## Step 1 — Termux from F-Droid

**Don't use the Play Store** — the version there is outdated and can't
`pkg upgrade` properly.

1. Install [F-Droid](https://f-droid.org/)
2. From F-Droid, install **Termux**
3. Open Termux once, run `pkg upgrade`

```bash
pkg update && pkg upgrade -y
pkg install -y proot-distro openssh termux-api
```

---

## Step 2 — Protect Termux from Android's process killer

**This is the most important step on this path.** If you skip it, Termux will die
on its own a few hours later.

**Turn off battery optimization:**
Settings → Apps → Termux → Battery → **Unrestricted / Not optimized**

**Take a wake lock so the CPU doesn't sleep:**

```bash
termux-wake-lock
```

**Lock Termux in the recent apps list** (the padlock icon / "Lock" in the recent menu).

**Check it's correct:**

```bash
# Check battery optimization (requires termux-api)
termux-battery-status | head -20
```

Without this step, you'll experience this: the service runs, then 3 hours
later it dies on its own with no error at all in the logs. That's Android killing it.

---

## Step 3 — Full Linux with proot-distro

```bash
# List the available distros
proot-distro list

# Install Debian
proot-distro install debian

# Log in
proot-distro login debian
```

Now you're inside Debian. Install anything:

```bash
apt update && apt upgrade -y
apt install -y python3 python3-pip nodejs npm git curl nano htop
```

**Exit** proot: `exit`

---

## Step 4 — Run containers with udocker

`udocker` runs OCI images **without a daemon and without root**. It's the closest
Docker substitute.

```bash
# In Termux (not inside proot)
pkg install -y python3
pip install udocker

udocker --allow-root install      # install the helper components
udocker version
```

Test:

```bash
udocker pull alpine
udocker create --name=uji alpine
udocker run uji echo "hello from container"
udocker run uji cat /etc/os-release
```

Running a service:

```bash
udocker run \
  --name=web \
  -p 8080:80 \
  -v /data/data/com.termux/files/home/app:/app \
  nginx
```

> `-p` in udocker isn't kernel port forwarding — it uses a userspace relay.
> It works, but it's slower than real Docker.

**udocker limitations you have to accept:**

| Feature | Status |
|---|---|
| Run OCI images | ✅ |
| Volumes | ✅ |
| Port mapping | ✅ (via relay, slow) |
| `docker compose` | ❌ **not available** |
| Networking between containers | ⚠️ limited |
| Perf | ~10–30 % slower (proot) |

---

## Step 5 — SSH from outside

```bash
# In Termux
sshd
whoami        # remember this username
ifconfig 2>/dev/null | grep inet || ip addr show | grep inet
# note the phone's local IP, e.g. 192.168.1.50
```

From another computer on the same Wi-Fi:

```bash
ssh -p 8022 user@192.168.1.50
```

Termux's default port is **8022** (not 22), because ports <1024 need root.

> Limitation: this only works on the local network. For access from the internet, you
> need a tunnel → [tunnel.md](tunnel.md)

---

## Step 6 — Autostart

Without root, you need **Termux:Boot** from F-Droid → [autostart.md](autostart.md)

---

## Step 7 — Battery limit

Without root you **can't** set a charge limit through the kernel. Options:

1. **Alternating charging** using a smart plug + schedule (the most practical without root)
2. **A built-in phone feature** — some brands have "protect battery" in Settings → Battery
3. Root → use ACC → [battery.md](battery.md)

Don't ignore this. See [battery.md](battery.md) for why.

---

## What's realistic to run on Path A

✅ **Suitable:**
- Simple bots (Telegram/Discord) — Python/Node
- Cron and scheduled scripts
- Small APIs (Flask/Express/FastAPI)
- File sync (Syncthing, rclone)
- Lightweight reverse proxy
- Webhook endpoints
- Monitoring (Uptime Kuma via Node directly)

❌ **Not suitable:**
- Anything that needs `docker compose`
- Jellyfin/Plex transcoding (needs hardware access + performance)
- Heavy databases (proot slows down I/O)
- Home Assistant with many add-ons (needs Docker)
- Anything that needs ports <1024 without a proxy

---

## Common pitfalls

| Problem | Cause & solution |
|---|---|
| Termux dies on its own | Battery optimization — see Step 2 |
| `sshd` doesn't run after reboot | Termux:Boot not installed |
| `pip install` fails | Some packages need a compiler: `pkg install build-essential` |
| proot is very slow | Normal — proot emulates syscalls. Don't use it for heavy I/O |
| udocker "cannot execute" | Try an older/smaller image, or use proot-distro directly |
| Storage full | `proot-distro` + images eat many GB. Check `df -h .` |

---

## Move up to Path B if...

- You need `docker compose` to actually work
- You need ports 80/443 directly
- Termux still dies on its own even with battery saving turned off
- You need serious uptime

→ [path-b2-postmarketos.md](path-b2-postmarketos.md)