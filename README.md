# Home Assistant Add-on: Firefly III

Firefly III is a self-hosted financial manager. It can help you keep track of expenses, income, budgets and everything in between.

## About

This add-on allows you to run Firefly III directly on your Home Assistant instance, providing a powerful personal finance management tool that integrates with your smart home setup.

## Installation

Follow these steps to install the add-on:

1. Navigate in your Home Assistant frontend to **Supervisor** -> **Add-on Store**.
2. Add this repository URL: [your-repository-url]
3. Find the "Firefly III" add-on and click it.
4. Click on the "INSTALL" button.

## Configuration

**Note**: After installing, you should change the default database password and app key for security.

Example configuration:


### Option: `database_type`

Choose between using the add-on's internal MariaDB database (`internal`) or an external one (`external`), such as the Home Assistant MariaDB add-on.

### Option: `database_host`

If using an external database, the hostname or IP address of the MariaDB server. For the Home Assistant MariaDB add-on, use `core-mariadb`.

### Option: `database_port`

If using an external database, the port of the MariaDB server. Default is `3306`.

### Option: `database_name`

If using an external database, the name of the database to use. Default is `firefly`.

### Option: `database_username`

If using an external database, the username with access to the database.

### Option: `database_password`

The password for the database user. If using internal database and left empty, a random password will be generated.

### Option: `app_key`

The application encryption key. If left empty, a random key will be generated.

### Option: `trusted_proxies`

The IP addresses or ranges that are considered trusted proxies. Default is "**" (all).

## How to use

1. Start the add-on.
2. Wait for the initialization to complete (this may take a few minutes).
3. Open the web UI from the "OPEN WEB UI" button or navigate to `http://your-home-assistant:8080`.
4. Create your Firefly III admin account on first run.
5. Start managing your finances!

## Support

Got questions?

- Join the [Home Assistant Discord](https://discord.gg/home-assistant) and ask in the #add-ons channel.
- [Open an issue on GitHub](your-repository-url/issues).

## License

MIT License
