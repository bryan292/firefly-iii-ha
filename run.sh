#!/usr/bin/env sh
set -eu

APP_DIR="${APP_DIR:-/var/www/html}"
HA_DATA_DIR="${HA_DATA_DIR:-/data/firefly}"
PORT="${PORT:-8080}"
OPTIONS_FILE="/data/options.json"

LOG_LEVEL="${LOG_LEVEL:-info}"
DEFAULT_LOG_DIR="${HA_DATA_DIR}/logs"
LOG_DIR="${HA_LOG_DIR:-$DEFAULT_LOG_DIR}"
LOG_INIT_MESSAGES=""

if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
  FALLBACK_LOG_DIR="/tmp/firefly-logs"
  if mkdir -p "$FALLBACK_LOG_DIR" 2>/dev/null; then
    LOG_INIT_MESSAGES="Requested log directory '$LOG_DIR' unavailable; using '$FALLBACK_LOG_DIR' instead."
    LOG_DIR="$FALLBACK_LOG_DIR"
  else
    LOG_INIT_MESSAGES="Unable to create requested log directory '$LOG_DIR'; using current directory for logging."
    LOG_DIR="."
  fi
fi

DEFAULT_LOG_FILE="$LOG_DIR/startup.log"
LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"
if [ -n "$LOG_FILE" ] && ! touch "$LOG_FILE" 2>/dev/null; then
  FALLBACK_LOG_FILE="$LOG_DIR/startup.log"
  if [ "$LOG_FILE" != "$FALLBACK_LOG_FILE" ] && touch "$FALLBACK_LOG_FILE" 2>/dev/null; then
    if [ -n "$LOG_INIT_MESSAGES" ]; then
      LOG_INIT_MESSAGES="$LOG_INIT_MESSAGES Using fallback log file '$FALLBACK_LOG_FILE'."
    else
      LOG_INIT_MESSAGES="Using fallback log file '$FALLBACK_LOG_FILE'."
    fi
    LOG_FILE="$FALLBACK_LOG_FILE"
  elif touch /tmp/firefly-startup.log 2>/dev/null; then
    if [ -n "$LOG_INIT_MESSAGES" ]; then
      LOG_INIT_MESSAGES="$LOG_INIT_MESSAGES Using fallback log file '/tmp/firefly-startup.log'."
    else
      LOG_INIT_MESSAGES="Using fallback log file '/tmp/firefly-startup.log'."
    fi
    LOG_FILE="/tmp/firefly-startup.log"
  else
    if [ -n "$LOG_INIT_MESSAGES" ]; then
      LOG_INIT_MESSAGES="$LOG_INIT_MESSAGES Unable to create a writable log file; logging to stdout only."
    else
      LOG_INIT_MESSAGES="Unable to create a writable log file; logging to stdout only."
    fi
    LOG_FILE=""
  fi
fi

log_level_to_num() {
  case "$1" in
    error) echo 0 ;;
    warn) echo 1 ;;
    info) echo 2 ;;
    debug) echo 3 ;;
    trace) echo 4 ;;
    *) echo 2 ;;
  esac
}

log_should_emit() {
  level="$1"
  level_num="$(log_level_to_num "$level")"
  current_num="$(log_level_to_num "$LOG_LEVEL")"
  [ "$level_num" -le "$current_num" ]
}

log_write() {
  line="$1"
  printf '%s\n' "$line"
  if [ -n "${LOG_FILE:-}" ]; then
    printf '%s\n' "$line" >>"$LOG_FILE" 2>/dev/null || :
  fi
}

log() {
  level="$1"
  shift || true
  message="$*"
  if ! log_should_emit "$level"; then
    return 0
  fi
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  log_write "$timestamp [$level] $message"
}

log_error() { log error "$@"; }
log_warn() { log warn "$@"; }
log_info() { log info "$@"; }
log_debug() { log debug "$@"; }
log_trace() { log trace "$@"; }

