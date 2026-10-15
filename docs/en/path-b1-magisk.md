# Path B1 — Android + Magisk (+ Docker/udocker)

> 🧪 **NEEDS TESTING** — The rooting and Docker-on-Android flow hasn't been run
> by the author. Rooting differs by brand; verify the steps for **your device**
> with the XDA community before you start.

**The middle road:** keep using Android, but with root privileges. You get
more freedom without having to replace the OS.

| | |
|---|---|
| ⏱️ Time | 1–2 hours (including bootloader unlock) |
| ⚠️ Risk | moderate–high — **unlocking the bootloader wipes all data** |
| ✅ You get | Root, Magisk modules, reliable autostart, battery limit |
| ⚠️ Real Docker | **sometimes** works — depends on your phone's kernel |

---

## When to pick B1 vs B2

| | B1 (Android + Magisk) | B2 (postmarketOS) |
|---|---|---|
| Still usable as a phone | ✓ | ✗ |
| Real Docker | ⚠️ often fails (cgroup) | ✅ if the kernel supports it |
| systemd / systemctl | ✗ | ✓ |
| Risk | moderate | high |
| Android kills processes | ✓ (still can, but less often) | ✗ no Android at all |

**Pick B1 if:** you want the phone to still be usable normally, or your phone has no
postmarketOS port.

---

## Step 1 — Check eligibility

**Must-haves:**

- [ ] Bootloader **can be unlocked** (check your device's forum)
- [ ] There's a **root method** for your Android version (Magisk supports almost all)
- [ ] You're **ready to lose all data** during the unlock
- [ ] **Backup** — Google Takeout, photos, chats, everything

**Before continuing, answer this:** if your phone ends up unable to boot, what do
you lose? If the answer is "a lot of important things," stop and use
Path A.

---

## Step 2 — Unlock the bootloader

The process differs by brand:

| Brand | How | Notes |
|---|---|---|
| **Google Pixel** | `fastboot flashing unlock` | the easiest |
| **OnePlus** | `fastboot oem unlock` | easy |
| **Xiaomi** | Mi Unlock Tool | ⚠️ **wait 7–30 days** |
| **Samsung** | ⚠️ permanent Knox trip | **lose the warranty & some features permanently** |
| **Huawei** | usually ✗ | no official way |

```bash
# Install platform-tools on the computer
adb devices                   # your phone must appear
adb reboot bootloader
fastboot devices
fastboot flashing unlock      # or your brand's specific command
```

> ⚠️ **Verify the command for your device.** The wrong command can brick it.
> Don't guess.

---

## Step 3 — Install Magisk

1. Download **Magisk** from [github.com/topjohnwu/Magisk/releases](https://github.com/topjohnwu/Magisk/releases)
2. Get **boot.img** from your device's firmware (download the factory image)
3. On the phone: Magisk → Install → **Select and Patch a File** → pick `boot.img`
4. Copy the resulting `magisk_patched-*.img` to the computer
5. Flash:

```bash
fastboot flash boot magisk_patched-*.img
fastboot reboot
```

6. Open the Magisk app — it must show **Installed**

An alternative for devices with TWRP recovery: flash the Magisk ZIP through TWRP.

**Verify root:**

```bash
adb shell
su
id        # must show uid=0(root)
```

---

## Step 4 — Docker on Android: test first, don't get your hopes up

**This is the part that disappoints most often.** Docker needs cgroup and namespaces
that are **often disabled** in phone kernels.

### Test whether Docker can possibly work

```bash
su
# 1. Check cgroup availability
cat /proc/cgroups
mount | grep cgroup

# 2. Check namespaces
ls /proc/self/ns/

# 3. Check the cgroup version (v2 is expected for modern Docker)
cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null || echo "no cgroup v2"
```

**If `/proc/cgroups` is empty or cgroup isn't mounted → real Docker will most
likely fail.** Don't waste time; go on to udocker in Step 5.

### If cgroup is present

Some Magisk modules provide Docker for Android (search "docker" in the
Magisk module repo). Results **vary enormously per device**.

```bash
docker info        # if this errors about cgroup / iptables, Docker won't work
```

The most common problems:

| Error | Cause |
|---|---|
| `cgroup not mounted` | Kernel doesn't provide it |
| `iptables: not permitted` | Android kernel blocks it |
| Container starts but dies immediately | SELinux denies it |
| Runs but no networking | Incomplete net namespace |

> **Honest conclusion:** real Docker on Android is **not something you can rely on**.
> If you genuinely need Docker Compose, postmarketOS (Path B2) is far
> more likely to succeed. If Docker happens to work on your phone, great — but
> don't plan your project on that assumption.

---

## Step 5 — Fallback: udocker or chroot

If Docker fails (the common case):

### Option 1: udocker in Termux

See [path-a-nonroot.md](path-a-nonroot.md) — but with root, udocker
becomes faster and more stable.

### Option 2: chroot into full Linux

With root, you can chroot into a full Debian/Ubuntu:

```bash
su
mkdir -p /data/local/debian
# Install proot-distro in Termux first, then:
proot-distro install debian
# Then chroot into it (faster than proot because there's no syscall emulation)
```

This gives you full Linux without emulation — faster than proot. But still
**not Docker**.

---

## Step 6 — Autostart (Magisk service.d)

This is root's main advantage: reliable autostart.

```bash
su -c 'mkdir -p /data/adb/service.d'
su -c 'nano /data/adb/service.d/hp-vps.sh'
```

```sh
#!/system/bin/sh
# Runs automatically at boot (Magisk)
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 10                              # wait for networking & mounts to be ready

nohup sh /data/adb/battery-limit.sh >/dev/null 2>&1 &
nohup /data/data/com.termux/files/usr/bin/sshd >/dev/null 2>&1 &
```

```bash
su -c 'chmod +x /data/adb/service.d/hp-vps.sh'
```

Full details: [autostart.md](autostart.md)

---

## Step 7 — Battery limit

With root, you can now **set** a charge limit:

```bash
./scripts/battery-limit.sh detect
./scripts/battery-limit.sh set 80
```

Or better, use **ACC/AccA** — more resistant to brand quirks:

```bash
acc -s pc=80        # pause charge at 80%
```

Required reading: [battery.md](battery.md)

---

## Step 8 — Access & security

- [tunnel.md](tunnel.md) — access from the internet
- [hardening.md](hardening.md) — don't let your phone become a botnet

Especially for root: **never** grant root access to apps from unknown
sources, and don't use a system that doesn't receive Android security updates
for anything sensitive.

---

## ⚠️ Risks specific to Path B1

1. **Old Android versions don't get security patches.** Root + an outdated OS = a risky
   combination for anything facing the internet.
2. **Magisk can be detected** by banking/DRM apps — some will refuse
   to run.
3. **Samsung bootloader unlock is permanent** (Knox trip) — it can't be undone.
4. **Android OTA updates** will remove root and can cause a bootloop.
   Turn off automatic updates.

---

## Report your result

What's most useful to others:

```
Device      : (brand + model)
Android     : (version)
Magisk      : (version)
Real Docker : works / fails (error: ...)
cgroup      : v1 / v2 / absent
End path    : B1 + udocker / B1 + Docker / moved to B2
```