# Access from the internet: CGNAT & tunnel

> 📖 **RESEARCH** — Based on the Cloudflare & Tailscale documentation. Not yet
> tested by the author on a real device.

This is the number one barrier that makes people give up. The good news: there
are free solutions that don't need a public IP.

---

## Why inbound ports are blocked

Almost all cellular internet plans (and many home ISPs) use **CGNAT
(Carrier-Grade NAT)**. That means:

- You **don't have a public IPv4** — your IP is shared with hundreds of customers
- **Port 80, 443, and almost all inbound ports are blocked** by the carrier
- Port forwarding on the router **won't help** — the traffic never reaches your
  router

### Check whether you're behind CGNAT

```bash
# Method 1: script in this repo
./scripts/expose-tunnel.sh check

# Method 2: manual
# See the IP used for outbound traffic
ip route get 1.1.1.1 | awk '{print $7}'
# Then compare it with the public IP seen from outside
curl -s https://api.ipify.org
```

If your local IP is very different from the public IP, or your local IP is in
the **`100.64.0.0/10`** range, you're behind CGNAT. That range is specifically
for CGNAT.

> Note: IPv6 sometimes saves the day. If your carrier gives you public IPv6
> (`curl -6 https://api64.ipify.org` succeeds), you **might** be able to use
> inbound ports over IPv6. Success varies per carrier — don't rely on it.

---

## Tunnel choices

| Solution | Free | Needs an account | Your own domain | Best for |
|---|---|---|---|---|
| **Cloudflare Tunnel** | ✓ | ✓ (free) | ✓ (possible) | Public web server — **recommended** |
| **Tailscale** | ✓ | ✓ | ✗ (uses `*.ts.net`) | Private access between your own devices |
| **ngrok** | ✓ (limited) | ✓ | ✗ (random URL) | Quick tests, demos |
| **Self-hosted WireGuard** | ✓ | ✗ | needs a VPS | Those who have a small VPS as an intermediary |

---

## Cloudflare Tunnel (recommended)

**Why:** free, doesn't open any port (your phone makes outbound connections,
it doesn't accept them), gets automatic HTTPS, can use your own domain, and can
run as a service that stays up after a reboot.

### Quick way — for a test (no account)

```bash
./scripts/expose-tunnel.sh install
./scripts/expose-tunnel.sh quick 8080
```

A URL like `https://xxxx-xxxx.trycloudflare.com` will appear. This URL is
**random and disappears** when the process stops — good for testing, not for
permanent use.

### Permanent way — use your domain

Four steps, done once:

```bash
cloudflared tunnel login               # open the URL in a browser, pick a domain
cloudflared tunnel create hp-vps       # create the tunnel
cloudflared tunnel route dns hp-vps vps.domainmu.com
cloudflared tunnel run hp-vps
```

Configuration `~/.cloudflared/config.yml`:

```yaml
tunnel: hp-vps
credentials-file: /root/.cloudflared/<tunnel-id>.json
ingress:
  - hostname: vps.domainmu.com
    service: http://localhost:8080
  - service: http_status:404        # required: the last rule must be 404
```

> **The `login` step is deliberately not automated** by the script in this repo,
> because it requires opening a browser and choosing an account — that's your
> decision, not the script's.

### Run it after a reboot

See [autostart.md](autostart.md). Example for systemd:

```ini
# /etc/systemd/system/cloudflared.service
[Unit]
Description=Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel run hp-vps
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now cloudflared
sudo systemctl status cloudflared
```

---

## Tailscale (if it's just for you)

**Why:** simpler than Cloudflare, no domain needed, and traffic is encrypted
end-to-end over WireGuard. But only devices on your Tailscale network can
access it — it's not public.

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4          # private IP on the tailscale network
```

After that, from your laptop that also has Tailscale installed:

```bash
ssh user@<ip-tailscale>
curl http://<ip-tailscale>:8080
```

**Good for:** SSH, admin dashboards, private panels — anything that doesn't
need to be accessed by others. This is the safest choice because nothing is
exposed to the public internet.

**You can do both:** Cloudflare for public things, Tailscale for SSH/admin.
This is actually the ideal setup — never open SSH to the public internet.

---

## ⚠️ Security: don't expose SSH to the internet

If you forward port 22 to the public internet, you'll be sent thousands of
login attempts every day by bots. What may be exposed to Cloudflare:

| ✅ Safe to expose | ❌ Never |
|---|---|
| Web app behind authentication | SSH |
| Public API endpoint | Admin dashboard without login |
| Static files | Database (Postgres, MySQL, Redis) |
| Webhooks | Docker socket |

For SSH and admin: **just use Tailscale or WireGuard.** If you absolutely must
expose SSH, at minimum: disable password login, use keys only, change the port,
install fail2ban. All of that is in [hardening.md](hardening.md).

---

## If the tunnel doesn't work

| Symptom | Cause |
|---|---|
| `cloudflared` won't start | Wrong architecture — check `uname -m`, download `arm64` for modern phones |
| URL appears but 502 | Local service isn't running on that port — check `curl localhost:PORT` |
| Connection drops every few minutes | The phone's Wi-Fi is power-saving — turn off Wi-Fi power saving, or use a cable |
| Extremely slow | The phone is throttling (heat) or Wi-Fi is weak — see [battery.md](battery.md) |
| Tunnel dies after a reboot | Not installed as a service yet — see [autostart.md](autostart.md) |
