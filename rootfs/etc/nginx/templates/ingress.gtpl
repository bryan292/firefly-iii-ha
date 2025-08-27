server {
    listen {{ .interface }}:8099 default_server;
    server_name _;
    
    # Ingress interface
    listen {{ .interface }}:8080;
    
    root /var/www/html/public;
    index index.php index.html;

    client_max_body_size 100M;

    # Error and access logs
    error_log /data/nginx/logs/error.log debug;
    access_log /data/nginx/logs/access.log;

    # Add proper headers for ingress
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;

    # Enable gzip but do not remove ETag headers
    gzip on;
    gzip_vary on;
    gzip_comp_level 4;
    gzip_min_length 256;
    gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
    gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;

    # Laravel pretty URLs with fallback
    location / {
        try_files $uri $uri/ /index.php$is_args$args;
        
        # Add support for Home Assistant's ingress
        add_header Access-Control-Allow-Origin *;
    }

    # Specific handling for index.php
    location = /index.php {
        include fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_X_FORWARDED_HOST $http_host;
        fastcgi_param HTTP_X_FORWARDED_PORT $server_port;
        fastcgi_param HTTP_X_FORWARDED_PROTO $scheme;
        
        # Set longer timeouts for Firefly III operations
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    # PHP-FPM configuration
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        
        # Make sure SCRIPT_FILENAME is set
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        
        # Home Assistant ingress requires these headers
        fastcgi_param HTTP_X_INGRESS 1;
        fastcgi_param HTTP_X_FORWARDED_HOST $http_host;
        fastcgi_param HTTP_X_FORWARDED_PORT $server_port;
        fastcgi_param HTTP_X_FORWARDED_PROTO $scheme;
        
        # Set longer timeouts for Firefly III operations
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 16 16k;
        fastcgi_busy_buffers_size 32k;
    }

    # Optimize asset delivery
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires max;
        log_not_found off;
        access_log off;
        add_header Cache-Control "public, max-age=31536000";
        try_files $uri $uri/ /index.php?$query_string;
    }

    # Add caching for API results
    location /api {
        try_files $uri $uri/ /index.php?$query_string;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
    }

    # Deny access to hidden files
    location ~ /\.(?!well-known) {
        deny all;
    }
    
    # Don't log access to favicon.ico
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    # Don't log access to robots.txt
    location = /robots.txt {
        log_not_found off;
        access_log off;
    }
    
    # Additional security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
}
