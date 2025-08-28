#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Firefly III
# Configures Firefly III
# ==============================================================================
declare admin_email
declare db_host
declare db_port
declare db_name
declare db_user
declare db_password
declare timezone
declare log_level
declare wait_timeout
declare app_key
declare app_url

# Make sure persistent data directory exists
mkdir -p /data/firefly-iii
mkdir -p /data/nginx/logs

# Get config
admin_email=$(bashio::config 'admin_email')
db_host=$(bashio::config 'database.host')
db_port=$(bashio::config 'database.port')
db_name=$(bashio::config 'database.database')
db_user=$(bashio::config 'database.username')
db_password=$(bashio::config 'database.password')
timezone=$(bashio::config 'timezone')
log_level=$(bashio::config 'log_level')

# Wait for database to be available
bashio::log.info "Waiting for database ${db_host}:${db_port} to be available..."
wait_timeout=30
while ! nc -z "${db_host}" "${db_port}" > /dev/null 2>&1; do
    wait_timeout=$((wait_timeout - 1))
    if [[ ${wait_timeout} -eq 0 ]]; then
        bashio::log.error "Database ${db_host}:${db_port} not available, timeout."
        exit 1
    fi
    sleep 1
done

# Generate a valid Laravel app key (32 bytes base64 encoded) without using openssl
if [ ! -f /data/firefly-iii/app_key ]; then
    app_key="base64:$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr -d '\n')"
    echo "${app_key}" > /data/firefly-iii/app_key
else
    app_key=$(cat /data/firefly-iii/app_key)
fi

# For Home Assistant integration, we need the proper URLs
# Detect ingress URL and use that as the base
ingress_entry=$(bashio::addon.ingress_entry)
app_url=$(bashio::addon.ingress_url)

# Log information about the URLs
bashio::log.info "Using app URL: ${app_url}"
bashio::log.info "Ingress entry: ${ingress_entry}"

# Remove index.html if exists (it would take precedence over index.php)
if [ -f /var/www/html/public/index.html ]; then
    rm -f /var/www/html/public/index.html
fi

# Create needed directories with proper permissions
mkdir -p /var/www/html/storage/logs
chmod -R 777 /var/www/html/storage/logs
touch /var/www/html/storage/logs/laravel.log
chmod 666 /var/www/html/storage/logs/laravel.log

# Setup environment file
cat > /var/www/html/.env << EOF
APP_ENV=local
APP_DEBUG=true
APP_KEY=${app_key}
APP_URL=http://localhost
APP_LOG_LEVEL=${log_level}
APP_TIMEZONE=${timezone}

# Used for the trusted proxies package
TRUSTED_PROXIES=**

# Database settings
DB_CONNECTION=mysql
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_DATABASE=${db_name}
DB_USERNAME=${db_user}
DB_PASSWORD=${db_password}

# Cache, session and queue settings
CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_DRIVER=sync

# Mail settings
MAIL_DRIVER=log
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_FROM=changeme@example.com
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null

# Home Assistant specific settings
TZ=${timezone}
FORCE_HTTPS=false
FORCE_SINGLE_USER_MODE=true
APP_NAME="Firefly III on Home Assistant"
SITE_OWNER=${admin_email}
ASSET_URL=

# Logging to file settings
LOG_CHANNEL=stack
LOG_LEVEL=debug

# Additional settings for Firefly III
FIREFLY_III_LAYOUT=v2
EXPECT_SECURE_URL=false
DB_USE_UTF8MB4=true
ADLDAP_CONNECTION=default
TRACKER_SITE_ID=1
DISABLE_FRAME_HEADER=true
CACHE_PREFIX=firefly
SEND_REGISTRATION_MAIL=false
SEND_ERROR_MESSAGE=true
ENABLE_EXTERNAL_MAP=false
MAPBOX_API_KEY=
MAP_DEFAULT_LAT=51.983333
MAP_DEFAULT_LONG=5.916667
MAP_DEFAULT_ZOOM=6

# Prevent redirect loops
TRUSTED_PROXIES=**
SANCTUM_STATEFUL_DOMAINS=*
SESSION_DOMAIN=*
FORCE_ROOT_URL=
DISABLE_AUTHENTICATE_GUARD=true
SINGLE_USER_MODE=true

