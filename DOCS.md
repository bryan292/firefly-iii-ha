# Firefly III Add-on Documentation

## Introduction

Firefly III is a free and open source personal finance manager. This add-on allows you to run Firefly III within Home Assistant, with secure ingress access and MariaDB integration.

## Features

- Secure ingress access via Home Assistant
- MariaDB database integration
- Automatic setup and migration
- Admin user creation (optional)
- Customizable log level and timezone

## Configuration

Example configuration in Home Assistant:

```yaml
app_url: ""
database:
  engine: mysql
  host: core-mariadb
  port: 3306
  username: firefly
  password: mysecretpassword
  database: firefly
timezone: Europe/London
admin_email: admin@example.com
log_level: info
```

### Options

- `app_url`: The URL of your Firefly III instance. Leave empty to use ingress.
- `database`: Database connection details.
- `timezone`: Timezone for Firefly III.
- `admin_email`: Email for the admin user (optional).
- `log_level`: Log verbosity.

## Usage

1. Install the MariaDB add-on and configure it.
2. Configure Firefly III add-on with your database details.
3. Start the add-on.
4. Access Firefly III via the Home Assistant web UI.

## Support

- [Home Assistant Discord](https://discord.gg/c5DvZ4e)
- [Community Forum](https://community.home-assistant.io)
- [GitHub Issues](https://github.com/bryan292/firefly-iii-ha/issues)

## License

MIT License
