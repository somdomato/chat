# Ansible Playbook - IRC Infrastructure

Playbook Ansible para automatizar instalação e configuração do ambiente de chat IRC.

## 🎯 O que este playbook faz

1. **Detecção automática do SO**: Oracle Linux, Rocky Linux, Debian ou Ubuntu
2. **Instalação de dependências**: Nginx, Certbot, Node.js, unzip, etc.
3. **Configuração de SELinux**: Contextos e booleans (Red Hat family)
4. **Certificados SSL**: Obtém via Let's Encrypt + Cloudflare DNS
5. **Ergo IRC Server**: Sincroniza e configura em `/usr/share/ergo`
6. **KiwiIRC Client**: Baixa do GitHub e instala em `/usr/share/kiwiirc`
7. **WebIRC Gateway**: Configura em `/opt/webircgateway`
8. **Nginx**: Configura proxy reverso com SSL
9. **Systemd**: Cria e habilita serviços

## 📁 Estrutura

```
ansible/
├── playbook.yml              # Playbook principal
├── ansible.cfg               # Configurações do Ansible
├── group_vars/
│   ├── all.yml               # Variáveis globais (domínios, diretórios)
│   └── vault.yml             # Credenciais criptografadas (Cloudflare)
├── etc/                      # Arquivos de configuração
│   ├── nginx/sites.d/        # Configurações do Nginx
│   ├── systemd/system/       # Serviços systemd
│   ├── kiwiirc/              # Configurações do KiwiIRC
│   └── letsencrypt/          # Hooks de renovação SSL
└── usr/share/
    ├── ergo/                 # Arquivos do Ergo IRC
    └── kiwiirc/              # Temas personalizados do KiwiIRC
```

## 🚀 Uso

### Primeira execução

```bash
# 1. Configurar vault
../scripts/vault.sh setup
../scripts/vault.sh edit

# 2. Editar variáveis
vim group_vars/all.yml

# 3. Executar playbook
../scripts/ansible.sh

# Ou diretamente:
ansible-playbook playbook.yml -i ananke, --vault-password-file=.vault_pass
```

### Executar com tags específicas

```bash
# Apenas configuração do Nginx
ansible-playbook playbook.yml -i ananke, --vault-password-file=.vault_pass --tags nginx

# Apenas certificados SSL
ansible-playbook playbook.yml -i ananke, --vault-password-file=.vault_pass --tags ssl

# Apenas serviços systemd
ansible-playbook playbook.yml -i ananke, --vault-password-file=.vault_pass --tags systemd
```

### Modo dry-run (check)

```bash
# Ver o que seria alterado sem executar
ansible-playbook playbook.yml -i ananke, --vault-password-file=.vault_pass --check
```

### Modo verbose (debug)

```bash
# Saída detalhada
ansible-playbook playbook.yml -i ananke, --vault-password-file=.vault_pass -vvv
```

## ⚙️ Variáveis

### group_vars/all.yml

```yaml
# Domínios
domains:
  irc: "irc.somdomato.com"
  chat: "chat.somdomato.com"

# Diretórios
app_dirs:
  ergo: "/usr/share/ergo"
  kiwiirc: "/usr/share/kiwiirc"
  webircgateway: "/opt/webircgateway"

# Email para Let's Encrypt
letsencrypt_email: "seu_email@dominio.com"

# Configurações SSH
ansible_port: 2200
ansible_user: root

# Controle de sincronização
refresh_apps: true  # false para não sincronizar arquivos
```

### group_vars/vault.yml (criptografado)

```yaml
# Credenciais do Cloudflare (modo legacy)
cloudflare_email: "seu_email@cloudflare.com"
cloudflare_api_key: "sua_global_api_key"
```

## 🔐 Ansible Vault

```bash
# Editar vault
ansible-vault edit group_vars/vault.yml --vault-password-file=.vault_pass

# Ou usar o script auxiliar
../scripts/vault.sh edit
```

## 🏗️ Componentes Instalados

### Ergo IRC Server
- **Diretório**: `/usr/share/ergo`
- **Configuração**: `/usr/share/ergo/ircd.yaml`
- **Serviço**: `somdomato-ergo.service`
- **Portas**: 6667 (IRC), 6697 (IRC+SSL), 8067 (WebSocket)
- **Usuário**: `ergo`

