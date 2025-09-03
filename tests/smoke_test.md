# Smoke Test for Firefly III Add-on

This document outlines a basic smoke test to verify that the Firefly III add-on is working correctly.

## Prerequisites

- Docker and Docker Compose installed
- Make installed

## Test Steps

1. **Build and start the containers**

   ```bash
   make build
   make run-local
   ```

2. **Wait for startup**

   ```bash
   make logs
   ```

   Look for messages indicating successful database migration and server startup.
   
   You should see something like:
   ```
   firefly | Running database migrations...
   firefly | Migration table created successfully.
   ...
   firefly | Starting Firefly III application...
   ```

3. **Verify web UI**

   Open a browser and go to http://localhost:8080

   You should see the Firefly III login page.

4. **Register a new user**

   Click on "Register a new account" and follow the process to create a test user.
   
   If registration works, you know the database is properly configured.

5. **Verify cron**

   Check the logs to see if the cron service started:
   
   ```bash
   make logs | grep cron
   ```
   
   You should see:
   ```
   firefly | Setting up Firefly III cron jobs...
   firefly | Starting cron service...
   ```

6. **Clean up**

   When you're done testing:
   
   ```bash
   make clean
   ```

## Troubleshooting

If you encounter any issues:

1. **Database connection errors**
   - Check if MariaDB container is running: `docker ps`
   - Verify environment variables in docker-compose.dev.yml

2. **Permission errors**
   - Check the logs for permission-related messages
   - The bootstrap script should be setting proper permissions

3. **HTTP errors or blank pages**
   - Check for PHP errors in the logs
   - Verify APP_KEY is being generated correctly
