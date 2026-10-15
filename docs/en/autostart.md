# Autostart: make it come back alive on its own after a reboot

> 🧪 **NEEDS TESTING** — the commands here are standard, but the author hasn't
> run them on a real device.

A phone-server that doesn't automatically recover after a reboot isn't a
server. This is what separates a "hobby project" from a "real VPS".

---

## Pick according to your init system

| Condition | Init | Autostart method |
|---|---|---|
| postmarketOS | OpenRC | `rc-update add` |
| postmarketOS + systemd | systemd | `systemctl enable` |
| Android + Magisk | `magisk`/init.d | service module |
| Termux (no root) | ✗ | Termux:Boot |

Check which one you're using:

```bash
ps -p 1 -o comm=        # "init" = OpenRC/Android · "systemd" = systemd
```

---

## postmarketOS — OpenRC

```bash
# Built-in services
sudo rc-update add sshd default
sudo rc-update add docker default

# Your own service: put the script in /etc/init.d/
sudo nano /etc/init.d/hp-vps
```

```sh
#!/sbin/openrc-run
# /etc/init.d/hp-vps
name="hp-vps"
description="HP-VPS main service"
command="/usr/local/bin/hp-vps-start.sh"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/hp-vps.log"
error_log="/var/log/hp-vps.err"

depend() {
    need net
    after firewall docker
    use dns logger
}
```

```bash
sudo chmod +x /etc/init.d/hp-vps /usr/local/bin/hp-vps-start.sh
sudo rc-update add hp-vps default
sudo rc-service hp-vps start
sudo rc-service hp-vps status
```

---

## postmarketOS — systemd

```ini
# /etc/systemd/system/hp-vps.service
[Unit]
Description=HP-VPS main service
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=user
WorkingDirectory=/home/user/app
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=always
RestartSec=10
# Limit it so it doesn't use up all the phone's RAM
MemoryMax=1G

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now hp-vps
systemctl status hp-vps
journalctl -u hp-vps -f        # watch the logs
```

### Docker containers have their own restart policy

For containers, the most reliable way isn't systemd, but Docker itself:

```yaml
# docker-compose.yml
services:
  web:
    image: nginx
    restart: unless-stopped        # ← this is what brings it back after a reboot
```

```bash
docker run -d --restart unless-stopped nginx
```

**Rule:** if `docker.service` already autostarts, a container with
`restart: unless-stopped` will automatically run after a reboot. You don't need
an extra systemd service for that.

---

## Android + Magisk

Magisk runs scripts from `service.d` at boot:

```bash
su -c 'mkdir -p /data/adb/service.d'
su -c 'nano /data/adb/service.d/hp-vps.sh'
```

```sh
#!/system/bin/sh
# /data/adb/service.d/hp-vps.sh — runs automatically at boot (Magisk)
# Wait for boot to finish first
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 10

# Charge limit (see docs/en/battery.md)
nohup sh /data/adb/battery-limit.sh >/dev/null 2>&1 &

# Run your service inside proot/chroot
nohup /data/data/com.termux/files/usr/bin/cloudflared tunnel run hp-vps >/dev/null 2>&1 &
```

```bash
su -c 'chmod +x /data/adb/service.d/hp-vps.sh'
```

> ⚠️ `sleep 10` is not decoration. Without it, the network and mounts aren't
> ready yet and your script will fail silently.

---

## Termux (no root) — Termux:Boot

Termux does **not** automatically start after a reboot. You need the
**Termux:Boot** app (from F-Droid, not the Play Store).

1. Install Termux:Boot, open it **once** (this registers the boot receiver)
2. Disable battery optimization for Termux **and** Termux:Boot:
   Settings → Apps → Termux → Battery → **Unrestricted**
3. Create the script:

```bash
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/start-services.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
sshd
cloudflared tunnel run hp-vps
EOF
chmod +x ~/.termux/boot/start-services.sh
```

> ⚠️ **The hard truth:** without root, Android can still kill Termux
> (system updates, aggressive memory management). For a server you actually
> rely on, root is the answer.

---

## Verify that autostart really works

**Don't assume. Reboot and prove it.**

```bash
# 1. Note the uptime before
cat /proc/uptime | awk '{printf "%.0f menit\n", $1/60}'

# 2. Reboot
sudo reboot        # or: su -c reboot

# 3. Wait 2 minutes, then from another device:
ssh user@<phone-address>
systemctl status hp-vps        # or: rc-service hp-vps status
docker ps                       # the container should be running again

# 4. Check that the uptime has reset
cat /proc/uptime | awk '{printf "%.0f menit\n", $1/60}'
```

If the service isn't running after the reboot, check the logs:

```bash
journalctl -b -u hp-vps --no-pager | tail -30     # systemd
cat /var/log/hp-vps.err                            # OpenRC
logcat | grep -i magisk                            # Android
```

**Test this periodically.** Phones go down unexpectedly more often than VPSs
(power, updates, thermal). Untested autostart = autostart that doesn't exist.

---

## Anti-patterns to avoid

| ❌ Don't | ✅ Do |
|---|---|
| `nohup ./app &` with no autostart | service + `systemctl enable` |
| Relying on Termux without Termux:Boot | install Termux:Boot, or root |
| `restart: no` on an important container | `restart: unless-stopped` |
| Putting scripts in `/tmp` (gone on reboot) | `/usr/local/bin` or `/data/adb` |
| No logs | direct them to a file or journal |
| Using `sleep` as a substitute for dependencies | proper `After=`/`depend()` |

`sleep` is still fine as an **addition** for Android hardware that isn't ready
yet (see the Magisk example above), not as a substitute for service
dependencies.
