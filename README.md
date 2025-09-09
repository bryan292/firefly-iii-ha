# Simple Web UI

A minimal Home Assistant add-on that provides a simple web UI via Ingress.

## Installation

### Local Installation

1. On your Home Assistant host, create the folder structure:
   ```
   /addons/local/simple-webui/
   ```

2. Copy all files from this repository to that folder.

3. In Home Assistant, navigate to:
   **Settings** → **Add-ons** → **Add-on Store** → Click the menu in the top right → **Reload**

4. Find "Simple Web UI" under "Local add-ons", click Install.

5. Start the add-on and click **OPEN** to access the UI through Ingress.

## Usage

Once installed, you can:

- Access the web UI directly from Home Assistant's Supervisor panel by clicking the **OPEN** button
- Use the health check endpoint at `/healthz` to verify the app is running

## Troubleshooting

- If the **OPEN** button is disabled, ensure that the add-on is started.
- Check the add-on logs for the message "Starting Flask application on port 8099" to confirm the web server started correctly.
- Remember that Ingress uses a tunneled path - avoid using absolute URLs in your HTML/CSS/JS.
- If you make changes to the add-on files, you'll need to:
  1. Uninstall the add-on
  2. Reload the add-on store
  3. Install the add-on again
  
  Alternatively, use the **Rebuild** option in the add-on page if available.

## Features

- Simple Flask web application
- Accessible via Home Assistant's Ingress
- Health check endpoint at `/healthz`
- Multi-architecture support (amd64, aarch64, armv7)
