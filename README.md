# 🎧 Rádio Som do Mato - Infraestrutura IRC

![Rádio Som do Mato](https://raw.githubusercontent.com/somdomato/somdomato/refs/heads/main/web/static/images/logo.svg "Rádio Som do Mato")

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
| `9083` | Jitsi Meet – `http://localhost:9083` (opcional, ver [seção de conferência](#-conferência-jitsi-meet-self-hosted)) |

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

> **Ponte IRC ↔ Telegram (opcional):** não sobe com os comandos acima. Veja a
> seção [💬 Ponte IRC <-> Telegram (Matterbridge)](#-ponte-irc---telegram-matterbridge).

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
│   │   ├── somdomato-webircgateway.service
│   │   └── somdomato-matterbridge.service   # ponte IRC <-> Telegram
│   ├── kiwiirc/                   # Configurações do KiwiIRC
│   ├── matterbridge/              # Template da config da ponte Telegram
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

### Rodar comandos `ansible-playbook` manualmente (syntax-check, lint, --tags, etc)

O `playbook.yml` carrega `group_vars/vault.yml`, que é **criptografado** (Ansible Vault). Qualquer comando `ansible-playbook` — incluindo `--syntax-check`, `ansible-lint` ou execuções parciais com `--tags` — precisa receber a senha do vault, senão falha com:

```
[ERROR]: Invalid vars_files file '.../group_vars/vault.yml': Attempting to decrypt but no vault secrets found.
```

`ansible/ansible.cfg` já define `vault_password_file = .vault_pass`, então basta rodar **de dentro da pasta `ansible/`** e a senha é lida automaticamente:

```bash
cd ansible
ansible-playbook playbook.yml --syntax-check
```

O caminho em `ansible.cfg` é relativo a essa pasta, e o Ansible só carrega esse arquivo automaticamente quando ele está no diretório atual. Rodando a partir da raiz do repo (ex.: `ansible-playbook ansible/playbook.yml`), aponte explicitamente para o config ou para o arquivo de senha:

```bash
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbook.yml --syntax-check
# ou
ansible-playbook ansible/playbook.yml --syntax-check --vault-password-file=ansible/.vault_pass
```

Não existe `ansible/.vault_pass`? Rode `./scripts/vault.sh setup` primeiro (veja "Erro: Arquivo de senha do vault não encontrado" no Troubleshooting).

### Gerenciar Serviços

```bash
# No servidor VPS
sudo systemctl status somdomato-ergo
sudo systemctl status somdomato-webircgateway
sudo systemctl status somdomato-matterbridge    # ponte Telegram (se configurada)
sudo systemctl status nginx

# Reiniciar serviços
sudo systemctl restart somdomato-ergo
sudo systemctl restart somdomato-webircgateway
sudo systemctl restart somdomato-matterbridge
sudo systemctl restart nginx

# Ver logs em tempo real
sudo journalctl -u somdomato-ergo -f
sudo journalctl -u somdomato-webircgateway -f
sudo journalctl -u somdomato-matterbridge -f
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

## 🎨 Temas do KiwiIRC e Gamja

Guia completo para editar a aparência visual do chat, testar localmente e publicar em produção.

### Onde está cada coisa

| O quê | Onde | Observação |
|---|---|---|
| Temas do KiwiIRC | `ansible/usr/share/kiwiirc/static/themes/<nome>/theme.css` | Cada tema importa `../common/base.css` e sobrescreve variáveis/seletores |
| Estilos base (compartilhados por todos os temas) | `ansible/usr/share/kiwiirc/static/themes/common/base.css` | Editado raramente; afeta todos os temas |
| Tema ativo / lista de temas disponíveis | `ansible/etc/kiwiirc/client.json` (chave `theme` e `themes`) | Em produção. No Docker local, ver `docker/kiwiirc.client.json` |
| Imagens usadas pelos temas (ex. `wood.jpg`, `favicon.png`) | `ansible/usr/share/kiwiirc/static/img/` | Referenciadas nos `theme.css` com caminho relativo `../../img/...` |
| Código-fonte completo do Gamja | `ansible/usr/share/gamja/` | Vendorizado por completo (não é só CSS) — `style.css` na raiz controla o visual |
| Config do Gamja | `ansible/usr/share/gamja/config.json` (prod) / `docker/gamja.config.json` (Docker) | |

O **KiwiIRC** é distribuído como build pronto (baixado em `.zip` direto do GitHub pelo playbook/Dockerfile) — por isso só os arquivos em `static/themes/` e `static/img/` são editáveis aqui; o restante (`static/js`, `static/css/app.*.css`) vem do release oficial. Já o **Gamja** está vendorizado como código-fonte completo e precisa ser compilado (`npm run build`, via Parcel) a cada alteração.

### Como descobrir os nomes de classe certos para estilizar

Os temas do KiwiIRC sobrescrevem classes CSS de componentes Vue já compilados (não há acesso aos `.vue` originais aqui, só ao bundle minificado em `static/js/app.*.js`). Para confirmar a estrutura real do HTML antes de escrever uma regra nova:

```bash
# Procura nomes de classe relacionados a um termo (ex.: "header", "sidebar")
grep -o "kiwi-[a-zA-Z-]*header[a-zA-Z-]*" ansible/usr/share/kiwiirc/static/js/app.*.js | sort -u

# Mostra o trecho do template Vue renderizado em volta de uma classe específica
grep -o ".\{80\}kiwi-header-option-nicklist.\{120\}" ansible/usr/share/kiwiirc/static/js/app.*.js
```

Ou, mais simples: abra o DevTools do navegador (F12 → Elements) na instância local e inspecione o elemento diretamente.

### Editar e testar localmente (rebuild)

```bash
# 1. Edite os arquivos desejados, por exemplo:
#    ansible/usr/share/kiwiirc/static/themes/sdm-dark/theme.css
#    ansible/usr/share/gamja/style.css

# 2. Suba (ou reconstrua) a stack local — isso reempacota o tema do KiwiIRC
#    e recompila o Gamja (stage "gamja-builder" no docker/Dockerfile.nginx)
docker compose -f docker/docker-compose.yml up -d --build nginx

# 3. Acesse no navegador
#    KiwiIRC → http://localhost:9080
#    Gamja   → http://localhost:9081
```

> Dica: o nginx local serve `static/themes/` com `Cache-Control: no-store` (ver `docker/nginx.conf`), então um simples reload da página já reflete mudanças de CSS — só é necessário `--build` quando o **Gamja** for alterado (precisa recompilar) ou quando o container ainda não existe.

### Publicar em produção

| Cenário | Comando | O que faz |
|---|---|---|
| Só mudei CSS/tema do KiwiIRC ou arquivos de config | `./scripts/sync.sh` | `rsync` direto dos diretórios `kiwiirc/`, `gamja/` etc. para a VPS e reinicia os serviços. Mais rápido, não recompila nada. |
| Mudei código-fonte do Gamja (componentes `.js`, `style.css`) | `./scripts/ansible.sh` (playbook completo) | Reexecuta a task "Executar build do Gamja (parcel)" do `ansible/playbook.yml`, ou seja, roda `npm run build` no servidor antes de publicar |

Depois de publicar, confira em produção:

```bash
sudo systemctl status somdomato-kiwiirc nginx
curl -I https://chat.somdomato.com
```

### Reversão de alterações nos botões do header (Configurações / Informações)

Os botões de **Configurações** (engrenagem) e **Informações** (about) do header do KiwiIRC foram intencionalmente ocultados nos temas `sdm` e `sdm-dark` (eles não tinham nenhuma função útil no modo restrito/simplificado usado aqui). O botão de **Lista de usuários** foi mantido e voltou a funcionar — antes ele estava quebrado porque o painel lateral (`.kiwi-sidebar`) era escondido por completo via CSS, o que também desabilitava a lista de usuários.

Para reexibir os botões de Configurações/Informações no futuro, localize e remova o bloco abaixo em **ambos** os arquivos (`static/themes/sdm/theme.css` e `static/themes/sdm-dark/theme.css`) — ele está marcado com um comentário `REVERSÃO:`:

```css
.kiwi-header-option-settings,
.kiwi-header-option-about {
    display: none !important;
}
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

---

## 🔌 Soju IRC Bouncer + Senpai

O [soju](https://soju.im/) é um bouncer IRC moderno que mantém suas conexões com redes IRC ativas mesmo quando você está offline, com replay de histórico ao reconectar. O [senpai](https://git.sr.ht/~taiite/senpai) é um cliente IRC de terminal que integra perfeitamente com o soju.

### Arquitetura

```
senpai (terminal) → soju :6698 (bouncer) → irc.libera.chat   (nick: sistematico)
                                          → irc.somdomato.com (nick: lucas)
```

### Configuração do soju

**Localização:** `/etc/soju/config`

```
listen unix+admin:///var/run/soju/admin
listen ircs://:6698
tls /etc/soju/fullchain.pem /etc/soju/privkey.pem
hostname irc.somdomato.com
db sqlite3 /var/lib/soju/main.db
```

O Ansible gerencia o serviço (`somdomato-soju.service`) e os certificados TLS automaticamente.

### Gerenciar usuários (sojuctl)

`sojuctl` gerencia apenas **usuários** do bouncer. Redes e canais são configurados via IRC (BouncerServ).

Comandos disponíveis: `user create`, `user delete`, `user update`, `user status`, `user run`

```bash
# Criar usuário admin
/usr/local/bin/sojuctl -config /etc/soju/config user create \
  -username lucas -password 'senha-segura' -admin

# Verificar usuários existentes
/usr/local/bin/sojuctl -config /etc/soju/config user status

# Alterar senha
/usr/local/bin/sojuctl -config /etc/soju/config user update \
  -username lucas -password 'nova-senha'
```

### Configuração do senpai

**Localização:** `~/.config/senpai/senpai.scfg`

```
address  ircs://irc.somdomato.com:6698
nickname lucas
password "senha-segura"
```

O senpai autentica no soju via SASL PLAIN usando `nickname` como usuário e `password` como senha.

### Adicionar redes IRC (via BouncerServ)

Redes são gerenciadas **dentro do IRC** pelo serviço `BouncerServ`. Conecte com o senpai e execute:

```irc
# Adicionar rede Som do Mato
/msg BouncerServ network create -addr irc.somdomato.com:6697 -name somdomato

# Adicionar Libera.chat
/msg BouncerServ network create -addr irc.libera.chat:6697 -name libera

# Listar redes cadastradas
/msg BouncerServ network status

# Remover rede
/msg BouncerServ network delete somdomato
```

### Autojoin de canais

O soju lembra automaticamente dos canais em que você está. Basta entrar no canal:

```irc
/join #somdomato
```

Da próxima vez que conectar, o soju já estará no canal e entregará o histórico. Para sair permanentemente (sem rejoinar no próximo login):

```irc
/part #somdomato
```

### Autenticação SASL nas redes upstream

Para autenticar automaticamente com NickServ via SASL PLAIN:

```irc
# Libera.chat
/msg BouncerServ network update libera -sasl-mechanism PLAIN -sasl-plain-username sistematico -sasl-plain-password senha-nickserv

# Som do Mato
/msg BouncerServ network update somdomato -sasl-mechanism PLAIN -sasl-plain-username lucas -sasl-plain-password senha-nickserv
```

Para remover a autenticação SASL de uma rede:

```irc
/msg BouncerServ network update libera -sasl-mechanism none
```

### Navegação no senpai

| Tecla | Ação |
|-------|------|
| `Alt+↑` / `Alt+↓` | Navegar entre buffers (canais/redes) |
| `Ctrl+L` | Limpar tela |
| `Ctrl+C` | Fechar senpai (soju continua conectado em background) |

### Comandos úteis no senpai

```irc
# Ver todas as redes e canais
/msg BouncerServ network status

# Entrar em canal
/join #somdomato

# Ver ajuda do BouncerServ
/msg BouncerServ help
```

### Checklist soju + senpai

```bash
# 1. Serviço rodando
sudo systemctl status somdomato-soju

# 2. Porta escutando
sudo ss -tlnp | grep 6698

# 3. Usuários existentes
/usr/local/bin/sojuctl -config /etc/soju/config user status

# 4. Testar conexão TLS
openssl s_client -connect irc.somdomato.com:6698

# 5. Logs de erro
sudo journalctl -u somdomato-soju -n 50
```

---

## 💬 Ponte IRC <-> Telegram (Matterbridge)

O canal `#somdomato` (Ergo) é espelhado no grupo do Telegram
[**Som do Mato**](https://t.me/somdomato) usando o
[**Matterbridge**](https://github.com/42wim/matterbridge) — uma ponte de chat
open source em Go, ativamente mantida, leve (um único binário estático, sem
runtime/dependências) e a opção mais popular do gênero (bridge genérica
IRC/Telegram/Discord/Matrix/Slack/etc., >9k estrelas no GitHub). Mensagens
enviadas em qualquer um dos dois lados aparecem automaticamente no outro.

**Por que Matterbridge e não um bot Telegram feito à mão:** ele já implementa
os dois lados do protocolo (cliente IRC + Bot API do Telegram), reconexão
automática, formatação de nomes de usuário e é configurado só com um arquivo
TOML — sem escrever/manter código próprio de bridge.

### Arquitetura

```
Telegram (@somdomato) ⇄ Bot API ⇄ Matterbridge ⇄ IRC (nick "TelegramBridge") ⇄ Ergo (#somdomato)
```

O Matterbridge entra no canal `#somdomato` como **mais um cliente IRC comum**
(como o KiwiIRC, Gamja, The Lounge ou qualquer cliente IRC direto) — ele não
precisa de nenhuma mudança no Ergo, no WebIRC Gateway, no Nginx ou nos outros
clientes já configurados. É estritamente aditivo: se o Matterbridge cair ou
nunca for configurado, o resto da infraestrutura de chat continua funcionando
exatamente como antes.

| O quê | Onde |
|---|---|
| Dev local (Docker) — build da imagem | `docker/Dockerfile.matterbridge` (compila do source, mesmo padrão do `Dockerfile.webircgateway`) |
| Dev local (Docker) — stack opcional | `docker/docker-compose.telegram.yml` (não sobe com o `docker compose up -d` padrão) |
| Dev local (Docker) — template de config | `docker/matterbridge.docker.toml.tmpl` (renderizado pelo `docker/matterbridge-entrypoint.sh` via `envsubst`) |
| Dev local (Docker) — segredos | `docker/.env` (copiado de `docker/.env.example`, nunca versionado) |
| Produção (Ansible) — build/instalação | Tasks "MATTERBRIDGE" em `ansible/playbook.yml` (compila do source, igual ao WebIRC Gateway) |
| Produção (Ansible) — template de config | `ansible/etc/matterbridge/matterbridge.toml.j2` → `/etc/matterbridge/matterbridge.toml` (modo `0640`, dono `matterbridge`) |
| Produção (Ansible) — serviço systemd | `ansible/etc/systemd/system/somdomato-matterbridge.service` → `somdomato-matterbridge.service` |
| Produção (Ansible) — segredos | `telegram_bot_token` e `telegram_chat_id` no `ansible/group_vars/vault.yml` (Ansible Vault) |
| Canal IRC espelhado | `#somdomato` (`matterbridge_irc_channel` em `ansible/group_vars/all.yml`) |
| Grupo Telegram | [t.me/somdomato](https://t.me/somdomato) |

### Criar o bot no Telegram

1. Fale com [@BotFather](https://t.me/BotFather) e crie um bot (`/newbot`) — copie o token gerado (formato `123456:ABC-DEF...`).
2. Desative o modo privacidade do bot (senão ele só recebe comandos, não o histórico de mensagens do grupo): `/setprivacy` → escolha o bot → `Disable`.
3. Adicione o bot ao grupo [Som do Mato](https://t.me/somdomato) como membro (não precisa ser admin).
4. Descubra o `chat_id` do grupo (é um número negativo, ex: `-1001234567890`):
   - envie qualquer mensagem no grupo e acesse `https://api.telegram.org/bot<TOKEN>/getUpdates` no navegador, ou
   - adicione temporariamente o [@getidsbot](https://t.me/getidsbot) ao grupo.

### Rodar localmente (dev)

Não sobe junto com o `podman compose -f docker/docker-compose.yml up -d`
padrão — é uma stack separada, só necessária se for testar a ponte:

```bash
# 1. A stack principal já precisa estar no ar (ergo, webircgateway, etc.)
podman compose -f docker/docker-compose.yml up -d

# 2. Configurar credenciais
cp docker/.env.example docker/.env
$EDITOR docker/.env    # preencher TELEGRAM_BOT_TOKEN e TELEGRAM_CHAT_ID

# 3. Subir a ponte
podman compose -f docker/docker-compose.telegram.yml up -d --build
# ou, via Makefile (a partir da raiz do repo):
make up-telegram
```

Verifique os logs para confirmar que conectou nos dois lados:

```bash
make logs-matterbridge
# ou
podman compose -f docker/docker-compose.telegram.yml logs -f matterbridge
```

Envie uma mensagem em `#somdomato` (KiwiIRC em `http://localhost:9080`, Gamja
em `http://localhost:9081` ou qualquer cliente IRC em `localhost:6667`) e
confirme que ela aparece no grupo do Telegram, e vice-versa.

### Configurar em produção (Ansible)

O bloco "MATTERBRIDGE" do `playbook.yml` só instala/habilita o serviço se
`telegram_bot_token` **e** `telegram_chat_id` existirem no vault — sem eles,
nenhuma task relacionada ao Telegram roda, e o restante do playbook (Ergo,
KiwiIRC, Gamja, The Lounge, soju, Jitsi) não é afetado.

```bash
# 1. Adicionar as credenciais ao vault
./scripts/vault.sh edit
```

Adicione ao `vault.yml`:

```yaml
telegram_bot_token: "123456:ABC-DEF..."
telegram_chat_id: "-1001234567890"
```

```bash
# 2. Rodar o playbook normalmente
./scripts/ansible.sh
```

O Matterbridge roda como usuário de sistema dedicado (`matterbridge`, sem
shell/home) e conecta ao Ergo via `127.0.0.1:6667` (loopback) — **não abre
nenhuma porta nova no firewall**, já que ele só faz conexões de saída (para o
Ergo local e para a API do Telegram).

Verificação:

```bash
sudo systemctl status somdomato-matterbridge
sudo journalctl -u somdomato-matterbridge -n 50 -f
```

### Segurança

- O token do bot fica **só** no vault criptografado (Ansible Vault) e no
  arquivo `/etc/matterbridge/matterbridge.toml` gerado em produção, com modo
  `0640` e dono `matterbridge:matterbridge` — nunca em texto plano no
  repositório (`docker/.env` está no `.gitignore`).
- O usuário de sistema `matterbridge` roda com `NoNewPrivileges`,
  `PrivateTmp` e `ProtectSystem=strict` na unit systemd (mesma prática de
  hardening usada em `somdomato-soju.service`).
- O bot vê e retransmite **todo** o histórico do grupo do Telegram e do
  canal IRC — trate o token com o mesmo cuidado de uma senha de admin do
  grupo.

### Troubleshooting

| Sintoma | Causa provável |
|---|---|
| Container/serviço reinicia em loop | `TELEGRAM_BOT_TOKEN`/`telegram_bot_token` errado ou vazio — confira `docker/.env` (dev) ou o vault (prod) |
| Mensagens do IRC não chegam no Telegram | Bot não está no grupo, ou "Privacy Mode" ainda ativado no @BotFather (`/setprivacy` → `Disable`) |
| Mensagens do Telegram não chegam no IRC | `TELEGRAM_CHAT_ID`/`telegram_chat_id` errado — confirme que é o `chat_id` do grupo (negativo), não o `user_id` de alguém |
| `network sdm-chat-network not found` (dev) | Suba a stack principal primeiro: `podman compose -f docker/docker-compose.yml up -d` |

---

## 📜 Gerenciar Histórico do Ergo (HistServ)

O Ergo armazena histórico de mensagens por canal e por usuário. O serviço **HistServ** permite apagar histórico já gravado, enquanto a configuração em `ircd.yaml` controla se o histórico será gravado daqui em diante.

### Desativar histórico de um canal específico

**1. Apagar o histórico armazenado (HistServ):**

```irc
# Apaga todo o histórico gravado do canal (requer oper ou ser fundador do canal)
/msg HistServ FORGET #canal
```

**2. Impedir que novo histórico seja gravado no canal:**

Como IRC oper, defina o modo de histórico do canal para zero entradas:

```irc
/mode #canal +H 0:0
```

Ou via ChanServ (se o canal estiver registrado):

```irc
/msg ChanServ SET #canal HISTORY off
```

> O modo `+H <entradas>:<segundos>` controla quantas mensagens e por quanto tempo o Ergo mantém por canal. Definir `0:0` desativa o armazenamento para aquele canal.

**3. Verificar o modo de histórico atualmente ajustado no canal:**

```irc
/mode #canal
```

A resposta lista os modos ativos do canal; procure por `+H <entradas>:<segundos>` na saída (se o modo `+H` não aparecer, o canal está usando o padrão da rede, definido em `ircd.yaml`).

**4. Voltar ao padrão (remover o override e usar o valor da rede):**

```irc
/mode #canal -H
```

Isso remove o modo `+H` do canal, fazendo-o voltar a usar o limite padrão definido na seção `history` do `ircd.yaml` (veja abaixo).

### Desativar histórico para toda a rede

Edite `/usr/share/ergo/ircd.yaml` e ajuste a seção `history`:

```yaml
history:
    # Desativar completamente o armazenamento de histórico
    enabled: false
```

Ou, para manter o recurso ativo mas sem guardar nenhuma mensagem:

```yaml
history:
    enabled: true
    channel-length: 0      # Nenhuma mensagem por canal
    client-length: 0       # Nenhuma mensagem por usuário (DMs)
    query-cutoff: none     # Sem limite de busca retroativa
    persist: false         # Não persistir em disco (apenas memória)
```

Após editar, recarregue a configuração sem derrubar o servidor:

```bash
# Recarregar config em runtime (sem desconectar usuários)
sudo systemctl reload somdomato-ergo

# Ou via IRC (requer oper)
/quote REHASH
```

**Verificar a configuração de histórico atualmente ajustada:**

```bash
# Ver a seção history do arquivo de configuração em uso
grep -A 6 "^history:" /usr/share/ergo/ircd.yaml
```

**Voltar aos padrões da rede:**

Os valores padrão do Ergo para a seção `history` são:

```yaml
history:
    enabled: true
    channel-length: 2048
    client-length: 256
    autoresize-window: 7d
    autoreplay-on-join: 0
    chathistory-maxmessages: 100
    znc-maxmessages: 2048
    query-cutoff: server-time
    target-expiration:
        enabled: false
        duration: 1y
```

Restaure esses valores no `ircd.yaml` e recarregue a configuração (`systemctl reload somdomato-ergo` ou `/quote REHASH`).

### Apagar histórico de um usuário (DMs)

```irc
# Apaga todo o histórico de mensagens privadas do próprio usuário
/msg HistServ FORGET *
```

### Referência rápida do HistServ

| Comando | Efeito |
|---------|--------|
| `/msg HistServ FORGET #canal` | Apaga histórico armazenado do canal |
| `/msg HistServ FORGET *` | Apaga histórico de DMs do usuário atual |
| `/msg HistServ HELP` | Lista todos os comandos disponíveis |

---

## 📹 Conferência (Jitsi Meet self-hosted)

O KiwiIRC roda o plugin oficial [`kiwiirc/plugin-conference`](https://github.com/kiwiirc/plugin-conference),
que adiciona chamadas de áudio/vídeo direto nos canais e DMs (ícone de telefone
no header). Por trás dele, em vez do servidor público `meet.jit.si`, rodamos
nosso próprio Jitsi Meet — **instalação nativa, sem Docker** (a VPS de
produção é Oracle Linux 10 ARM e não roda Docker). Prosody, Jicofo, JVB e o
frontend web são instalados/compilados diretamente no host, replicando a
mesma lógica dos scripts `postinst` dos pacotes Debian oficiais (jicofo e
jitsi-videobridge são pacotes `arch: all` — apenas jar + scripts — e por isso
rodam em qualquer distro/arquitetura com JRE, incluindo ARM).

| O quê | Onde |
|---|---|
| Build do plugin do KiwiIRC (commit fixado) | Tasks "plugin de conferência" em `ansible/playbook.yml` (prod) / stage `conference-builder` em `docker/Dockerfile.nginx` (dev) |
| Config do plugin no KiwiIRC | Chaves `plugins` / `conference` em `ansible/etc/kiwiirc/client.json` (prod) e `docker/kiwiirc.client.json` (dev) |
| Prosody (XMPP) | Pacote `prosody` via EPEL/CRB; vhost gerado de `ansible/etc/prosody/jitsi-meet.cfg.lua.j2` |
| Jicofo / JVB | Extraídos dos `.deb` oficiais (`download.jitsi.org/stable`) em `/usr/share/jicofo` e `/usr/share/jitsi-videobridge`; units em `ansible/etc/systemd/system/jicofo.service` e `jitsi-videobridge2.service` |
| Frontend web | Compilado do source de `jitsi/jitsi-meet` (commit fixado) em `/usr/share/jitsi-meet`, igual ao Gamja |
| Vhost Nginx (prod) | `ansible/etc/nginx/sites.d/16-meet.somdomato.com.conf` — serve os estáticos e faz proxy de `/http-bind` e `/xmpp-websocket` para o Prosody local |
| Stack opcional para dev local | `docker/jitsi/` (vendorizado do `docker-jitsi-meet`, só para quem quiser testar a feature localmente — não reflete como produção roda) |
| Domínio | `meet.somdomato.com` |

### Subir o Jitsi localmente (opcional)

Não sobe junto com o `docker compose up -d` padrão do ambiente de dev — é uma
stack separada (usa Docker só localmente, não em produção), só necessária se
for testar a feature de chamada:

```bash
cd docker/jitsi
cp .env.example .env
./gen-passwords.sh
docker compose up -d
```

Acesse `http://localhost:9083` para confirmar que o Jitsi local subiu antes de
testar o ícone de chamada no KiwiIRC (`http://localhost:9080`).

### Checklist de produção

Depois de `./scripts/ansible.sh`, faltam passos **manuais** (o playbook não
gerencia registros DNS, só o desafio DNS-01 do certbot):

1. Criar o registro DNS `meet.somdomato.com` no Cloudflare apontando para o IP da VPS.
2. Confirmar a porta `10000/udp` (mídia do JVB) liberada no firewall — já incluída
   na task `firewalld` do playbook, mas confira em provedores com firewall externo
   (ex.: Security Groups/Network Security Groups da Oracle Cloud) que também
   precisa ser liberada manualmente lá.
3. Java (`java-17-openjdk-headless`), Prosody (EPEL+CRB) e o build do frontend
   (Node ≥24, já instalado pelo playbook para o Gamja) são resolvidos
   automaticamente — mas por ser uma instalação não-oficialmente-suportada
   pelo projeto Jitsi fora do Debian/Ubuntu, espere precisar depurar/ajustar
   no primeiro `./scripts/ansible.sh` real.

Verificação:

```bash
sudo systemctl status prosody jicofo jitsi-videobridge2 nginx
curl -I https://meet.somdomato.com
sudo ss -tlnp | grep 5280              # prosody (BOSH/websocket, só localhost)
sudo ss -ulnp | grep 10000             # JVB (mídia, público)
sudo journalctl -u jicofo -u jitsi-videobridge2 -n 50
```

As senhas internas do Jitsi (XMPP) são geradas uma única vez pelo playbook e
persistidas em `ansible/.secrets/jitsi/` (fora do vault, nunca versionado —
veja `.gitignore`).

### Nota de segurança

**Sem autenticação JWT por enquanto.** As salas de conferência são acessíveis
a qualquer pessoa que souber o nome do canal/DM (mesma ressalva do README
oficial do plugin) — o servidor é self-hosted, mas não há controle de quem
entra na chamada. JWT pode ser adicionado depois (exige módulo de auth no
Prosody + um endpoint para emitir tokens assinados).

---

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
