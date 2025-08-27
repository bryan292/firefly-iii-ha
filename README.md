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

