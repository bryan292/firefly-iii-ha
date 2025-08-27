# Home Assistant Add-on: Firefly III

Firefly III is a self-hosted financial manager. It can help you keep track of expenses, income, budgets and everything in between.

## About

This add-on allows you to run Firefly III within Home Assistant. It integrates with the MariaDB add-on to store its data.

## Installation

Follow these steps to get the add-on installed on your system:

1. Navigate in your Home Assistant frontend to **Supervisor** -> **Add-on Store**.
2. Add this repository to your add-on store.
3. Find the "Firefly III" add-on and click it.
4. Click on the "INSTALL" button.

## How to use

The add-on requires a MariaDB database to store its data. Make sure you have the MariaDB add-on installed and properly set up.

1. In the configuration of the add-on, fill in the database details. If you're using the MariaDB add-on, use `core-mariadb` as the host.
2. Start the add-on.
3. Check the logs to see if everything is working correctly.
4. Open the web UI and start using Firefly III.

## Configuration

Example add-on configuration:

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

### Option: `app_url`

The URL of your Firefly III instance. If left empty, it will use the ingress URL.

### Option: `database`

The database configuration:

- `engine`: The database engine to use (only MySQL/MariaDB is supported).
- `host`: The host of the database server.
- `port`: The port of the database server.
- `username`: The username to use for the database connection.
- `password`: The password to use for the database connection.
- `database`: The database to use.

### Option: `timezone`

The timezone to use for Firefly III.

### Option: `admin_email`

The email address of the admin user.

### Option: `log_level`

The log level for Firefly III.

## Features

- Automatically installs the latest version of Firefly III
- Integrates with the MariaDB add-on for data storage
- Easy configuration through the Home Assistant UI
- Secure access through Home Assistant authentication

## Support

Got questions?

You have several options to get them answered:

- The [Home Assistant Discord Chat Server](https://discord.gg/c5DvZ4e).
- The Home Assistant [Community Forum](https://community.home-assistant.io).
- Join the [Reddit subreddit](https://reddit.com/r/homeassistant) in [/r/homeassistant](https://reddit.com/r/homeassistant).

In case you've found a bug, please [open an issue on our GitHub](https://github.com/bryan292/firefly-iii-ha/issues).
