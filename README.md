# 🎧 Rádio Som do Mato (CHAT)

![Rádio Som do Mato](https://raw.githubusercontent.com/somdomato/somdomato/refs/heads/main/public/images/logo.svg "Rádio Som do Mato")

Streaming de audio para as massas.

| sistema | url | descrição | 
| :--- | :---: | ---: |
| [Site](https://github.com/somdomato/somdomato) | [somdomato.com](https://somdomato.com) | |
| [Stream](https://github.com/somdomato/stream) | [radio.somdomato.com](https://radio.somdomato.com) | Arquivos de configuração do Icecast e Liquidsoap |
| Chat | [chat.somdomato.com](https://chat.somdomato.com) | Arquivos de configuração do bate-papo usando IRC(Ergo, Gamja & KiwiIRC)  |
| [Podman](https://github.com/somdomato/podman) | - | Imagens e contêineres do [Podman](https://podman.io) para desenvolvimento local. |

## 🚀 Instalação Automatizada com Ansible

Este projeto utiliza Ansible para automatizar a instalação e configuração do ambiente de chat IRC. O processo inclui:

- ✅ Instalação automática de certificados SSL via Let's Encrypt + Cloudflare DNS
- ✅ Configuração do servidor IRC (Ergo)
- ✅ Setup do cliente web Gamja
- ✅ Configuração do KiwiIRC
- ✅ Configuração do Nginx
- ✅ Gerenciamento de serviços systemd

### 📋 Pré-requisitos

1. **Ansible** instalado na máquina local
2. **Token da API do Cloudflare** para DNS challenge
3. **Acesso SSH** ao servidor de destino

### 🔐 Configuração do Ansible Vault

O projeto usa Ansible Vault para armazenar credenciais sensíveis de forma segura.

#### 1. Configuração inicial do vault

```bash
# Executar configuração inicial (primeira vez)
./scripts/vault.sh setup
```

Será solicitado:
- Uma senha para o vault (guarde com segurança!)
- O arquivo `group_vars/vault.yml` será criptografado automaticamente

#### 2. Editar variáveis sensíveis

```bash
# Editar o vault com suas credenciais
./scripts/vault.sh edit
```

Configure no vault:
```yaml
# Token da API do Cloudflare para DNS challenge
cloudflare_api_token: "seu_token_cloudflare_aqui"

# Email do Cloudflare (opcional)
cloudflare_email: "seu_email@dominio.com"
```

#### 3. Outros comandos do vault

```bash
# Visualizar conteúdo do vault
./scripts/vault.sh view

# Alterar senha do vault
./scripts/vault.sh rekey

# Criptografar arquivo vault
./scripts/vault.sh encrypt

# Descriptografar arquivo vault
./scripts/vault.sh decrypt
```

### ⚙️ Configuração das Variáveis

As variáveis globais estão em `ansible/group_vars/all.yml`:

```yaml
# Domínios (ajuste conforme necessário)
domains:
  irc: "irc.somdomato.com"
  gamja: "gamja.somdomato.com" 
  chat: "chat.somdomato.com"

# Email para Let's Encrypt
letsencrypt_email: "admin@somdomato.com"

# Configurações SSH
ansible_port: 2200
ansible_user: root
```

### 🎯 Como obter as Credenciais do Cloudflare (Modo Legacy)

1. Acesse [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Vá em **My Profile** → **API Tokens**
3. Na seção **API Keys**, clique em **View** na **Global API Key**
4. Confirme sua senha e copie a API Key
5. Use seu email de login do Cloudflare + a Global API Key

### 🧪 Testando as Credenciais do Cloudflare

```bash
# Testar se as credenciais estão funcionando
./scripts/test-cloudflare.sh
```

Este script vai:
- ✅ Verificar se email e API key estão no vault
- ✅ Testar conectividade com a API do Cloudflare
- ✅ Mostrar informações do usuário
- ❌ Indicar problemas se houver

### 🚀 Executando o Playbook

```bash
# Executar a instalação completa
./scripts/ansible.sh
```

O script irá:
1. ✅ Verificar se o vault está configurado
2. ✅ Instalar dependências (certbot, nginx, nodejs, etc.)
3. ✅ Obter certificados SSL via Cloudflare DNS challenge
4. ✅ Sincronizar arquivos de configuração
5. ✅ Configurar usuários e permissões
6. ✅ Iniciar e habilitar serviços

### 📁 Estrutura do Projeto

```
ansible/
├── ansible.cfg              # Configurações do Ansible
├── playbook.yml             # Playbook principal
├── group_vars/
│   ├── all.yml              # Variáveis globais
│   └── vault.yml            # Variáveis criptografadas (vault)
└── .vault_pass              # Senha do vault (criada automaticamente)

scripts/
├── ansible.sh               # Script principal de execução
└── vault.sh                 # Gerenciador do vault
```

### 🔧 Troubleshooting

#### Erro: "Arquivo de senha do vault não encontrado"
```bash
# Execute a configuração inicial
./scripts/vault.sh setup
```

#### Erro: "Error determining zone_id: 6003 Invalid request headers"
- ✅ **Causa**: Credenciais do Cloudflare inválidas ou com permissões insuficientes
- 🔧 **Solução**: 
  ```bash
  # 1. Teste as credenciais
  ./scripts/test-cloudflare.sh
  
  # 2. Se inválidas, reconfigure
  ./scripts/vault.sh edit
  
  # 3. Certifique-se de usar:
  #    - Email: seu email de login do Cloudflare
  #    - API Key: Global API Key (não token personalizado)
  ```

#### Erro: "Source /etc/letsencrypt/live/domain/fullchain.pem not found"
- ✅ **Resolvido!** O playbook agora obtém os certificados automaticamente via Cloudflare
- Certifique-se de que o token do Cloudflare está correto no vault

#### Erro: "Erro ao acessar o vault"
```bash
# Verifique se o vault está configurado
./scripts/vault.sh view

# Se necessário, reconfigure
./scripts/vault.sh setup
```

#### Debug do playbook
```bash
# Executar em modo verbose
cd ansible
ansible-playbook playbook.yml -i ananke, --vault-password-file=.vault_pass -vvv
```

### 📝 Logs e Monitoramento

Após a instalação, verifique os serviços:

```bash
# Status dos serviços
systemctl status somdomato-ergo.service
systemctl status somdomato-kiwiirc.service
systemctl status nginx

# Logs dos serviços
journalctl -u somdomato-ergo.service -f
journalctl -u somdomato-kiwiirc.service -f
```

### 🔄 Renovação de Certificados

Os certificados serão renovados automaticamente pelo certbot. O hook de deployment está configurado em:
- `/etc/letsencrypt/renewal-hooks/deploy/install-ergo-certificates`

---

## 📚 Instalação Manual (Método Antigo)

<details>
<summary>Clique para ver o método manual (não recomendado)</summary>

Crie o arquivo `/etc/cloudflare.ini`:
```conf
dns_cloudflare_email   = SEU_EMAIL
dns_cloudflare_api_key = SEU_TOKEN
```

Crie os certificados necessários:

```bash
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/cloudflare.ini -d irc.somdomato.com
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/cloudflare.ini -d chat.somdomato.com
```

</details>
