server {
   listen 80;
   listen [::]:80;

   server_name irc.somdomato.com;

    location / {
        proxy_read_timeout 15m;
        proxy_pass http://127.0.0.1:6667;

        # Set http version and headers
        proxy_http_version 1.1;
    
        # Add X-Forwarded-* headers
        proxy_set_header X-Forwarded-Host   $host;
        proxy_set_header X-Forwarded-Proto  $scheme;
        proxy_set_header X-Forwarded-For    $remote_addr;

        # Allow upgrades to websockets
        proxy_set_header Upgrade     $http_upgrade;
        proxy_set_header Connection  "upgrade";
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    ssl_certificate         /etc/letsencrypt/live/irc.somdomato.com/fullchain.pem;
    ssl_certificate_key     /etc/letsencrypt/live/irc.somdomato.com/privkey.pem;
    
    server_name irc.somdomato.com;
    proxy_intercept_errors on;

    location / {
        proxy_read_timeout 15m;
        proxy_pass http://127.0.0.1:6697;

        # Set http version and headers
        proxy_http_version 1.1;
    
        # Add X-Forwarded-* headers
        proxy_set_header X-Forwarded-Host   $host;
        proxy_set_header X-Forwarded-Proto  $scheme;
        proxy_set_header X-Forwarded-For    $remote_addr;

        # Allow upgrades to websockets
        proxy_set_header Upgrade     $http_upgrade;
        proxy_set_header Connection  "upgrade";
    }

    location ~ /\.ht { deny all; }
}

