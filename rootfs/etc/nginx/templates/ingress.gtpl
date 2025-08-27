server {
    listen {{ .interface }}:8099 default_server;
    server_name _;
    
    # Ingress interface
    listen {{ .interface }}:8080;
    
    root /var/www/html/public;
    index index.php;

    client_max_body_size 100M;

    # Error and access logs
    error_log /data/nginx/logs/error.log debug;
    access_log /data/nginx/logs/access.log combined;

    # Disable MIME type sniffing
    add_header X-Content-Type-Options "nosniff" always;
    
    # Disable iframe embedding except from same origin
    add_header X-Frame-Options "SAMEORIGIN" always;
    
    # Enable XSS protection
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Disable search engine indexing
    add_header X-Robots-Tag "none" always;
    
    # Set referrer policy
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Enable cross-origin requests for Home Assistant ingress
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE, HEAD" always;
    add_header Access-Control-Allow-Headers "X-Requested-With, Content-Type, Authorization, Accept" always;

    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

    # Handle pre-flight requests for CORS
    location ~ ^/(.*)$ {
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
        try_files $uri $uri/ /index.php?$query_string;
    }

    # Main location for PHP files
    location ~ \.php$ {
        # Include standard FastCGI parameters
        include fastcgi_params;
        
        # Pass PHP scripts to PHP-FPM
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        
        # Set the script filename parameter for PHP-FPM
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $document_root;
        
        # Set additional headers for PHP scripts
        fastcgi_param HTTP_X_INGRESS 1;
        fastcgi_param HTTP_X_FORWARDED_HOST $http_host;
        fastcgi_param HTTP_X_FORWARDED_PORT $server_port;
        fastcgi_param HTTP_X_FORWARDED_PROTO $scheme;
        
        # Configure FastCGI parameters for Firefly III
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        
        # Add headers for PHP responses
        add_header Access-Control-Allow-Origin "*" always;
    }
    
    # Handle assets with proper caching
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires max;
        access_log off;
        log_not_found off;
        add_header Cache-Control "public, max-age=31536000";
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # Handle /test.php requests specially for debugging
    location = /test.php {
        include fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_X_FORWARDED_HOST $http_host;
        fastcgi_param HTTP_X_FORWARDED_PORT $server_port;
        fastcgi_param HTTP_X_FORWARDED_PROTO $scheme;
    }
    
    # Block access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
