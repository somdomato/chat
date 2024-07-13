server {
  listen 80;
  listen [::]:80;
  server_name gamja.somdomato.com;
  return 301 https://$host$request_uri;
}

server {
   listen 80;
   listen [::]:80;

    listen 443 ssl;
    listen [::]:443 ssl;

    ssl_certificate         /etc/letsencrypt/live/gamja.somdomato.com/fullchain.pem;
    ssl_certificate_key     /etc/letsencrypt/live/gamja.somdomato.com/privkey.pem;
    
    server_name gamja.somdomato.com;
    proxy_intercept_errors on;

    location / {
      root /usr/share/gamja/dist;
    }

    location /webirc {
        proxy_pass http://127.0.0.1:8067;
        proxy_read_timeout 600s;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}