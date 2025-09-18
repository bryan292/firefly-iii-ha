## 0.0.13 - 2025-09-18

- docs: clarify release process in README

## 0.0.12 - 2025-09-18

- docs: improve README formatting for project information and release instructions

## 0.0.11 - 2025-09-18

- feat: migrate markdownlint configuration from YAML to JSONC format

## 0.0.10 - 2025-09-18

- feat: replace .markdownlint.yaml with .markdownlint-cli2.yaml for streamlined configuration

## 0.0.9 - 2025-09-18

- feat: add custom markdownlint configuration for repository

## 0.0.8 - 2025-09-18

- feat: add .yamllint configuration for linting rules

## 0.0.7 - 2025-09-18

- fix: improve PHP heredoc syntax for better readability in get_opt function

## 0.0.6 - 2025-09-18

- feat: add hadolint configuration to ignore DL3002 warning

## 0.0.5 - 2025-09-18

- fix: separate hadolint ignore comment for clarity in Dockerfile

## 0.0.4 - 2025-09-18

- fix: add hadolint ignore comment for USER directive in Dockerfile

## 0.0.3 - 2025-09-18

- fix: update ShellCheck action version to 1.1.0 in lint workflow

## 0.0.2 - 2025-09-18

- feat: add linting workflow for Dockerfile, shell scripts, YAML, Markdown, and JSON validation

## 0.0.1 - 2025-09-18

- refactor: streamline version bump process in config.yaml using awk
- feat: enhance auto-release workflow to determine next version and update changelog; improve README and config.yaml timezone options

## 0.0.0 - 2025-09-18