# Authentication settings
AUTHENTICATION_GUARD=web
AUTHENTICATION_GUARD_HEADER=REMOTE_USER

# Custom for ingress
URL_FORCE_HTTPS=false
HOME_ASSISTANT_INGRESS=true
DISABLE_GLOBAL_REDIRECTS=true
EOF

cd /var/www/html || exit

# Create a simple login/register controller to directly handle these routes
mkdir -p /var/www/html/app/Http/Controllers
cat > /var/www/html/app/Http/Controllers/IngressController.php << EOF
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class IngressController extends Controller
{
    public function login()
    {
        if (Auth::check()) {
            return redirect('/');
        }
        
        return view('auth.login');
    }
    
    public function register()
    {
        if (Auth::check()) {
            return redirect('/');
        }
        
        return view('auth.register');
    }
}
EOF

# Create a custom route to handle login and registration directly
mkdir -p /var/www/html/routes
cat > /var/www/html/routes/ingress.php << EOF
<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\IngressController;

Route::get('/login', [IngressController::class, 'login']);
Route::get('/register', [IngressController::class, 'register']);

// Add a fallback route to catch all URLs and redirect to home
Route::fallback(function () {
    return redirect('/');
});
EOF

# Create middleware to fix redirects
mkdir -p /var/www/html/app/Http/Middleware
cat > /var/www/html/app/Http/Middleware/IngressMiddleware.php << EOF
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Facades\Redirect;

class IngressMiddleware
{
    public function handle(Request \$request, Closure \$next)
    {
        // Disable Laravel redirects to external URLs
        Redirect::macro('away', function (\$path, \$status = 302, \$headers = []) {
            return redirect()->to(\$path, \$status, \$headers);
        });
        
        // Handle the response
        \$response = \$next(\$request);
        
        // If it's a redirect to an external URL, modify it to redirect internally
        if (\$response->isRedirection()) {
            \$location = \$response->headers->get('Location');
            
            // Check if it's an external URL that should be made internal
            if (strpos(\$location, 'http://192.168.68.61:8080') === 0) {
                \$internalPath = str_replace('http://192.168.68.61:8080', '', \$location);
                return redirect(\$internalPath);
            }
        }
        
        return \$response;
    }
}
EOF

# Fix the Kernel.php modification script to avoid undefined variable warning
cat > /tmp/append_kernel.php << EOF
<?php
\$file = '/var/www/html/app/Http/Kernel.php';
\$content = file_get_contents(\$file);

// Directly modify the Kernel.php file to register our middleware
// Add the use statement first
\$content = str_replace('namespace App\\\\Http;', "namespace App\\\\Http;\n\nuse App\\\\Http\\\\Middleware\\\\IngressMiddleware;", \$content);

// Create a backup of the original file
file_put_contents(\$file . '.bak', \$content);

// Simple string replacement for the web middleware array
\$pattern = "/'web' => \\[/";
\$replacement = "'web' => [\n        \\\\IngressMiddleware::class,";

// Perform the replacement
\$modified = preg_replace(\$pattern, \$replacement, \$content);

// Check if replacement was successful
if (\$modified !== \$content) {
    file_put_contents(\$file, \$modified);
    echo "Successfully added middleware to Kernel.php\n";
} else {
    echo "Could not find the web middleware group in Kernel.php\n";
    
    // Fallback: Insert the middleware in a different way
    // Find protected $middleware = [
    \$pattern = "/protected \\\$middleware = \\[/";
    if (preg_match(\$pattern, \$content, \$matches)) {
        \$replacement = \$matches[0] . "\n        \\\\IngressMiddleware::class,";
        \$modified = preg_replace(\$pattern, \$replacement, \$content);
        file_put_contents(\$file, \$modified);
        echo "Added middleware to global middleware array instead\n";
    }
}
EOF

php /tmp/append_kernel.php

# Fix the route service provider update to not use $this in static context
cat > /tmp/update_routes_provider.php << EOF
<?php
\$file = '/var/www/html/app/Providers/RouteServiceProvider.php';
if (!file_exists(\$file)) {
    echo "RouteServiceProvider.php file not found\n";
    exit(0);
}

\$content = file_get_contents(\$file);

