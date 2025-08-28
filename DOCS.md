# Home Assistant Add-on: Firefly III

Firefly III is a free and open-source personal finance manager that helps you track your expenses, income, budgets, and more.

## Installation

Follow these steps to get the add-on installed on your system:

1. Navigate in your Home Assistant frontend to **Settings** -> **Add-ons** -> **Add-on Store**.
2. Find the "Firefly III" add-on and click it.
3. Click on the "INSTALL" button.

## How to use

The add-on requires a MariaDB database to store its data. Make sure you have the MariaDB add-on installed and properly set up.

1. Install the MariaDB add-on if you haven't already done so.
2. Create a database for Firefly III in MariaDB (e.g., "firefly").
3. In the configuration of the add-on, fill in the database details.
4. Start the add-on.
5. Check the logs to see if everything is working correctly.
6. Open the web UI and start using Firefly III.

## Configuration

Example add-on configuration:

```yaml
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

The email address of the admin user. This will be used to create the first user in Firefly III.

### Option: `log_level`

The log level for Firefly III and the add-on. Possible values are: `trace`, `debug`, `info`, `notice`, `warning`, `error`, `fatal`.

## Default Login

If an admin email is provided during setup, a user with the following credentials will be created:

- Email: The email provided in the config
- Password: `welcome`

Please change this password immediately after logging in!

## Support

Got questions?

You have several options to get them answered:

- The Home Assistant [Community Forum](https://community.home-assistant.io/).
- Join the [Discord chat server](https://discord.gg/c5DvZ4e).
- The [Firefly III documentation](https://docs.firefly-iii.org/).

In case you've found a bug, please [open an issue on our GitHub](https://github.com/bryan292/firefly-iii-ha/issues).

## License

MIT License

Copyright (c) 2023-2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