- feat: implement auto-release workflow and remove release-please configuration chore: update README to reflect new release process and clarify project status fix: reset version in config.yaml to 0.0.0 and update repository.yaml for consistency
- Add Dependabot configuration and release automation files; update README for project status and release information
- Bump version to 1.0.48; update Dockerfile to use specific Firefly III core version and refresh changelog for clarity.
- Bump version to 1.0.47; update README for clarity and remove unused app_url option from config.yaml
- Update application name and bump version to 1.0.46; remove unused APP_URL variable from run.sh
- Bump version in config.yaml to 1.0.45 and update icon file
- Add icon file and update version in config.yaml to 1.0.43
- Remove Flask application and related files; bump version in config.yaml to 1.0.43.
- Bump version in config.yaml to 1.0.42; enhance ingress handling in run.sh with upstream scheme and host support.
- Bump version in config.yaml to 1.0.41; update ingress handling in run.sh for improved request processing.
- Bump version in config.yaml to 1.0.40; enhance PHP built-in router script in run.sh for improved ingress handling.
- Bump version in config.yaml to 1.0.39; add PHP built-in router script creation in run.sh for improved routing.
- Bump version in config.yaml to 1.0.38; add healthcheck file creation and symlink in run.sh for readiness probe.
- Bump version in config.yaml to 1.0.37; update error handling in run.sh to log errors on script exit.
- Bump version in config.yaml to 1.0.36; enhance logging in run.sh with fallback mechanisms for log directory and file, and improve healthcheck logging.
- Bump version in config.yaml to 1.0.35; update healthcheck.html to include an additional OK response and extend healthcheck wait time in run.sh to 90 seconds.
- Bump version in config.yaml to 1.0.34; refactor healthcheck logic in run.sh to streamline TCP port readiness and static healthcheck verification.
- Bump version in config.yaml to 1.0.33; update healthcheck logic in run.sh to wait for TCP port readiness before checking static healthcheck.
- Bump version in config.yaml to 1.0.32; update watchdog URL format to use TCP protocol.
- Bump version in config.yaml to 1.0.31; update watchdog URL and extend healthcheck wait time in run.sh.
- Bump version in config.yaml to 1.0.30; update healthcheck.html and enhance run.sh healthcheck logging.
- Bump version in config.yaml to 1.0.29; enhance run.sh with dynamic port handling and improved healthcheck logic.
- Bump version in config.yaml to 1.0.28; add healthcheck wait logic in run.sh.
- Bump version in config.yaml to 1.0.27; update watchdog URL and add healthcheck.html file.
- Bump version in config.yaml to 1.0.26; update watchdog configuration format to string URI.
- Bump version in config.yaml to 1.0.25; update watchdog configuration format.
- Bump version in config.yaml to 1.0.24
- Bump version in config.yaml to 1.0.23; adjust watchdog configuration format.
- Bump version in config.yaml to 1.0.22; standardize watchdog configuration format.
- Bump version in config.yaml to 1.0.21; maintain watchdog configuration format.
- Bump version in config.yaml to 1.0.20; add healthcheck endpoint and ensure PHP built-in server uses index.php as router.
- Bump version in config.yaml to 1.0.19; simplify run.sh to always use PHP built-in server for HTTP serving.
- Bump version in config.yaml to 1.0.18; refactor run.sh for improved web entrypoint detection and fallback to PHP built-in server.
- Bump version in config.yaml to 1.0.17; update README with PHP built-in server fallback for missing upstream entrypoint; enhance run.sh for improved entrypoint detection and execution.
- Bump version in config.yaml to 1.0.16; update Dockerfile to run php-fpm as www-data with environment preservation; enhance run.sh for improved upstream entrypoint logging; add zz-ha-user.conf for php-fpm pool configuration.
- Bump version in config.yaml to 1.0.15; update README with new .env handling details; enhance run.sh for improved .env symlink management and upstream entrypoint detection
- Bump version in config.yaml to 1.0.14; update Dockerfile to run as user 0; enhance run.sh for upstream entrypoint detection and execution
- Bump version in config.yaml to 1.0.13; update README with non-destructive storage handling details and root access changes; enhance run.sh to ensure APP_KEY generation with manual fallback
- Bump version in config.yaml to 1.0.12; update Dockerfile to run as root for write access to /data; enhance run.sh for improved storage handling and .env updates
- Bump version in config.yaml to 1.0.11; update README with non-destructive storage handling details; enhance run.sh for safe .env updates and improved permissions management
- Bump version in config.yaml to 1.0.10; update README with storage handling changes and Nginx configuration; enhance run.sh for non-destructive storage management
- Bump version in config.yaml to 1.0.9; update Dockerfile to clarify bootstrap script permissions; refactor run.sh for improved option handling and database migration retries
- Bump version in config.yaml to 1.0.8; update Dockerfile to copy bootstrap script with executable permissions
- Bump version in config.yaml to 1.0.7; update Dockerfile to use latest core image; enhance README with database configuration details; improve run.sh for better database connection handling and SQLite support
- Bump version in config.yaml to 1.0.6; update README with database requirements and enhance setup script for improved database connection handling
- Bump version in config.yaml from 1.0.3 to 1.0.4; enhance run.sh with APP_KEY generation and improved error handling
- Bump version in config.yaml from 1.0.2 to 1.0.3; simplify storage handling in run.sh
- Bump version in config.yaml from 1.0.1 to 1.0.2; enhance run.sh with additional logging and error handling
- Update image references in .addons.yaml and Dockerfile; remove image from config.yaml
- Update image reference in config.yaml to remove the latest tag
- Bump version in config.yaml from 1.0.0 to 1.0.1
- Update image reference in config.yaml to use the latest tag
- Reduce timeout value in config.yaml from 600 to 300 seconds
- Update image reference in config.yaml to use GitHub Container Registry
- Update .gitignore, Dockerfile to install jq, and add repository.json for project metadata
- Add .addons.yaml for Firefly III add-on configuration and update config.yaml with multi-arch support
- Update repository.yaml URL to point to the correct GitHub repository
- Refactor Firefly III add-on: update changelog, README, config, and Dockerfile; enhance run script for better initialization and configuration handling
- Update Dockerfile and run.sh shebang; bump version in config.yaml to 0.1.1
- Refactor Dockerfile, update app.py to remove application root setting, and modify config.yaml URL; add repository.yaml for project metadata
- Refactor Dockerfile and run script; update app.py to support proxy paths and enhance config.yaml with additional metadata
- Add initial implementation of Simple Web UI with Flask
- Add initial project files including Dockerfile, LICENSE, README, app code, requirements, styles, HTML template, config, and run script
- restart
- Enhance environment variable handling in bootstrap scripts; create separate source files for app and cron services
- Bump version to 0.2.7 in config.yaml; clean up run.sh by removing redundant healthcheck endpoint creation
- test
- Bump version to 0.2.5 in config.yaml; enhance 00-bootstrap.sh and run.sh for improved Home Assistant Ingress compatibility and session management
- test
- Bump version to 0.2.3 in config.yaml; enhance 00-bootstrap.sh and run.sh for improved environment variable handling and database initialization
- Bump version to 0.2.2 in config.yaml; enhance 00-bootstrap.sh to include additional environment variables and improve database initialization process
- Bump version to 0.2.1 in config.yaml; enhance run.sh and 00-bootstrap.sh for persistent environment variable handling
- Update environment variables in Dockerfile, bump version to 0.2.0 in config.yaml, and enhance run.sh with signal handling and user account check
- Bump version to 0.1.14 in config.yaml; update db_password to 'password' and enhance run.sh with new environment variables for improved Home Assistant integration and session handling
- Update README and configuration: enhance documentation, bump version to 0.1.13, and improve run.sh output messages
- Refactor Dockerfile and run.sh: remove PHP-FPM installation, update database credentials, and add database connection wait logic; bump version to 0.1.12 in config.yaml
- Remove PHP-FPM installation and configuration from Dockerfile and run.sh; bump version to 0.1.11 in config.yaml
- Update PHP version in Dockerfile to php8.2-fpm; bump version to 0.1.10 in config.yaml
- Add Nginx and PHP-FPM support; create minimal Nginx configuration in run.sh; bump version to 0.1.9 in config.yaml
- Enhance storage directory setup and permissions in Dockerfile; update run.sh for environment variable exports and improved PHP server handling; bump version to 0.1.8 in config.yaml
- Update storage permissions and enhance application startup process; bump version to 0.1.7 in config.yaml
- Update PHP-FPM configuration to set user and group to www-data; bump version to 0.1.6 in config.yaml
- Update Dockerfile and run.sh for improved APP_KEY generation; bump version to 0.1.5 in config.yaml
- Bump version to 0.1.4 in config.yaml; update Dockerfile and run.sh for APP_KEY generation
- Update version to 0.1.3 in config.yaml; refine Dockerfile and add run.sh script
- Update version number to 0.1.2 in config.yaml
- Add Dockerfile and build configuration; remove build_from from config.yaml
- Update version number to 0.1.1 and modify build configuration in config.yaml
- Update version number to 0.1.0 and enable hassio_api in config.yaml
- Fix version number in config.yaml from 0.1.0 to 0.0.1
- Add initial Dockerfile, bootstrap script, and cron setup for Firefly III integration
- Add repository.json for Firefly III Home Assistant add-on metadata
- Update README.md to reorganize features section and add repository.yaml for add-on metadata
- Refactor Dockerfile to improve directory structure setup and permissions
- Update Dockerfile to use official fireflyiii/core image
- Update CI workflow and Dockerfile to use official Firefly III image and improve process management
- Update Docker image references to use the official fireflyiii/core image
- Remove QEMU and Docker Buildx setup from CI workflow; update architecture in config.yaml to only include amd64
- Update Docker image references to use the official jc5x/firefly-iii image
- Update Docker image references to use the official Firefly III image
- Update CI workflow to build for amd64 platform and adjust Dockerfile dependencies
- Fix CI workflow branch references from 'main' to 'master'
- Add initial project files including CI configuration, Docker setup, and scripts
- Bump version to 0.0.21 [skip ci]
- restart
- Bump version to 0.0.20 [skip ci]
- Fix Laravel 'auth' provider error by ensuring config file exists and reinstalling auth scaffolding
- Bump version to 0.0.19 [skip ci]
- Fix Laravel 'auth' provider error by publishing vendor and caching config
- Bump version to 0.0.18 [skip ci]
- Enhance NGINX directory management by adding symlink creation for logs and temp directories, with fallback to config patching if symlinks fail
- Bump version to 0.0.17 [skip ci]
- Enhance NGINX directory management by removing non-writable log and temp directories, and creating symlinks to writable locations or updating NGINX config if symlinks fail
- Bump version to 0.0.16 [skip ci]
- Enhance NGINX directory management by removing non-writable logs and temp directories, and creating symlinks to writable locations
- Bump version to 0.0.15 [skip ci]
- Enhance NGINX configuration patching to update all references to log and temp directories
- Bump version to 0.0.14 [skip ci]
- Refactor nginx log and temp directory creation to ensure they are always created and writable
- Bump version to 0.0.13 [skip ci]
- Ensure nginx log and temp directories are created with warnings on failure
- Bump version to 0.0.12 [skip ci]
- Ensure nginx log and temp directories are created only if writable
- Bump version to 0.0.11 [skip ci]
- Ensure nginx log and temp directories exist and are writable
- Bump version to 0.0.10 [skip ci]
- Remove redundant .initialized file creation and clean up existing file
- Bump version to 0.0.9 [skip ci]
- Update initialization script to create .initialized file in the data directory with error logging
- Bump version to 0.0.8 [skip ci]
- Remove hardcoded environment variables from .env file generation in initialization script
- Bump version to 0.0.7 [skip ci]
- Enhance .env file handling and set appropriate file permissions for storage and cache directories
- Bump version to 0.0.6 [skip ci]
- Improve file permission handling in initialization script
- Bump version to 0.0.5 [skip ci]
- Refactor storage and cache directory setup for clarity and maintainability
- Bump version to 0.0.4 [skip ci]
- Add initial files: changelog, documentation, AppArmor profile, and icons
- Bump version to 0.0.3 [skip ci]
- Ensure storage and cache directories exist and set appropriate permissions
- Bump version to 0.0.2 [skip ci]
- d
- Bump version to 0.0.1 [skip ci]
- Set version in config.yaml back to 0.0.0 and configure Git user for version bump step
- Update version in config.yaml to 1.0.0 and comment out release steps in workflow
- Enhance Nginx configuration with security headers and caching directives
- Bump version to 1.0.16 [skip ci]
- Update admin_email schema type from "email?" to "str?"
- Bump version to 1.0.15 [skip ci]
- Remove default admin email value and update schema to indicate optional email
- Bump version to 1.0.14 [skip ci]
- Ensure admin user creation only occurs if admin_email is provided
- Bump version to 1.0.13 [skip ci]
- Add logic to create admin user using built-in command or manual method
- Bump version to 1.0.12 [skip ci]
- Add logic to create admin user if none exist in the database
- Bump version to 1.0.11 [skip ci]
- Remove mariadb-client from Dockerfile and update user creation command in 40-firefly.sh
- Bump version to 1.0.10 [skip ci]
- Add mysql-client and update database creation logic in 40-firefly.sh
- Bump version to 1.0.9 [skip ci]
- Refactor Dockerfile to remove openssl installation and update app key generation method in 40-firefly.sh
- Bump version to 1.0.8 [skip ci]
- Add openssl installation to Dockerfile for dependency management
- Bump version to 1.0.7 [skip ci]
- test
- Bump version to 1.0.6 [skip ci]
- test
- Bump version to 1.0.5 [skip ci]
- test
- Bump version to 1.0.4 [skip ci]
- test
- Bump version to 1.0.3 [skip ci]
- test
- Bump version to 1.0.2 [skip ci]
- test
- Bump version to 1.0.2 [skip ci]
- test
- Bump version to 1.0.1 [skip ci]
- test
- test
- test
- test
- test
- test
- test
- test
- test
- test
- test
- restart
- Add Firefly III Home Assistant add-on with initial configuration and setup scripts
- Add initial files for Firefly III Home Assistant add-on

# Changelog

## 1.0.47
- Added bundled icon/logo so the add-on displays artwork in the Home Assistant store.
- Removed the unused `app_url` option from the configuration schema and startup script.
- Refreshed the README with clearer setup guidance and configuration details.

## 1.0.0
- Initial Firefly III add-on with Ingress, persistent `/data`, and DB migrations.
- Uses official Firefly III Docker image with Home Assistant integration.
- Connection to external MySQL/MariaDB database.
- Persistent storage for application data.