mask_value() {
  key="$1"
  value="$2"
  case "$key" in
    *PASSWORD*|*SECRET*|APP_KEY|ENCRYPTION_KEY|PASSPORT_PRIVATE_KEY|PASSPORT_PUBLIC_KEY)
      printf '<redacted>'
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

trap 'rc=$?; if [ "$rc" -ne 0 ]; then log_error "Startup script aborted unexpectedly (exit $rc)"; fi' EXIT

log_info "Starting Firefly III Home Assistant startup script (PID $$)"
log_info "Logging level set to '$LOG_LEVEL'"
if [ -n "$LOG_FILE" ]; then
  log_info "Writing detailed logs to '$LOG_FILE'"
else
  log_warn "No log file configured; output available on stdout only."
fi
if [ -n "$LOG_INIT_MESSAGES" ]; then
  log_warn "$LOG_INIT_MESSAGES"
fi

if [ -f "$OPTIONS_FILE" ]; then
  log_info "Loading add-on options from '$OPTIONS_FILE'"
else
  log_warn "Options file '$OPTIONS_FILE' not found; using default values."
fi

# Read key from options.json using PHP (base image has PHP)
get_opt() {
  key="$1"; default="$2"
  if [ -f "$OPTIONS_FILE" ]; then
    val=$(php -r "
      \$f = getenv('OPTIONS_FILE') ?: '/data/options.json';
      if (!file_exists(\$f)) { exit; }
      \$o = json_decode(file_get_contents(\$f), true);
      \$k = \$argv[1];
      if (is_array(\$o) && array_key_exists(\$k, \$o) && \$o[\$k] !== '' && \$o[\$k] !== null) { echo \$o[\$k]; }
    " "$key" 2>/dev/null || true)
    if [ -n "${val:-}" ]; then
      printf "%s" "$val"
      return
    fi
  fi
  printf "%s" "$default"
}

DB_HOST="$(get_opt db_host core-mariadb)"
DB_PORT="$(get_opt db_port 3306)"
DB_NAME="$(get_opt db_name firefly)"
DB_USER="$(get_opt db_user firefly)"
DB_PASSWORD="$(get_opt db_password "")"
TIMEZONE="$(get_opt timezone UTC)"
SITE_OWNER="$(get_opt site_owner owner@example.com)"
GENERATE_APP_KEY="$(get_opt generate_app_key true)"

log_info "Database configuration: host=$DB_HOST port=$DB_PORT database=$DB_NAME user=$DB_USER password_set=$( [ -n "$DB_PASSWORD" ] && printf 'yes' || printf 'no' )"
log_info "Timezone set to '$TIMEZONE'"
log_info "Site owner email set to '$SITE_OWNER'"
log_info "APP_KEY auto-generation enabled: $GENERATE_APP_KEY"

mkdir -p "$HA_DATA_DIR"
log_info "Using Home Assistant data directory '$HA_DATA_DIR'"
ENV_FILE="$HA_DATA_DIR/.env"
STORAGE_DIR="$HA_DATA_DIR/storage"
APP_ENV_FILE="$APP_DIR/.env"

mkdir -p "$STORAGE_DIR"
log_info "Ensuring persistent storage directory at '$STORAGE_DIR'"

cd "$APP_DIR"
log_info "Working directory set to '$APP_DIR'"

# Ensure static healthcheck file exists for readiness probe
HEALTHCHECK_FILE="$APP_DIR/public/healthcheck.html"
if [ ! -f "$HEALTHCHECK_FILE" ]; then
  log_warn "Healthcheck file '$HEALTHCHECK_FILE' missing; creating default placeholder."
  if cat <<'EOHC' >"$HEALTHCHECK_FILE" 2>/dev/null; then
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Firefly III Add-on Healthcheck</title>
  </head>
  <body>
    <p>OK</p>
  </body>
</html>
EOHC
    log_info "Created default healthcheck file at '$HEALTHCHECK_FILE'."
  else
    log_error "Failed to write healthcheck file at '$HEALTHCHECK_FILE'."
  fi
else
  log_debug "Healthcheck file present at '$HEALTHCHECK_FILE'."
fi

ALT_HEALTHCHECK_FILE="$APP_DIR/public/healthcheck"
if [ ! -e "$ALT_HEALTHCHECK_FILE" ]; then
  if ln -s "$(basename "$HEALTHCHECK_FILE")" "$ALT_HEALTHCHECK_FILE" 2>/dev/null; then
    log_info "Created symlink '$ALT_HEALTHCHECK_FILE' → $(basename "$HEALTHCHECK_FILE") for compatibility."
  elif cp "$HEALTHCHECK_FILE" "$ALT_HEALTHCHECK_FILE" 2>/dev/null; then
    log_info "Copied healthcheck file to '$ALT_HEALTHCHECK_FILE' for compatibility."
  else
    log_warn "Unable to create compatibility healthcheck at '$ALT_HEALTHCHECK_FILE'."
  fi
else
  log_debug "Compatibility healthcheck already present at '$ALT_HEALTHCHECK_FILE'."
fi

# Storage handling (non-destructive, no Nginx edits, no destructive ops)
if [ -d "$APP_DIR/storage" ] && [ ! -L "$APP_DIR/storage" ]; then
  log_info "Copying contents from $APP_DIR/storage to $STORAGE_DIR (non-destructive)"
  if cp -a "$APP_DIR/storage/." "$STORAGE_DIR/" 2>/dev/null; then
    log_debug "Seeded persistent storage with existing application data."
  else
    log_warn "Failed to copy initial storage contents from $APP_DIR/storage; continuing with existing data in $STORAGE_DIR."
  fi
  if ln -sfn "$STORAGE_DIR" "$APP_DIR/storage"; then
    log_info "Linked $APP_DIR/storage → $STORAGE_DIR"
  else
    log_warn "Could not link $APP_DIR/storage; leaving as-is (likely busy)."
  fi
elif [ -L "$APP_DIR/storage" ]; then
  target="$(readlink "$APP_DIR/storage")"
  if [ "$target" != "$STORAGE_DIR" ]; then
    if ln -sfn "$STORAGE_DIR" "$APP_DIR/storage"; then
      log_info "Updated symlink $APP_DIR/storage → $STORAGE_DIR"
    else
      log_warn "Unable to update existing storage symlink from '$target' to '$STORAGE_DIR'."
    fi
  else
    log_debug "Storage symlink already points to '$STORAGE_DIR'."
  fi
else
  if ln -sfn "$STORAGE_DIR" "$APP_DIR/storage"; then
    log_info "Created symlink $APP_DIR/storage → $STORAGE_DIR"
  else
    log_warn "Failed to create storage symlink; copying contents as fallback."
    cp -a "$STORAGE_DIR/." "$APP_DIR/storage/" 2>/dev/null || log_warn "Fallback copy to $APP_DIR/storage failed."
  fi
fi

run_cmd() {
  if [ "$#" -eq 0 ]; then
    log_warn "run_cmd invoked without arguments"
    return 0
  fi
  cmd_display="$*"
  log_info "Executing command: $cmd_display"
  if [ -n "$LOG_FILE" ]; then
    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '%s [command] %s\n' "$timestamp" "$cmd_display" >>"$LOG_FILE" 2>/dev/null || :
  fi
  tmp="$(mktemp /tmp/firefly-cmd.XXXXXX)"
  if "$@" >"$tmp" 2>&1; then
    if [ -s "$tmp" ]; then
      if log_should_emit trace; then
        while IFS= read -r line; do
          log_trace "→ $line"
        done <"$tmp"
      fi
      if [ -n "$LOG_FILE" ]; then
        cat "$tmp" >>"$LOG_FILE" 2>/dev/null || :
      fi
    fi
    rm -f "$tmp"
    log_debug "Command succeeded: $cmd_display"
    return 0
  else
    rc=$?
    if [ -s "$tmp" ]; then
      while IFS= read -r line; do
        log_warn "→ $line"
      done <"$tmp"
      if [ -n "$LOG_FILE" ]; then
        cat "$tmp" >>"$LOG_FILE" 2>/dev/null || :
      fi
    fi
    rm -f "$tmp"
    log_error "Command failed (exit $rc): $cmd_display"
    return $rc
  fi
}

set_kv() {
  key="$1"; value="$2"
  tmpfile="$(mktemp /tmp/firefly-env.XXXXXX)"
  found=0
  modified=0
  if [ -f "$ENV_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "$key="*)
          found=1
          current="${line#*=}"
          if [ "$current" != "$value" ]; then
            printf '%s=%s\n' "$key" "$value" >>"$tmpfile"
            modified=1
          else
            printf '%s\n' "$line" >>"$tmpfile"
          fi
          ;;
        *)
          printf '%s\n' "$line" >>"$tmpfile"
          ;;
      esac
    done <"$ENV_FILE"
  fi
  if [ "$found" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmpfile"
    modified=1
  fi
  if [ "$modified" -eq 0 ]; then
    rm -f "$tmpfile"
    log_debug "No change required for $key in $ENV_FILE"
    return 0
  fi
  if mv "$tmpfile" "$ENV_FILE" 2>/dev/null; then
    :
  else
    cp "$tmpfile" "$ENV_FILE"
    rm -f "$tmpfile"
  fi
  log_info "Updated $ENV_FILE: $key=$(mask_value "$key" "$value")"
}

if [ ! -f "$ENV_FILE" ]; then
  if [ -f ".env.example" ]; then
    log_info "Creating $ENV_FILE from .env.example"
    cp .env.example "$ENV_FILE"
  else
    log_warn ".env.example not found; creating empty $ENV_FILE"
    : >"$ENV_FILE"
  fi
else
  log_debug "Found existing environment file at $ENV_FILE"
fi

sync_app_env() {
  if [ -L "$APP_ENV_FILE" ]; then
    target="$(readlink "$APP_ENV_FILE")"
    if [ "$target" != "$ENV_FILE" ]; then
      log_warn "App .env symlink points to '$target'; updating to '$ENV_FILE'"
      rm -f "$APP_ENV_FILE"
      if ln -s "$ENV_FILE" "$APP_ENV_FILE"; then
        log_info "Updated symlink $APP_ENV_FILE → $ENV_FILE"
      else
        log_warn "Unable to update .env symlink; copying as fallback"
        cp "$ENV_FILE" "$APP_ENV_FILE"
        log_info "Copied $ENV_FILE to $APP_ENV_FILE (symlink fallback)"
      fi
    else
      log_debug "App .env symlink already points to $ENV_FILE"
    fi
  elif [ -f "$APP_ENV_FILE" ]; then
    log_warn "App directory contains a regular .env file; replacing with symlink"
    rm -f "$APP_ENV_FILE" 2>/dev/null || true
    if ln -s "$ENV_FILE" "$APP_ENV_FILE"; then
      log_info "Linked $APP_ENV_FILE → $ENV_FILE"
    else
      log_warn "Failed to create symlink; copying environment file instead"
      cp "$ENV_FILE" "$APP_ENV_FILE"
      log_info "Copied $ENV_FILE to $APP_ENV_FILE (symlink failed)"
    fi
  else
    if ln -s "$ENV_FILE" "$APP_ENV_FILE" 2>/dev/null; then
      log_info "Linked $APP_ENV_FILE → $ENV_FILE"
    else
      log_warn "Symlink creation for $APP_ENV_FILE failed; copying environment file"
      cp "$ENV_FILE" "$APP_ENV_FILE"
      log_info "Copied $ENV_FILE to $APP_ENV_FILE"
    fi
  fi
}

# Core env
set_kv APP_ENV "production"
set_kv TZ "$TIMEZONE"
set_kv TRUSTED_PROXIES "**"
set_kv LOG_CHANNEL "stack"
set_kv SITE_OWNER "$SITE_OWNER"

# DB env
set_kv DB_CONNECTION "mysql"
set_kv DB_HOST "$DB_HOST"
set_kv DB_PORT "$DB_PORT"
set_kv DB_DATABASE "$DB_NAME"
set_kv DB_USERNAME "$DB_USER"
set_kv DB_PASSWORD "$DB_PASSWORD"

# Mail defaults
set_kv MAIL_MAILER "log"

sync_app_env

export APP_ENV="production"
export TZ="$TIMEZONE"
export TRUSTED_PROXIES="**"
export LOG_CHANNEL="stack"
export SITE_OWNER="$SITE_OWNER"
export DB_CONNECTION="mysql"
export DB_HOST="$DB_HOST"
export DB_PORT="$DB_PORT"
export DB_DATABASE="$DB_NAME"
export DB_USERNAME="$DB_USER"
export DB_PASSWORD="$DB_PASSWORD"
export MAIL_MAILER="log"
log_debug "Core environment variables exported (sensitive values redacted)."

ensure_app_key() {
  current_key="$(grep '^APP_KEY=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)"
  if [ "$GENERATE_APP_KEY" = "true" ] && { [ -z "$current_key" ] || [ "$current_key" = "" ]; }; then
    log_info "APP_KEY missing; attempting artisan key generation."
    if ! run_cmd php artisan key:generate --force --no-ansi; then
      log_warn "Artisan key:generate reported an error; will attempt manual key generation if needed."
    fi
    sync_app_env
    current_key="$(grep '^APP_KEY=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)"
    if [ -z "$current_key" ] || [ "$current_key" = "" ]; then
      log_warn "Artisan key:generate did not produce an APP_KEY; generating manually."
      manual_key="base64:$(head -c 32 /dev/urandom | base64)"
      set_kv APP_KEY "$manual_key"
      sync_app_env
      current_key="$manual_key"
    fi
  fi
  if [ -z "$current_key" ] || [ "$current_key" = "" ]; then
    log_error "APP_KEY is missing and could not be generated. Startup aborted."
    exit 1
  fi
  export APP_KEY="$current_key"
  log_info "APP_KEY is set (value redacted)."
}

ensure_app_key

if ! run_cmd php artisan config:clear; then
  log_warn "Continuing despite failure of 'php artisan config:clear'."
fi
if ! run_cmd php artisan cache:clear; then
  log_warn "Continuing despite failure of 'php artisan cache:clear'."
fi
if ! run_cmd php artisan config:cache; then
  log_warn "Continuing despite failure of 'php artisan config:cache'."
fi
if ! run_cmd php artisan passport:keys --force; then
  log_warn "Continuing despite failure of 'php artisan passport:keys --force'."
fi

migrate_attempts=0
while ! run_cmd php artisan migrate --force --no-ansi; do
  migrate_attempts=$((migrate_attempts + 1))
  if [ "$migrate_attempts" -ge 15 ]; then
    log_error "Migrations failed after $migrate_attempts attempts; proceeding without successful migration."
    break
  fi
  log_warn "Database not ready... retry $migrate_attempts/15"
  sleep 4
done

log_info "Starting PHP built-in server on 0.0.0.0:$PORT with document root $APP_DIR/public"
ROUTER_FILE="$APP_DIR/ha-router.php"
if [ ! -f "$ROUTER_FILE" ]; then
  log_info "Creating PHP built-in router script at '$ROUTER_FILE'."
  if cat <<'EOPHP' >"$ROUTER_FILE" 2>/dev/null; then
<?php
$publicPath = __DIR__ . '/public';
$publicReal = realpath($publicPath) ?: $publicPath;
$originalRequest = $_SERVER['REQUEST_URI'] ?? '/';
$rawUri = parse_url($originalRequest, PHP_URL_PATH) ?? '/';
$uri = urldecode($rawUri);
$ingressHeader = $_SERVER['HTTP_X_INGRESS_PATH'] ?? '';
$upstreamScheme = $_SERVER['HTTP_X_FORWARDED_PROTO'] ?? (($_SERVER['HTTPS'] ?? 'off') !== 'off' ? 'https' : 'http');
$upstreamHost = $_SERVER['HTTP_X_FORWARDED_HOST'] ?? ($_SERVER['HTTP_HOST'] ?? 'localhost');

if ($ingressHeader !== '' && strpos($uri, $ingressHeader) === 0) {
    $stripped = substr($uri, strlen($ingressHeader));
    $stripped = '/' . ltrim($stripped, '/');
} else {
    $stripped = $uri;
}

if ($ingressHeader !== '') {
    $_SERVER['HTTP_X_FORWARDED_PREFIX'] = $ingressHeader;
    $scriptName = rtrim($ingressHeader, '/') . '/index.php';
    if ($scriptName === '/index.php' && rtrim($ingressHeader, '/') !== '') {
        $scriptName = $ingressHeader . '/index.php';
    }
    $_SERVER['SCRIPT_NAME'] = $scriptName;
    $_SERVER['PHP_SELF'] = $scriptName . ($stripped === '/' ? '' : $stripped);
    $_SERVER['PATH_INFO'] = $stripped === '/' ? '' : $stripped;
    $forcedUrl = rtrim($upstreamScheme . '://' . $upstreamHost . rtrim($ingressHeader, '/'), '/');
    putenv('APP_URL=' . $forcedUrl);
    $_ENV['APP_URL'] = $forcedUrl;
    $_SERVER['APP_URL'] = $forcedUrl;
}

$fullPath = realpath($publicPath . $stripped);
if ($stripped !== '/' && $fullPath && strpos($fullPath, $publicReal) === 0 && is_file($fullPath)) {
    return false;
}

header_register_callback(function () use ($upstreamScheme, $upstreamHost) {
    $allowedOrigin = $upstreamScheme . '://' . $upstreamHost;
    header_remove('X-Frame-Options');
    header('X-Frame-Options: ALLOWALL');
    $csp = "frame-ancestors 'self' $allowedOrigin";
    header_remove('Content-Security-Policy');
    header('Content-Security-Policy: ' . $csp);
});

require_once $publicPath . '/index.php';
EOPHP
    log_info "Router script created."
  else
    log_warn "Failed to write router script to '$ROUTER_FILE'; built-in server will rely on default routing."
    ROUTER_FILE=""
  fi
else
  log_debug "Router script already present at '$ROUTER_FILE'."
fi

if [ -n "$ROUTER_FILE" ]; then
  php -S 0.0.0.0:"$PORT" -t "$APP_DIR/public" "$ROUTER_FILE" >/var/log/php-server.log 2>&1 &
else
  php -S 0.0.0.0:"$PORT" -t "$APP_DIR/public" >/var/log/php-server.log 2>&1 &
fi
PHP_SERVER_PID=$!
log_info "PHP built-in server started with PID $PHP_SERVER_PID (logs: /var/log/php-server.log)"

wait_for_http() {
  log_info "Waiting for HTTP healthcheck at http://127.0.0.1:$PORT/healthcheck.html (max 90s)"
  i=0
  while [ "$i" -lt 90 ]; do
    i=$((i + 1))
    if curl --silent --fail --max-time 2 "http://127.0.0.1:$PORT/healthcheck.html" >/dev/null; then
      log_info "Healthcheck OK after $i attempt(s)."
      return 0
    fi
    if [ $((i % 10)) -eq 0 ]; then
      log_debug "Healthcheck not ready after $i attempt(s)."
    fi
    sleep 1
  done
  log_error "PHP dev server failed to start or healthcheck not ready after 90s"
  if [ -f /var/log/php-server.log ]; then
    log_warn "Tail of /var/log/php-server.log:"
    tmp_log="$(mktemp /tmp/firefly-php-log.XXXXXX)"
    if tail -n 200 /var/log/php-server.log >"$tmp_log" 2>/dev/null; then
      while IFS= read -r line || [ -n "$line" ]; do
        log_warn "[php] $line"
      done <"$tmp_log"
    else
      log_warn "Unable to read /var/log/php-server.log"
    fi
    rm -f "$tmp_log"
  else
    log_warn "PHP server log not found at /var/log/php-server.log"
  fi
  exit 1
}

wait_for_http

log_info "Startup sequence completed; entering wait state for background processes."
wait
