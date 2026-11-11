# Firefly III (Home Assistant Add-on)

![Firefly III add-on icon](icon.png)

Firefly III is a self-hosted personal finance manager. This repository packages the official Firefly III container so it runs cleanly as a Home Assistant add-on with Supervisor ingress, persistent storage, and automatic database bootstrapping.

Learn more about the upstream project:
- Website: [firefly-iii.org](https://firefly-iii.org)
- Source: [Firefly III GitHub repository](https://github.com/firefly-iii/firefly-iii)

> **Project status:** This add-on is still in active development. Many of the scaffold and maintenance scripts were created with the help of AI assistants, including [Aider](https://aider.chat/) and [OpenAI Codex](https://openai.com/blog/openai-codex).

## Features
- Ingress-ready UI so the add-on opens directly inside Home Assistant.
- Works with MariaDB/MySQL or the bundled SQLite datastore.
- Persists Firefly III configuration and storage beneath `/data/firefly`.
- Automatically manages the Laravel `.env`, APP_KEY generation, migrations, and health checks.
- Ships with bundled icon/graphics for a polished appearance in the add-on store.

## Installation
The add-on packages Firefly III 6.7.9 and supports amd64 and aarch64 hosts.

1. In Home Assistant, navigate to **Settings → Add-ons → Add-on Store**.
2. Click the overflow menu (⋮) and choose **Repositories**, then add:
   - `https://github.com/bryan292/firefly-iii-ha`
3. After the store refreshes, locate **Firefly III** under the repository you just added and click **Install**.
4. Configure the add-on options as needed (see below), then click **Start**.
5. Use **OPEN** to launch Firefly III through Supervisor ingress.

## Configuration

| Option | Default | Description |
| --- | --- | --- |
| `db_connection` | `sqlite` | Choose `sqlite` for local storage or `mysql` for an external MySQL/MariaDB database. |
| `db_host` | `core-mariadb` | Hostname of your MariaDB/MySQL server when `db_connection` is `mysql`. |
| `db_port` | `3306` | Database port. |
| `db_name` | `firefly` | Database schema name. |
| `db_user` | `firefly` | Database username. |
| `db_password` | `""` | Database password (blank when using SQLite). |
| `timezone` | `UTC` | Select from the bundled list of timezones (UTC, America/New_York, America/Chicago, America/Denver, America/Los_Angeles, America/Costa_Rica, Europe/London, Europe/Berlin, Europe/Paris, Asia/Tokyo, Asia/Singapore, Australia/Sydney). |
| `site_owner` | `owner@example.com` | Email address shown for the site owner in Firefly III. |
| `generate_app_key` | `true` | Generate a missing Laravel `APP_KEY` on startup. Existing keys are preserved, including on restart. |
| `mail_mailer` | `log` | Use `smtp` to send email, or `log` to keep email in application logs. |
| `mail_host` | `""` | SMTP server hostname; required when `mail_mailer` is `smtp`. |
| `mail_port` | `587` | SMTP server port (typically 587 for STARTTLS or 465 for implicit TLS). |
| `mail_username` | `""` | SMTP authentication username. |
| `mail_password` | `""` | SMTP authentication password. |
| `mail_encryption` | `tls` | `tls` for SMTP with STARTTLS, or `ssl` for implicit TLS (SMTPS). |
| `mail_from` | `""` | Sender email address; defaults to `site_owner` when empty. |

SMTP settings must be entered explicitly; the add-on does not inherit Home Assistant's notification configuration.
Existing installations without mail options continue using the `log` mailer.

All configuration is stored in `/data/options.json` by Home Assistant. The add-on keeps `/data/firefly/.env` in sync so manual edits are rarely required.

## Usage Notes
- Startup runs Laravel migrations and the Firefly III database upgrade commands before serving requests. Back up the add-on and any external database before upgrading.
- For best reliability, ensure the MariaDB/MySQL server is running before starting the add-on.
- Persistent storage (including uploads, sessions and OAuth keys) lives in `/data/firefly/storage`, selected through `LARAVEL_STORAGE_PATH`. Existing keys are reused on restart.
- SQLite uses `/data/firefly/database.sqlite`, which is preserved across restarts and upgrades. Changing `db_connection` selects a different database; it does not migrate existing data.
- The add-on now exposes Firefly III on `http://<home-assistant-host>:8080`, so importers or API clients can talk to Firefly directly instead of going through ingress (which blocks POST/PUT calls).
- To rotate credentials, stop the add-on, update the options, then start it again.
- The health check is served from `/public/healthcheck.html`, enabling Home Assistant's watchdog.

## Releases
- Releases are produced by a GitHub Actions workflow that monitors pushes to `master` or manual workflow dispatches.
  - The workflow reads the version in `config.yaml`, updates the changelog, tags the repository, and publishes a GitHub release with generated notes.
- When hosting this add-on repository, point the add-on store entry to the latest GitHub release archive.
  - Example: `https://github.com/bryan292/firefly-iii-ha/releases/latest/download/firefly-iii-ha.zip`

## Troubleshooting
- If **OPEN** is disabled, verify the add-on is running and review the Supervisor logs.
- The startup script retries migrations up to 15 times and stops if they keep failing.
- `generate_app_key: true` generates a key only when it is missing or still the upstream template placeholder. A valid existing key is always reused.
- With `generate_app_key: false`, you must provide an existing `APP_KEY` in `/data/firefly/.env`; otherwise startup stops.
- Preserve your application key and include it in backups: changing it invalidates sessions and can make encrypted data unreadable.

## Development checks
Run the startup regression tests against the real application image:

```sh
docker build -t firefly-ha:test .
python3 -m unittest discover -s tests -v
```

The tests cover SQLite migrations and persistence, APP_KEY generation and reuse, SMTP configuration and secret escaping, and MySQL configuration compatibility.
They use temporary local containers and do not send email.

## License
Distributed under the terms of the [MIT License](LICENSE).
