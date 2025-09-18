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
1. In Home Assistant, navigate to **Settings → Add-ons → Add-on Store**.
2. Click the overflow menu (⋮) and choose **Repositories**, then add:
   - `https://github.com/bryan292/firefly-iii-ha`
3. After the store refreshes, locate **Firefly III** under the repository you just added and click **Install**.
4. Configure the add-on options as needed (see below), then click **Start**.
5. Use **OPEN** to launch Firefly III through Supervisor ingress.

## Configuration
| Option | Default | Description |
| --- | --- | --- |
| `db_connection` | `sqlite` | Choose `sqlite` for local storage or `mysql`/`mariadb` for an external database. |
| `db_host` | `core-mariadb` | Hostname of your MariaDB/MySQL server when `db_connection` is `mysql`. |
| `db_port` | `3306` | Database port. |
| `db_name` | `firefly` | Database schema name. |
| `db_user` | `firefly` | Database username. |
| `db_password` | `""` | Database password (blank when using SQLite). |
| `timezone` | `UTC` | Select from the bundled list of timezones (UTC, America/New_York, America/Chicago, America/Denver, America/Los_Angeles, America/Costa_Rica, Europe/London, Europe/Berlin, Europe/Paris, Asia/Tokyo, Asia/Singapore, Australia/Sydney). |
| `site_owner` | `owner@example.com` | Email address shown for the site owner in Firefly III. |
| `generate_app_key` | `true` | When true, the add-on creates or refreshes the Laravel `APP_KEY` during startup. |

All configuration is stored in `/data/options.json` by Home Assistant. The add-on keeps `/data/firefly/.env` in sync so manual edits are rarely required.

## Usage Notes
- First startup may take a few minutes while dependencies install and database migrations execute.
- For best reliability, ensure the MariaDB/MySQL server is running before starting the add-on.
- Persistent storage (including Firefly III uploads) lives in `/data/firefly/storage`.
- To rotate credentials, stop the add-on, update the options, then start it again.
- The health check is served from `/public/healthcheck.html`, enabling Home Assistant's watchdog.

## Releases
- Releases are produced by a GitHub Actions workflow that monitors pushes to `master` or manual workflow dispatches.
  - The workflow reads the version in `config.yaml`, updates the changelog, tags the repository, and publishes a GitHub release with generated notes.
- When hosting this add-on repository, point the add-on store entry to the latest GitHub release archive.
  - Example: `https://github.com/bryan292/firefly-iii-ha/releases/latest/download/firefly-iii-ha.zip`

## Troubleshooting
- If **OPEN** is disabled, verify the add-on is running and review the Supervisor logs.
- The startup script retries database connectivity up to 15 times before giving up.
- To reset the application key, set `generate_app_key: true` and remove `APP_KEY` from `/data/firefly/.env` (advanced use only).

## License
Distributed under the terms of the [MIT License](LICENSE).
