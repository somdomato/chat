# 🎧 Rádio Som do Mato - Infraestrutura IRC

![Rádio Som do Mato](https://raw.githubusercontent.com/somdomato/somdomato/refs/heads/main/public/images/logo.svg "Rádio Som do Mato")

Infraestrutura de chat IRC completa usando Ergo, KiwiIRC e WebIRC Gateway.

| sistema | url | descrição |
| :--- | ---: | ---: |
| [Site](https://github.com/somdomato/somdomato) | [somdomato.com](https://somdomato.com) | Web Rádio Som do Mato |
| [Stream](https://github.com/somdomato/stream) | [radio.somdomato.com](https://radio.somdomato.com) | IceCast2 & LiquidSoap |
| [Chat](https://github.com/somdomato/chat) | [chat.somdomato.com](https://chat.somdomato.com) | Ergo IRC Server & Gamja IRC Web Client |
| [Mobile](https://github.com/somdomato/mobile) |  | Aplicativos iOS e Android da rádio |
| [Infra](https://github.com/somdomato/infra) |  | Imagens e contêineres do Docker e Ansible Playbooks para desenvolvimento local |

## Desenvolvimento Local (Docker)

Espelha o ambiente de produção (Oracle Linux 9 arm64) rodando em qualquer arquitetura (amd64/arm64).

### Subir o ambiente

```bash
# Na pasta chat/
podman compose -f docker/docker-compose.yml up -d --build
```

| Porta | Serviço |
|-------|---------|
| `9080` | KiwiIRC – `http://localhost:9080` |
| `9081` | Gamja – `http://localhost:9081` |
| `6667` | IRC plaintext (para clientes IRC diretos) |

### Via Makefile (monorepo)

```bash
# Na raiz do monorepo (pasta sdm/)
make vps2
```

### Credenciais de teste

| Serviço | Credencial |
|---------|-----------|
| IRC oper | `/oper admin hackme` |

### Configurações Docker

| Arquivo | Função |
|---------|--------|
| `docker/ircd.docker.yaml` | Ergo sem TLS, WebSocket em `:8067` (KiwiIRC) e `:8097` (Gamja) |
| `docker/webircgateway.docker.conf` | Upstream aponta para `ergo:8067` (Docker DNS) |
| `docker/nginx.conf` | Porta 80 → KiwiIRC, porta 8080 → Gamja |
| `docker/kiwiirc.client.json` | Usa `/webirc` relativo (funciona com qualquer porta) |
| `docker/gamja.config.json` | `ws://localhost:9081/webirc` |

Diferenças do Docker vs produção:

| Aspecto | Docker | Produção |
|---------|--------|----------|
| TLS | Sem TLS (plaintext) | Let's Encrypt via Cloudflare |
| Ergo porta 6697 | Não exposta | IRC com TLS |
| WebIRC Gateway bind | `0.0.0.0:7778` | `127.0.0.1:7778` |
| SELinux | Não aplicável | Configurado pelo Ansible |

### Comandos Docker

```bash
# Logs de todos os serviços
docker compose -f docker/docker-compose.yml logs -f

# Logs de um serviço específico
docker compose -f docker/docker-compose.yml logs -f ergo

# Reiniciar serviço
docker compose -f docker/docker-compose.yml restart ergo

# Parar tudo
docker compose -f docker/docker-compose.yml down

# Apagar dados do Ergo (banco IRC) e recomeçar do zero
docker compose -f docker/docker-compose.yml down -v
```

---

## 🎯 Arquitetura

### Fluxo de Comunicação

```
Usuário (Navegador) → NGINX (443/SSL) → WebIRC Gateway (8088) → Ergo IRC (6697)
                       ↓
                  KiwiIRC (arquivos estáticos)
```

### Componentes

- **Ergo IRC Server**: Servidor IRC moderno em `/usr/share/ergo`
  - Portas: 6667 (IRC), 6697 (IRC+SSL), 8067 (WebSocket)
  - Certificados SSL do Let's Encrypt
  
- **KiwiIRC Client**: Cliente web em `/usr/share/kiwiirc` (baixado do GitHub)
  - Servido como arquivos estáticos pelo Nginx
  - Interface web para conectar ao IRC
  
- **WebIRC Gateway**: Gateway para websockets em `/opt/webircgateway`
  - Porta: 8088 (localhost apenas)
  - Converte WebSocket (navegador) para protocolo IRC
  - Ponte entre KiwiIRC e Ergo
  
- **Nginx**: Proxy reverso com SSL (Let's Encrypt via Cloudflare DNS)
  - Serve arquivos estáticos do KiwiIRC
  - Faz proxy para WebIRC Gateway
  - Gerencia certificados SSL

### Resumo das Portas

| Serviço | Porta | Onde Escuta | Firewall | Descrição |
|---------|-------|-------------|----------|-----------|
| Ergo IRC | 6667 | 0.0.0.0 (público) | ✅ Abrir (opcional) | IRC sem SSL |
| Ergo IRC | 6697 | 0.0.0.0 (público) | ✅ Abrir | IRC com SSL/TLS |
| Ergo WebSocket | 8067 | 0.0.0.0 (público) | ✅ Abrir | WebSocket direto |
| WebIRC Gateway | 8088 | 127.0.0.1 (local) | ❌ Não abrir | Proxy WebSocket |
| Nginx HTTP | 80 | 0.0.0.0 (público) | ✅ Já aberto | Redireciona para HTTPS |
| Nginx HTTPS | 443 | 0.0.0.0 (público) | ✅ Já aberto | SSL/TLS |

### Sistemas Operacionais Suportados

- ✅ **Oracle Linux 9** (recomendado)
- ✅ Rocky Linux 8/9
- ✅ Debian 11/12
- ✅ Ubuntu 20.04/22.04/24.04

## 🚀 Instalação Rápida

### 1. Configurar Credenciais
� Configuração Detalhada dos Componentes

### 1. Ergo IRC Server

**Localização:** `/usr/share/ergo/ircd.yaml`

**Configuração de Portas:**

```yaml
server:
    listeners:
        # IRC sem SSL (opcional - pode remover se não precisar)
        ":6667": {}
        
        # IRC com SSL/TLS (principal)
        ":6697":
            tls:
                cert: /usr/share/ergo/fullchain.pem
                key: /usr/share/ergo/privkey.pem
        
        # WebSocket (para clientes web)
        ":8067":
            websocket: true
```

**Dicas:**
- Pode desabilitar a porta 6667 se quiser apenas conexões SSL
- A porta 8067 é para WebSocket direto (alternativa ao WebIRC Gateway)
- Certificados são copiados automaticamente pelo playbook

### 2. WebIRC Gateway

**Localização:** `/etc/webircgateway/config.conf`

**Configuração:**

```ini
# Servidor WebSocket (local apenas)
[server.1]
bind = "127.0.0.1"
port = 8088

# Conectar ao Ergo IRC
[upstream.1]
hostname = "127.0.0.1"
port = 6697
tls = true
timeout = 5
throttle = 2

# Nome do gateway
gateway_name = "webircgateway"

# Cliente
[clients]
username = "%i"
realname = "Rádio Som do Mato"
```

**Explicação:**
- `bind = "127.0.0.1"` - escuta APENAS localmente (Nginx faz proxy)
- `port = 8088` - porta do WebSocket
- `hostname = "127.0.0.1", port = 6697, tls = true` - conecta ao Ergo via SSL

### 3. Nginx

**Localização:** `/etc/nginx/sites.d/52-chat.somdomato.com.conf`

**Configuração:**

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name chat.somdomato.com;
    
    # Redirecionar HTTP para HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name chat.somdomato.com;

    # Certificados SSL
    ssl_certificate /etc/letsencrypt/live/chat.somdomato.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/chat.somdomato.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    # Servir KiwiIRC (arquivos estáticos)
    location / {
        root /usr/share/kiwiirc;
        try_files $uri $uri/ /index.html;
    }

    # Proxy para WebIRC Gateway (WebSocket)
    location /webirc {
        proxy_pass http://127.0.0.1:8067;
        proxy_http_version 1.1;
        
        # Essencial para WebSocket
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts para conexões IRC
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }

    location /webirc/kiwiirc {
        proxy_pass http://127.0.0.1:8067/webirc/kiwiirc;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
```

### 4. KiwiIRC

**Localização:** `/usr/share/kiwiirc/static/config.json`

**Configuração:**

```json
{
    "windowTitle": "Rádio Som do Mato - Chat",
    "startupScreen": "welcome",
    "kiwiServer": "/webirc/kiwiirc/",
    "restricted": false,
    "theme": "Default",
    "themes": [
        { "name": "Default", "url": "static/themes/default" },
        { "name": "Dark", "url": "static/themes/dark" }
    ],
    "startupOptions": {
        "server": "irc.somdomato.com",
        "port": 6697,
        "tls": true,
        "channel": "#somdomato",
        "nick": "visitante?"
    }
}
```

**Explicação:**
- `kiwiServer: "/webirc/kiwiirc/"` - aponta para o proxy do Nginx
- `startupOptions` - configurações padrão ao abrir o cliente

### Checklist de Configuração

Após executar o playbook, verifique:

```bash
# 1. Verificar se portas estão escutando
sudo ss -tlnp | grep -E '(443|6667|6697|8067|8088)'

# 2. Verificar serviços
sudo systemctl status somdomato-ergo
sudo systemctl status somdomato-webircgateway
sudo systemctl status nginx

# 3. Testar WebIRC Gateway localmente
curl http://127.0.0.1:8088/

# 4. Testar via Nginx
curl -I https://chat.somdomato.com

# 5. Verificar logs se houver problemas
sudo journalctl -u somdomato-ergo -n 50
sudo journalctl -u somdomato-webircgateway -n 50
sudo journalctl -u nginx -n 50

# 6. Testar no navegador
# Abra: https://chat.somdomato.com
```

### Ajustes de SELinux (Oracle Linux)

```bash
# 1. Contexto dos diretórios
sudo restorecon -Rv /usr/share/ergo
sudo restorecon -Rv /usr/share/kiwiirc
sudo restorecon -Rv /opt/webircgateway

# 2. Permitir conexões de rede do Nginx
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_can_network_relay 1

# 3. Verificar se há bloqueios
sudo ausearch -m avc -ts recent
```

## �
```bash
# Configurar vault (primeira vez)
./scripts/vault.sh setup

# Editar credenciais do Cloudflare
./scripts/vault.sh edit
```

Configure no vault:
```yaml
# Email e API Key do Cloudflare (modo legacy)
cloudflare_email: "seu_email@dominio.com"
cloudflare_api_key: "sua_global_api_key_aqui"
```

### 2. Executar Ansible

```bash
# Instalação completa automatizada
./scripts/ansible.sh
```

### 3. Verificar Serviços

```bash
# No servidor
sudo systemctl status somdomato-ergo
sudo systemctl status somdomato-webircgateway
sudo systemctl status nginx
```

## 📋 Pré-requisitos

### No Servidor (VPS)

- Oracle Linux 9, Rocky Linux 8/9, Debian 11+ ou Ubuntu 20.04+
- Acesso SSH com privilégios sudo/root
- Portas abertas: 80, 443, 6667, 6697, 8067, 8088
- DNS configurado apontando para o servidor

### Na Máquina Local

- Ansible 2.9+
- Python 3.6+
- SSH configurado para acesso ao servidor

## 🔐 Configuração do Cloudflare

### Obter Credenciais (Modo Legacy)

1. Acesse [Cloudflare Dashboard](https://dash.cloudflare.com/)
1. Acesse [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Vá em **My Profile** → **API Tokens**
3. Na seção **API Keys**, clique em **View** na **Global API Key**
4. Confirme sua senha e copie a API Key
5. Use seu email de login do Cloudflare + a Global API Key no vault

## ⚙️ Configuração Avançada

### Variáveis Globais

Edite [ansible/group_vars/all.yml](ansible/group_vars/all.yml):

```yaml
# Domínios
domains:
  irc: "irc.somdomato.com"
  chat: "chat.somdomato.com"

# Email para Let's Encrypt
letsencrypt_email: "seu_email@dominio.com"

# Diretórios das aplicações
app_dirs:
  ergo: "/usr/share/ergo"
  kiwiirc: "/usr/share/kiwiirc"
  webircgateway: "/opt/webircgateway"

# Configurações SSH
ansible_port: 2200
ansible_user: root
```

### SELinux (Oracle Linux / RHEL / Rocky)

O playbook configura automaticamente o SELinux para permitir:
- ✅ Nginx conectar em portas não-padrão
- ✅ Acesso aos diretórios das aplicações
- ✅ Contextos corretos para executáveis

Para verificar o SELinux:
```bash
# Verificar status
sudo getenforce

# Ver contextos
sudo ls -laZ /usr/share/ergo
sudo ls -laZ /opt/webircgateway

# Logs do SELinux
sudo ausearch -m avc -ts recent
```

### Portas e Firewall

Certifique-se de que as portas estejam abertas:

```bash
# Oracle Linux / RHEL / Rocky
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=6667/tcp
sudo firewall-cmd --permanent --add-port=6697/tcp
sudo firewall-cmd --permanent --add-port=8067/tcp
sudo firewall-cmd --permanent --add-port=8088/tcp
sudo firewall-cmd --reload

# Debian / Ubuntu
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 6667/tcp
sudo ufw allow 6697/tcp
sudo ufw allow 8067/tcp
sudo ufw allow 8088/tcp
```

## 📁 Estrutura do Projeto

```
ansible/
├── ansible.cfg                    # Configurações do Ansible
├── playbook.yml                   # Playbook principal
├── group_vars/
│   ├── all.yml                    # Variáveis globais
│   └── vault.yml                  # Credenciais criptografadas
├── etc/
│   ├── nginx/sites.d/             # Configurações do Nginx
│   │   ├── 12-irc.somdomato.com.conf
│   │   └── 52-chat.somdomato.com.conf
│   ├── systemd/system/            # Serviços systemd
│   │   ├── somdomato-ergo.service
│   │   └── somdomato-webircgateway.service
│   ├── kiwiirc/                   # Configurações do KiwiIRC
│   └── letsencrypt/               # Hooks do Let's Encrypt
└── usr/share/
    ├── ergo/                      # Arquivos do Ergo IRC
    └── kiwiirc/                   # Temas customizados do KiwiIRC

scripts/
├── ansible.sh                     # Script principal
├── vault.sh                       # Gerenciador do vault
├── sync.sh                        # Sincronizar arquivos
└── legacy/                        # Scripts antigos (depreciados)

working/                           # Backup do que está rodando na VPS
├── etc/
├── opt/
└── var/
```

## 🔧 Comandos Úteis

### Gerenciar Vault

```bash
./scripts/vault.sh edit      # Editar credenciais
./scripts/vault.sh view      # Visualizar
./scripts/vault.sh setup     # Configuração inicial
./scripts/vault.sh rekey     # Alterar senha
```

### Gerenciar Serviços

```bash
# No servidor VPS
sudo systemctl status somdomato-ergo
sudo systemctl status somdomato-webircgateway
sudo systemctl status nginx

# Reiniciar serviços
sudo systemctl restart somdomato-ergo
sudo systemctl restart somdomato-webircgateway
sudo systemctl restart nginx

# Ver logs em tempo real
sudo journalctl -u somdomato-ergo -f
sudo journalctl -u somdomato-webircgateway -f
sudo journalctl -u nginx -f
```

### Sincronizar Alterações

```bash
# Sincronizar arquivos locais com o servidor
./scripts/sync.sh

# Executar apenas partes específicas do playbook
cd ansible
ansible-playbook playbook.yml -i ananke, --vault-password-file=.vault_pass --tags nginx
```

## 🐛 Troubleshooting

### Erro: "Arquivo de senha do vault não encontrado"

```bash
./scripts/vault.sh setup
```

### Erro: Credenciais do Cloudflare Inválidas

```bash
# 1. Verificar credenciais
./scripts/vault.sh view

# 2. Editar e corrigir
./scripts/vault.sh edit

# 3. Testar conexão (no servidor)
curl -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "X-Auth-Email: seu_email@dominio.com" \
  -H "X-Auth-Key: sua_api_key"
```

### Erro: Certificados SSL não criados

Verifique se:
- ✅ Credenciais do Cloudflare estão corretas
- ✅ DNS está configurado corretamente
- ✅ Domínios estão gerenciados pelo Cloudflare

```bash
# No servidor
sudo tail -f /var/log/letsencrypt/letsencrypt.log
sudo certbot certificates
```

### Erro: Nginx não inicia

```bash
# Testar configuração
sudo nginx -t

# Ver logs
sudo journalctl -u nginx -n 50

# Verificar portas em uso
sudo ss -tlnp | grep -E ':(80|443|6667|6697|8067|8088)'
```

### Erro: SELinux bloqueando conexões

```bash
# Ver alertas do SELinux
sudo ausearch -m avc -ts recent

# Permitir temporariamente (para debug)
sudo setenforce 0

# Aplicar contextos novamente
sudo restorecon -Rv /usr/share/ergo
sudo restorecon -Rv /opt/webircgateway

# Habilitar SELinux novamente
sudo setenforce 1
```

### Debug Modo Verbose

```bash
cd ansible
ansible-playbook playbook.yml -i ananke, --vault-password-file=.vault_pass -vvv
```

## 🔄 Atualizações

### Atualizar KiwiIRC

O KiwiIRC é baixado automaticamente do GitHub. Para atualizar para uma nova versão:

1. Edite [ansible/playbook.yml](ansible/playbook.yml) e altere a URL da versão
2. Execute: `./scripts/ansible.sh`

### Atualizar Ergo

1. Substitua os arquivos em `ansible/usr/share/ergo/`
2. Execute: `./scripts/ansible.sh`

### Atualizar Configurações

```bash
# Sincronizar apenas configurações
./scripts/sync.sh

# Ou executar o playbook completo
./scripts/ansible.sh
```

## 📝 Logs e Monitoramento

```bash
# Logs do Ergo
sudo journalctl -u somdomato-ergo -f

# Logs do WebIRC Gateway
sudo journalctl -u somdomato-webircgateway -f

# Logs do Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Verificar certificados
sudo certbot certificates

# Renovar certificados manualmente
sudo certbot renew --dry-run
```

## 🔒 Segurança

### Firewall

Configure o firewall para permitir apenas as portas necessárias.

### SELinux

Mantenha o SELinux em modo `Enforcing` para máxima segurança. O playbook configura tudo automaticamente.

### Certificados

Os certificados são renovados automaticamente pelo certbot. Hook de deployment em:
- `/etc/letsencrypt/renewal-hooks/deploy/install-ergo-certificates`

### Backup

Faça backup regular de:
- Configurações: `/etc/nginx/`, `/usr/share/ergo/ircd.yaml`
- Dados do IRC: `/usr/share/ergo/ircd.db` (se usando SQLite)
- Certificados: `/etc/letsencrypt/`

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto é mantido pela [Rádio Som do Mato](https://somdomato.com).

## 🔗 Links Úteis

- [Ergo IRC](https://ergo.chat/) - Servidor IRC moderno
- [KiwiIRC](https://kiwiirc.com/) - Cliente web IRC
- [WebIRC Gateway](https://github.com/kiwiirc/webircgateway) - Gateway WebSocket
- [Let's Encrypt](https://letsencrypt.org/) - Certificados SSL gratuitos
- [Cloudflare](https://www.cloudflare.com/) - DNS e CDN

---

**Nota**: Este setup foi otimizado para Oracle Linux 9, mas é compatível com Rocky Linux, Debian e Ubuntu. O playbook detecta automaticamente o sistema operacional e ajusta os comandos apropriadamente.
