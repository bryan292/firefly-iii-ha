# Home Assistant Add-on: Firefly III

![Firefly III Logo](https://www.firefly-iii.org/static/img/logo-small.png)

Firefly III is a self-hosted financial manager. It helps you track your money and make smarter financial decisions.

This add-on packages the official Firefly III Docker image (fireflyiii/core) and makes it easily accessible through Home Assistant with Ingress support.

## Features

- Uses the official Firefly III Docker image
- Connects to Home Assistant's MariaDB add-on
- Automatic database migrations on startup
- Automatic APP_KEY generation for security
- Scheduled cron jobs for recurring tasks
- Accessible through Home Assistant's Ingress (no port forwarding needed)
- Compatible with external reverse proxies

## Installation

1. **Add the repository to your Home Assistant instance**
   - Navigate to Settings → Add-ons → Add-on Store
   - Click the menu in the top right corner and select "Repositories"
   - Add this repository URL

2. **Install the MariaDB add-on (if not already installed)**
   - Find MariaDB in the add-on store and install it
   - Configure the MariaDB add-on with a user and database for Firefly III:
     ```yaml
     databases:
       - homeassistant
       - firefly
     logins:
       - username: homeassistant
         password: YOUR_PASSWORD
       - username: firefly
         password: YOUR_FIREFLY_PASSWORD
     rights:
       - username: homeassistant
         database: homeassistant
       - username: firefly
         database: firefly
     ```
   - Start the MariaDB add-on

3. **Install the Firefly III add-on**
   - Find it in the add-on store after adding the repository
   - Click "Install"

4. **Configure Firefly III**
   - Set your database credentials to match what you configured in MariaDB
   - Example configuration:
     ```yaml
     db_host: core-mariadb
     db_port: 3306
     db_name: firefly
     db_user: firefly
     db_password: YOUR_FIREFLY_PASSWORD
     app_key: ""  # Leave empty for auto-generation
     timezone: "America/New_York"
     ```

5. **Start the add-on**
   - The first start may take a minute as database migrations run
   - Once started, click "OPEN WEB UI" to access Firefly III

## Configuration Options

| Option | Description |
|--------|-------------|
| `db_host` | MySQL/MariaDB host (default: core-mariadb) |
| `db_port` | MySQL/MariaDB port (default: 3306) |
| `db_name` | MySQL/MariaDB database name |
| `db_user` | MySQL/MariaDB username |
| `db_password` | MySQL/MariaDB password |
| `app_key` | Laravel app encryption key (leave empty to auto-generate) |
| `app_url` | External URL if accessing outside of Home Assistant (optional) |
| `trusted_proxies` | Proxy settings for reverse proxy (default: **) |
| `timezone` | Your timezone (default: America/Costa_Rica) |
| `php_memory_limit` | PHP memory limit (default: 512M) |

## First Run

On first run, the add-on will:

1. Generate a secure APP_KEY if none is provided
2. Run database migrations to set up the Firefly III database
3. Start the web server and make Firefly III available via Ingress

You can then create your first user by going to the Firefly III interface.

## Automated Tasks (Cron)

Firefly III relies on regular cron jobs to process recurring transactions and other scheduled tasks. The add-on includes a cron service that runs:

- `php artisan firefly-iii:cron` daily at 3:00 AM

To change the schedule, you can SSH into the add-on and edit `/etc/cron.d/firefly-cron`.

## Using with External Reverse Proxies

If you want to access Firefly III from outside your home network:

1. Set the `app_url` option to your external URL (e.g., https://finances.example.com)
2. Keep `trusted_proxies` set to "**" (allows all proxies)
3. Configure your reverse proxy to pass headers:
   - `X-Forwarded-Proto`
   - `X-Forwarded-Host`
   - `X-Forwarded-For`

## Data Persistence

Firefly III stores all your financial data in the MariaDB database. The add-on also maintains:

- `/data/app_key` - Your generated APP_KEY for encryption

## Troubleshooting

### 502 Bad Gateway or Proxy Errors
- Ensure `trusted_proxies` is set to "**"
- Check that your reverse proxy is correctly passing the required headers

### Database Connection Errors
- Verify your database credentials are correct
- Confirm the MariaDB add-on is running
- Check logs with "Show logs" in the add-on interface

### Permissions Issues
- The add-on automatically sets proper permissions on startup
- If you see permission errors, try restarting the add-on

### Can't Create User or Log In
- Check for database migration errors in the logs
- Verify database connectivity

## Uninstalling

Before uninstalling:

1. Back up your data using Firefly III's built-in export feature
2. If you want to completely remove all data, you'll need to drop the database in MariaDB

## Support

If you have questions or need help, please open an issue on the GitHub repository.
