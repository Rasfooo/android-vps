# Hardening the phone-server

> 📖 **RESEARCH** — Standard Linux security practice, not yet run by the author on a phone.

**You just put a phone on the internet.** Without these steps, within 24 hours
you will be sent thousands of login attempts from bots. This is not theory — it
happens to every live public IPv4 address.

A phone-server carries extra risk compared to a VPS: if it gets compromised, it
is not just your data that is lost, but your phone also becomes part of a botnet.

---

## 0. Basic principles

1. **Do not expose SSH to the public internet.** Use Tailscale/WireGuard. This
   one rule prevents 95 % of problems.
2. **Expose as little as possible.** If it does not need to be public, do not make it public.
3. **Assume this phone will die** — so do not keep the only copy of your data on it.
4. **Update regularly.** Phone kernels rarely get security patches; that is a risk
   you accept.

---

## 1. Update the system

```bash
# postmarketOS / Alpine
sudo apk update && sudo apk upgrade -a

# Android + Termux
pkg update && pkg upgrade
```

Schedule it automatically:

```bash
# systemd
sudo systemctl enable --now unattended-upgrades 2>/dev/null || true

# OpenRC: use cron
echo '0 4 * * * apk update && apk upgrade -a' | sudo crontab -
```

---

## 2. Secure SSH

### Disable password login — use keys only

On your computer (not on the phone):

```bash
ssh-keygen -t ed25519 -C "hp-vps"      # if you don't have a key yet
ssh-copy-id user@<alamat-hp>            # copy the public key
```

On the phone, edit `/etc/ssh/sshd_config` (or `$PREFIX/etc/ssh/sshd_config` in Termux):

```
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 20
X11Forwarding no
AllowAgentForwarding no
```

```bash
sudo systemctl restart sshd     # or: sudo rc-service sshd restart
```

> ⚠️ **Test that your key works in another terminal BEFORE closing this session.**
> Otherwise you can lock yourself out of your phone.

### If SSH has to be public

```bash
sudo apk add fail2ban          # postmarketOS
# or
pkg install fail2ban           # Termux

# /etc/fail2ban/jail.local
[sshd]
enabled = true
port = 22
maxretry = 3
bantime = 3600
```

Also change the port to something above 1024 (many automated attacks only
target ports <1024).

---

## 3. Firewall

Flip the rule: **deny everything inbound, allow only what you need.**

```bash
# postmarketOS
sudo apk add nftables

sudo tee /etc/nftables.d/hp-vps.nft >/dev/null <<'EOF'
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif lo accept
    ip protocol icmp accept
    # SSH only from the Tailscale network (100.64.0.0/10) — adjust as needed
    ip saddr 100.64.0.0/10 tcp dport 22 accept
    # Web app (if accessed via Cloudflare Tunnel, this isn't even needed)
    tcp dport 8080 accept
    drop
  }
}
EOF

sudo rc-service nftables restart     # or: systemctl restart nftables
```

**If you use Cloudflare Tunnel, you don't need to open any ports.** The
tunnel goes out from the phone, so the firewall can `drop` all inbound except SSH
from Tailscale. This is the safest setup.

---

## 4. Docker

```bash
# Run the container without root inside
docker run --user 1000:1000 ...

# Limit capabilities (mandatory for containers from third-party images)
docker run \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  --read-only \
  --tmpfs /tmp \
  ...
```

**Never mount the Docker socket into a container:**

```yaml
# ❌ DON'T
volumes:
  - /var/run/docker.sock:/var/run/docker.sock       # this is equivalent to giving root to the internet
```

If you need Docker access from a container, use
[`docker-socket-proxy`](https://github.com/Tecnativa/docker-socket-proxy) which
restricts the commands that are allowed.

### Check containers running as root

```bash
docker ps --format '{{.Names}}' | while read n; do
  printf '%-24s %s\n' "$n" "$(docker inspect -f '{{.Config.User}}' "$n" | sed 's/^$/root(bahaya)/')"
done
```

---

## 5. Automatic updates for Docker

```bash
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower --cleanup --schedule "0 0 4 * * *"
```

⚠️ Watchtower needs the Docker socket — so run it **only if you are aware of the
risk**, and do not expose Watchtower to the internet. A safer alternative:
manual updates scheduled via cron.

---

## 6. Don't store secrets in the repo or the image

```bash
# ❌ DON'T
ENV DB_PASSWORD=rahasia123          # in the Dockerfile — it goes into the image, anyone can see it

# ✅ Do this
docker run --env-file /root/.secrets/app.env ...
sudo chmod 600 /root/.secrets/app.env
```

Minimal `.gitignore`:

```
.env
*.key
*.pem
credentials.json
```

---

## 7. Monitor what's happening

```bash
# Who logged in
last -n 20
who

# Failed login attempts
sudo grep 'Failed password' /var/log/auth.log | tail -20

# Suspicious outbound connections (is the phone a botnet now?)
ss -tupn | grep ESTAB

# What containers are running
docker ps -a
```

Run the checks in this repo periodically:

```bash
./scripts/healthcheck.sh
```

---

## 8. Backup — this phone will break

Don't keep the only copy of your data on a used phone. Assume the device can
die at any moment.

```bash
# Example: send a backup elsewhere via rsync/rclone
rclone sync /home/user/data remote:hp-vps-backup --progress

# Or tar + send to another server
tar czf - /home/user/data | ssh user@serverlain 'cat > backup-$(date +%F).tar.gz'
```

Schedule it daily via cron. **Test the restore** — a backup that has never been
restored is not a backup.

---

## Security checklist

- [ ] SSH: password login disabled, keys only
- [ ] SSH: not exposed publicly (or fail2ban + non-standard port)
- [ ] Firewall: `drop` policy, only the ports you need opened
- [ ] Docker: no Docker socket in any container
- [ ] Secrets: not in the image/repo, files `600`
- [ ] Updates: scheduled automatically
- [ ] Backup: runs daily, and the restore has been tested
- [ ] Monitoring: `healthcheck.sh` runs regularly, logs are checked
- [ ] `healthcheck.sh` passes with no critical status