// Create a backup of the original file
file_put_contents(\$file . '.bak', \$content);

// Find the boot method and add the route loading statement after its opening brace
\$pattern = '/function boot\\(\\)\\s*{/';
if (preg_match(\$pattern, \$content, \$matches)) {
    \$replacement = \$matches[0] . "\n        \\\$this->loadRoutesFrom(base_path('routes/ingress.php'));";
    \$modified = preg_replace(\$pattern, \$replacement, \$content, 1);
    
    // Write the modified content back to the file
    file_put_contents(\$file, \$modified);
    echo "Routes added to RouteServiceProvider.php\n";
} else {
    echo "Could not find the boot method in RouteServiceProvider.php\n";
    
    // Try to find the __construct method as an alternative
    \$pattern = '/function __construct\\(\\)\\s*{/';
    if (preg_match(\$pattern, \$content, \$matches)) {
        \$replacement = \$matches[0] . "\n        \\\$this->loadRoutesFrom(base_path('routes/ingress.php'));";
        \$modified = preg_replace(\$pattern, \$replacement, \$content, 1);
        
        // Write the modified content back to the file
        file_put_contents(\$file, \$modified);
        echo "Routes added to RouteServiceProvider constructor instead\n";
    } else {
        // Create a direct routes file that will be loaded automatically
        echo "Creating a direct routes file\n";
        file_put_contents('/var/www/html/routes/web.php', file_get_contents('/var/www/html/routes/ingress.php'), FILE_APPEND);
    }
}
EOF

php /tmp/update_routes_provider.php

# Create a file to modify the RedirectIfAuthenticated middleware
cat > /tmp/fix_redirects.php << EOF
<?php
\$file = '/var/www/html/app/Http/Middleware/RedirectIfAuthenticated.php';
if (file_exists(\$file)) {
    \$content = file_get_contents(\$file);
    
    # Initialize pattern variable
    \$pattern = '';
    \$modified = '';
    
    # Find the handle method and modify the redirect
    \$pattern = '/return redirect\\(RouteServiceProvider::HOME\\);/';
    \$replacement = 'return redirect("/");';
    
    if (preg_match(\$pattern, \$content)) {
        \$modified = preg_replace(\$pattern, \$replacement, \$content);
        file_put_contents(\$file, \$modified);
        echo "Fixed RedirectIfAuthenticated middleware\n";
    }
}
EOF

php /tmp/fix_redirects.php

# Attempt to create database if it doesn't exist yet
bashio::log.info "Ensuring database exists..."
# Try using mysql client instead of mariadb-client which seems to be missing
if command -v mysql >/dev/null 2>&1; then
    mysql -h "${db_host}" -P "${db_port}" -u "${db_user}" -p"${db_password}" -e "CREATE DATABASE IF NOT EXISTS ${db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || bashio::log.warning "Failed to create database, it might already exist"
elif command -v mariadb >/dev/null 2>&1; then
    mariadb -h "${db_host}" -P "${db_port}" -u "${db_user}" -p"${db_password}" -e "CREATE DATABASE IF NOT EXISTS ${db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || bashio::log.warning "Failed to create database, it might already exist"
else
    bashio::log.warning "No MySQL/MariaDB client found, skipping database creation"
fi

# Create and set permissions for storage directories before Laravel commands
bashio::log.info "Setting up storage directories..."
mkdir -p /var/www/html/storage/app/public
mkdir -p /var/www/html/storage/framework/cache
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/bootstrap/cache

# Apply permissions to all storage directories
chmod -R 777 /var/www/html/storage
chmod -R 777 /var/www/html/bootstrap/cache
chown -R nginx:nginx /var/www/html/storage
chown -R nginx:nginx /var/www/html/bootstrap/cache

# Cache configurations
bashio::log.info "Setting up Laravel application..."
php artisan config:clear
php artisan cache:clear
php artisan view:clear

# Generate storage link
bashio::log.info "Creating storage link..."
php artisan storage:link || true

# Run migrations
bashio::log.info "Running database migrations..."
php artisan migrate --no-interaction --force

# Run optimize
bashio::log.info "Optimizing application..."
php artisan optimize

