Vou explicar de forma clara como tudo funciona junto:

## 📊 Arquitetura do Sistema

```
Usuário → NGINX (443) → webircgateway (8088) → Ergo IRC (6697)
          ↓
     KiwiIRC (arquivos estáticos)
```

---

## 🔧 **1. ERGO (Servidor IRC)** - `/opt/ergo/ircd.yaml`

**O que faz:** É o servidor IRC real onde as pessoas conversam.

**Portas que usa:** (do seu arquivo)
- `6667` - IRC sem SSL (pode desabilitar se não quiser)
- `6697` - IRC com SSL/TLS ✅ **(principal)**

**O que alterar:**

```yaml
server:
    listeners:
        # Pode remover a porta 6667 se não quiser conexão sem SSL
        # ":6667": {}
        
        # Manter esta - é a porta SSL
        ":6697":
            tls:
                cert: /etc/letsencrypt/live/irc.somdomato.com/fullchain.pem
                key: /etc/letsencrypt/live/irc.somdomato.com/privkey.pem
```

**Firewall:**
```bash
sudo firewall-cmd --permanent --add-port=6697/tcp
sudo firewall-cmd --reload
```

---

## 🌐 **2. WEBIRCGATEWAY** - `/opt/webircgateway/config.conf`

**O que faz:** Faz a ponte entre o navegador (KiwiIRC) e o servidor IRC (Ergo). Converte WebSocket para IRC.

**Portas:**
- **Escuta em:** `8088` (localhost apenas - não precisa abrir no firewall)
- **Conecta em:** `127.0.0.1:6697` (Ergo)

**Configuração correta:**

```bash
sudo nano /opt/webircgateway/config.conf
```

```ini
[listeners]
127.0.0.1:8088

[upstreams]
127.0.0.1 6697 tls=true

[gateway]
hostname=irc.somdomato.com

[logging]
level=info
```

**Explicação:**
- `127.0.0.1:8088` - escuta APENAS localmente (Nginx vai fazer proxy para aqui)
- `127.0.0.1 6697 tls=true` - conecta no Ergo via SSL
- `hostname` - nome do seu servidor IRC

---

## 🌍 **3. NGINX** - `/etc/nginx/sites-available/10-irc_somdomato_com.conf`

**O que faz:** Serve os arquivos do KiwiIRC e faz proxy para o webircgateway.

**Configuração limpa e correta:**

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name irc.somdomato.com;
    
    # Redirecionar HTTP para HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name irc.somdomato.com;

    # SSL
    ssl_certificate /etc/letsencrypt/live/irc.somdomato.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/irc.somdomato.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Root do KiwiIRC (arquivos estáticos)
    root /var/www/irc.somdomato.com;
    index index.html;

    # Servir arquivos estáticos do KiwiIRC
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy para webircgateway (WebSocket)
    location /webirc/ {
        proxy_pass http://127.0.0.1:8088/;
        proxy_http_version 1.1;
        
        # Essencial para WebSocket
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Headers padrão
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts para WebSocket
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }

    # Logs
    access_log /var/log/nginx/irc.somdomato.com.access.log;
    error_log /var/log/nginx/irc.somdomato.com.error.log;
}
```

**O que REMOVER do seu arquivo atual:**
- `listen 8088` - não é necessário
- Configurações duplicadas de SSL
- Blocos `location` desnecessários

---

## 📱 **4. KIWIIRC** - `/var/www/irc.somdomato.com/static/config.json`

**O que faz:** Interface web que roda no navegador.

**Configuração:**

```json
{
    "windowTitle": "Rádio Som do Mato",
    "startupScreen": "welcome",
    "kiwiServer": "/webirc/kiwiirc/",
    "restricted": false,
    "theme": "Default",
    "themes": [
        { "name": "Default", "url": "static/themes/default" },
        { "name": "Dark", "url": "static/themes/dark" }
    ],
    "startupOptions": {
        "channel": "#somdomato",
        "nick": "sdm-n?"
    }
}
```

**Explicação:**
- `kiwiServer: "/webirc/kiwiirc/"` - aponta para o proxy do Nginx que vai para o webircgateway

---

## ✅ **Checklist de configuração:**

```bash
# 1. Ajustar contexto SELinux do KiwiIRC
sudo restorecon -Rv /var/www/irc.somdomato.com

# 2. Ajustar webircgateway config
sudo nano /opt/webircgateway/config.conf
# (usar a configuração acima)

# 3. Ajustar Nginx
sudo nano /etc/nginx/sites-available/10-irc_somdomato_com.conf
# (usar a configuração acima)

# 4. Testar Nginx
sudo nginx -t

# 5. SELinux - permitir conexões do Nginx
sudo setsebool -P httpd_can_network_connect 1

# 6. Reiniciar serviços
sudo systemctl restart ergo
sudo systemctl restart webircgateway
sudo systemctl reload nginx

# 7. Verificar se tudo está rodando
sudo ss -tlnp | grep -E '(443|6697|8088)'
sudo systemctl status ergo webircgateway nginx
```

---

## 🔍 **Teste final:**

```bash
# 1. Testar webircgateway diretamente
curl http://127.0.0.1:8088/webirc/kiwiirc/

# 2. Testar via Nginx
curl https://irc.somdomato.com/webirc/kiwiirc/

# 3. Acessar no navegador
# https://irc.somdomato.com
```

---

## 🎯 **Resumo das portas:**

| Serviço | Porta | Onde escuta | Firewall |
|---------|-------|-------------|----------|
| Ergo IRC | 6697 | 0.0.0.0 (público) | ✅ Abrir |
| webircgateway | 8088 | 127.0.0.1 (local) | ❌ Não abrir |
| Nginx | 443 | 0.0.0.0 (público) | ✅ Já aberto |

Alguma dúvida sobre alguma parte específica?