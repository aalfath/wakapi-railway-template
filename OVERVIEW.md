# Deploy and Host Wakapi on Railway

Wakapi is a free, open-source, self-hosted backend for coding-time statistics that speaks the WakaTime API. You point the WakaTime plugins in VS Code, JetBrains, Vim or 60+ other editors at your own server, and Wakapi records heartbeats and shows dashboards, summaries, leaderboards and badges per project, language and editor.

## About Hosting Wakapi

This template runs Wakapi 2.18.2 from the official image (pinned by version and digest) with a Railway PostgreSQL database on its own volume, so all users and heartbeats survive redeploys. Wakapi listens on Railway's `PORT`, gets a public HTTPS domain and a `/api/health` health check. On the first boot a start script waits for Postgres and creates the admin account from generated variables, and public sign-up stays closed, so nobody else can claim your instance. The password salt, cookie key and admin password are generated per deploy. Wakapi fits comfortably on Railway's 0.5 GB plan.

## Common Use Cases

* Track your own coding time across editors and machines without sending it to a third-party service
* Give a team a private, WakaTime-compatible dashboard and leaderboard
* Keep a long-term history of coding activity, or import an existing WakaTime history

## Dependencies for Wakapi Hosting

* PostgreSQL (Railway's Postgres service, included)
* A WakaTime plugin in your editor, pointed at your Wakapi URL

### Deployment Dependencies

* Wakapi: https://github.com/muety/wakapi
* WakaTime editor plugins: https://wakatime.com/plugins
* Template repo: https://github.com/aalfath/wakapi-railway-template

### Implementation Details

**Services:** `Wakapi` (web app and WakaTime API, built from the template repo) and `Postgres` (the database, on a volume). Postgres starts first; Wakapi waits for it.

**After deploy:** open the Wakapi service's **Variables** tab, copy `WAKAPI_ADMIN_PASSWORD`, and log in at `https://YOUR-DOMAIN` as `admin` (or the `WAKAPI_ADMIN_USERNAME` you chose). Your API key is under **Settings**. Then set your editor's `~/.wakatime.cfg`:

```ini
[settings]
api_url = https://YOUR-DOMAIN/api
api_key = YOUR-WAKAPI-API-KEY
```

**More users:** sign-up is closed. Create invite links under Settings, or set `WAKAPI_ALLOW_SIGNUP=true` for a while. Changing `WAKAPI_ADMIN_PASSWORD` later does not change the existing password: change it in Wakapi's settings. Keep `WAKAPI_PASSWORD_SALT` unchanged, or existing passwords stop working.

**Optional:** e-mail (password resets, weekly reports) through the `WAKAPI_MAIL_*` variables, and OpenID Connect login; see Wakapi's README.

**Updates:** the Wakapi service builds from a GitHub repo, so Railway shows an "update available" notice when the template moves to a new Wakapi version. Read the repo's `CHANGELOG.md` before you apply it.

## Why Deploy Wakapi on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Wakapi on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
