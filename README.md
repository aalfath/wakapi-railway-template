[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/wakapi-1?utm_medium=integration&utm_source=button&utm_campaign=wakapi)

# Wakapi on Railway

One-click [Wakapi](https://github.com/muety/wakapi), the self-hosted, WakaTime-compatible backend for coding-time statistics, on [Railway](https://railway.com).

## What it deploys

| Service | What it does |
|---|---|
| **Wakapi** | Web dashboard and WakaTime-compatible API. Built from this repo: the official `ghcr.io/muety/wakapi:2.18.2` image pinned by digest, plus `start.sh`. Public HTTPS domain, health check `/api/health`. |
| **Postgres** | Railway's PostgreSQL, on its own volume. Holds every user, heartbeat and setting. |

`start.sh` waits for Postgres, creates the admin account on an empty database (through a loopback-only instance, so the public URL never shows the "first user becomes admin" sign-up), sizes `GOMAXPROCS`/`GOMEMLIMIT` to the container, and starts Wakapi. Any failure exits non-zero, so Railway restarts the service. Wakapi runs fine at Railway's 0.5 GB per-service limit.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `WAKAPI_ADMIN_USERNAME` | `admin` | Admin account created on first boot. |
| `WAKAPI_ADMIN_PASSWORD` | generated | Admin password on first boot. Copy it from the Variables tab. Changing it later has no effect: use Wakapi's settings. |
| `WAKAPI_PASSWORD_SALT` | generated | Pepper for password hashes. Never change it after the first deploy. |
| `WAKAPI_COOKIE_KEY` | generated | Base64 key for login cookies, so sessions survive restarts. |
| `WAKAPI_PUBLIC_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Used in links and e-mails. |
| `WAKAPI_DB_*` | references to `Postgres` | Private-network connection to the database. |
| `PORT` | `3000` | Port Wakapi listens on. |

Fixed in the image: PostgreSQL, secure cookies (Railway serves HTTPS), sign-up **closed** (`WAKAPI_ALLOW_SIGNUP=false`; set it to `true` on the service to open it, or use invite links from Settings). Optional extras such as e-mail (`WAKAPI_MAIL_*`) and OpenID Connect are documented in [Wakapi's README](https://github.com/muety/wakapi#-configuration).

## After deploy

1. Copy `WAKAPI_ADMIN_PASSWORD` from the Wakapi service's Variables tab and log in at your Railway domain.
2. Copy your API key from **Settings** and point your editor's WakaTime plugin at it (`~/.wakatime.cfg`):

   ```ini
   [settings]
   api_url = https://YOUR-DOMAIN/api
   api_key = YOUR-WAKAPI-API-KEY
   ```

## Updates

The Wakapi service builds from this repo's `main` branch. When we move the pin to a new Wakapi release and merge to `main`, Railway shows everyone who deployed the template an "update available" notice; you choose when to apply it. Read [`CHANGELOG.md`](CHANGELOG.md) first: breaking changes are listed at the top of each entry. Wakapi runs its own database migrations on start.

## Licence

This wrapper: MIT. Wakapi: MIT, © Ferdinand Mütsch and contributors.