### KiwiIRC Client
- **Diretório**: `/usr/share/kiwiirc`
- **Configuração**: `/etc/kiwiirc/client.json`
- **URL**: https://chat.somdomato.com
- **Usuário**: `nginx`
- **Versão**: v1.7.1 (do GitHub releases)

### WebIRC Gateway
- **Diretório**: `/opt/webircgateway`
- **Configuração**: `/etc/webircgateway/config.conf`
- **Serviço**: `somdomato-webircgateway.service`
- **Porta**: 8088
- **Usuário**: `nginx`

### Nginx
- **Configurações**: `/etc/nginx/sites.d/`
- **Certificados**: `/etc/letsencrypt/live/`
- **Logs**: `/var/log/nginx/`

## 🔧 Handlers

Handlers são executados automaticamente quando arquivos mudam:

- **Reiniciar Nginx**: Testa configuração antes de reiniciar
- **Reiniciar serviços**: Recarrega daemon e reinicia serviços IRC

## 🎛️ Características do Playbook

### Multi-Distro Support

Detecta automaticamente e ajusta comandos para:
- Oracle Linux 9
- Rocky Linux 8/9
- Debian 11/12
- Ubuntu 20.04/22.04/24.04

### SELinux Support

Para Red Hat family (Oracle Linux, Rocky, RHEL):
- Configura contextos automaticamente
- Habilita booleans necessários
- Aplica `restorecon` em diretórios

### Idempotência

O playbook é idempotente - pode ser executado múltiplas vezes sem efeitos colaterais:
- Usa `creates:` em tarefas de download/compilação
- Handlers só executam se houver mudanças
- Testa antes de aplicar alterações críticas

### Segurança

- Credenciais em vault criptografado
- SELinux em modo Enforcing
- Usuários dedicados (ergo, nginx)
- Proteções systemd (NoNewPrivileges, PrivateTmp)

## 🐛 Troubleshooting

### Playbook falha na obtenção de certificados

```bash
# Verificar credenciais do Cloudflare
../scripts/vault.sh view

# Testar manualmente no servidor
ssh root@ananke -p 2200
sudo certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
  -d irc.somdomato.com --dry-run
```

### Playbook falha no nginx

```bash
# Verificar configuração
ssh root@ananke -p 2200
sudo nginx -t
```

### Playbook falha no Node.js

O playbook pula a instalação do Node.js se já estiver funcional. Se falhar:

```bash
# No servidor
ssh root@ananke -p 2200
node --version
npm --version

# Se não funcionar, instalar manualmente
sudo dnf install nodejs  # Oracle Linux
# ou
sudo apt install nodejs  # Debian/Ubuntu
```

### Falha de permissão SELinux

```bash
# Ver alertas
sudo ausearch -m avc -ts recent

# Reaplicar contextos
sudo restorecon -Rv /usr/share/ergo
sudo restorecon -Rv /usr/share/kiwiirc
sudo restorecon -Rv /opt/webircgateway
```

## 📝 Notas

### Gamja (Desabilitado)

O cliente Gamja está comentado no playbook. Para reabilitar:
1. Descomentar linhas no playbook.yml
2. Adicionar domínio em group_vars/all.yml
3. Descomentar `51-gamja.somdomato.com.conf` na cópia do nginx

### KiwiIRC - Atualização de Versão

Para usar outra versão do KiwiIRC, edite a URL em playbook.yml:

```yaml
- name: Baixar KiwiIRC v1.7.1 do GitHub
  ansible.builtin.get_url:
    url: https://github.com/kiwiirc/kiwiirc/releases/download/v1.7.1/kiwiirc-client_v1.7.1-2_any.zip
    # Mude para a versão desejada ^^^
```

### Modo de Produção

Para executar em produção sem quebrar a VPS:

```yaml
# group_vars/all.yml
refresh_apps: false  # Não sincronizar arquivos da aplicação
```

Isso faz o playbook pular a sincronização de arquivos, útil para:
- Atualizar apenas configurações do nginx
- Renovar certificados
- Ajustar serviços systemd
- Sem risco de sobrescrever código em produção

## 🔗 Referências

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [SELinux User's Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/using_selinux/)

---

Para mais informações, consulte:
- [../README.md](../README.md) - Documentação principal
- [../CHANGELOG.md](../CHANGELOG.md) - Histórico de mudanças
- [../MIGRATION.md](../MIGRATION.md) - Guia de migração
