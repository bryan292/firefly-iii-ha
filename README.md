# Firefly III (Home Assistant Add-on)

This add-on packages Firefly III for Home Assistant with Ingress (open it via Supervisor).

## Install
1. On your Home Assistant host, create: `/addons/local/firefly-iii`
2. Copy all files from this repository there.
3. Home Assistant → Settings → Add-ons → Add-on Store → (⋮) → Reload.
4. Find **Firefly III (Ingress)** under "Local add-ons", click **Install**.
5. Configure the add-on options to match your MySQL/MariaDB add-on:
   - **db_host**, **db_port**, **db_name**, **db_user**, **db_password**
   - Optionally set **timezone**, **site_owner**, **app_url**.
6. Start the add-on, then click **OPEN** to access Firefly III.

## Notes
- First start may take longer while the database initializes and migrations run.
- Data persists under `/data/firefly` (including `.env` and `storage/`).
- If you later change DB credentials, stop the add-on, update options, start again.
- To reset the app key, set `generate_app_key: true` and blank `APP_KEY` in `/data/firefly/.env` (advanced).

## Troubleshooting
- If **OPEN** is disabled, ensure the add-on is started and no errors appear in logs.
- DB connection errors: verify host/port/auth and that your DB add-on is running.
- Path/URL issues behind Ingress: leave `app_url` blank or set it to your external URL (reverse proxy must forward headers; `TRUSTED_PROXIES` is set to `**`).
- To rebuild after changes: Uninstall → Reload → Install (or use Rebuild if available).
