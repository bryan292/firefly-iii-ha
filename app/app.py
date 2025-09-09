import os
import logging
from flask import Flask, render_template, send_from_directory

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Get port from environment variable or use default
PORT = int(os.environ.get("PORT", 8099))

@app.route('/')
def index():
    """Render the main page."""
    logger.info("Rendering index page")
    return render_template('index.html')

@app.route('/healthz')
def health_check():
    """Health check endpoint."""
    logger.info("Health check requested")
    return "ok", 200

@app.route('/static/<path:path>')
def send_static(path):
    """Serve static files."""
    return send_from_directory('static', path)

if __name__ == '__main__':
    logger.info(f"Starting Flask application on port {PORT}")
    # Setting application root to empty means it will work with any proxy path
    app.run(host='0.0.0.0', port=PORT, application_root='/')