# Only try to create admin user if admin_email is provided
if [[ -n "${admin_email}" ]]; then
    # Try to create admin user if it doesn't exist
    bashio::log.info "Ensuring admin user exists..."

    # Check if any users exist in the database
    USER_COUNT=$(mysql -h "${db_host}" -P "${db_port}" -u "${db_user}" -p"${db_password}" -e "SELECT COUNT(*) FROM ${db_name}.users;" 2>/dev/null | tail -n 1)
    
    if [ "$USER_COUNT" = "0" ] || [ -z "$USER_COUNT" ]; then
        # See if there's a command for creating the first user
        if php artisan list | grep -q "firefly-iii:create-first-user"; then
            # Use the official command if available
            bashio::log.info "Using built-in command to create first user..."
            php artisan firefly-iii:create-first-user "${admin_email}" --no-interaction || true
        else
            # Manual user creation as fallback
            bashio::log.info "Using manual method to create first user..."
            
            # Create SQL query file
            cat > /tmp/create_user.sql << EOSQL
USE ${db_name};
INSERT INTO users (email, password, role, blocked, created_at, updated_at) 
VALUES ('${admin_email}', '\$2y\$10\$Tje3t.qWN8iwDkbYaTGC0uw8Cb65kbDKQNTpUxE2DMdXY0fYS/JPe', 'owner', 0, NOW(), NOW());
EOSQL

            # Execute the SQL file
            mysql -h "${db_host}" -P "${db_port}" -u "${db_user}" -p"${db_password}" < /tmp/create_user.sql
            
            if [ $? -eq 0 ]; then
                bashio::log.info "Admin user created successfully with email: ${admin_email} and password: welcome"
            else
                bashio::log.warning "Failed to create admin user. You may need to create one manually."
            fi
            
            # Clean up
            rm -f /tmp/create_user.sql
        fi
    else
        bashio::log.info "Users already exist in database, skipping user creation."
    fi
else
    bashio::log.info "No admin email provided, skipping user creation."
fi

# Double-check permissions after all operations
bashio::log.info "Finalizing file permissions..."
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Ensure critical directories have the right permissions
chmod -R 777 /var/www/html/storage
chmod -R 777 /var/www/html/bootstrap/cache

# Create touch files for logs to ensure they exist with proper permissions
touch /var/www/html/storage/logs/laravel.log
touch /var/www/html/storage/logs/ff3-cli-$(date +'%Y-%m-%d').log
chmod 666 /var/www/html/storage/logs/*.log

# Set up Nginx logs
mkdir -p /data/nginx/logs
touch /data/nginx/logs/error.log
touch /data/nginx/logs/access.log
chmod 644 /data/nginx/logs/*.log
chown -R nginx:nginx /data/nginx

# Set proper ownership for the entire application
chown -R nginx:nginx /var/www/html

# Create a file to indicate successful initialization
touch /var/www/html/.initialized

# Create a simple standalone HTML file to verify the web server is working
cat > /var/www/html/public/hello.html << EOT
<!DOCTYPE html>
<html>
<head>
    <title>Firefly III Test Page</title>
</head>
<body>
    <h1>Hello from Firefly III</h1>
    <p>If you can see this page, the Nginx web server is working correctly.</p>
    <p>Now try the <a href="info.php">PHP info page</a> or <a href="test.php">test PHP page</a>.</p>
</body>
</html>
EOT
chmod 644 /var/www/html/public/hello.html

# Create PHP test files for debugging
cat > /var/www/html/public/info.php << EOT
<?php
phpinfo();
EOT
chmod 644 /var/www/html/public/info.php

cat > /var/www/html/public/test.php << EOT
<?php
echo '<h1>PHP Test Page</h1>';
echo '<p>If you can see this, PHP is working correctly with Nginx.</p>';
echo '<p>Server time: ' . date('Y-m-d H:i:s') . '</p>';
echo '<pre>';
echo 'Document Root: ' . \$_SERVER['DOCUMENT_ROOT'] . "\n";
echo 'Request URI: ' . \$_SERVER['REQUEST_URI'] . "\n";
echo 'PHP Version: ' . phpversion() . "\n";
echo '</pre>';
EOT
chmod 644 /var/www/html/public/test.php

# Show some debug information
bashio::log.info "Firefly III setup complete. App URL: ${app_url}"
