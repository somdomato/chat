# Scripts de Gerenciamento

Scripts essenciais para gerenciar o projeto de IRC.

## Scripts Ativos

### ansible.sh
Script principal para executar o playbook Ansible. Automatiza a instalação e configuração de todos os componentes.

**Uso:**
```bash
./scripts/ansible.sh
```

### ansible-essentials.sh  
Instala os pré-requisitos necessários para executar o Ansible.

**Uso:**
```bash
./scripts/ansible-essentials.sh
```

### vault.sh
Gerencia o Ansible Vault para credenciais sensíveis (API keys, senhas, etc).

**Comandos disponíveis:**
```bash
./scripts/vault.sh edit      # Editar credenciais
./scripts/vault.sh view      # Visualizar credenciais
./scripts/vault.sh encrypt   # Criptografar vault
./scripts/vault.sh decrypt   # Descriptografar vault
./scripts/vault.sh setup     # Configuração inicial
./scripts/vault.sh rekey     # Alterar senha do vault
```

### sync.sh
Sincroniza arquivos locais com o servidor remoto (útil durante desenvolvimento).

**Uso:**
```bash
./scripts/sync.sh
```

## Scripts Legados

Scripts antigos movidos para `legacy/` por serem redundantes ou desnecessários com o novo setup:

- `diagnose.sh` - Diagnósticos gerais (funcionalidade incorporada ao playbook)
- `fix-certificates.sh` - Correção de certificados (gerenciado pelo playbook)
- `fix-nginx-conflicts.sh` - Correção do nginx (gerenciado pelo playbook)
- `quick-check.sh` - Checagem rápida (use o playbook com tags específicas)
- `start-services.sh` - Iniciar serviços (use systemctl diretamente)
- `test-certbot.sh` - Teste do certbot (incorporado ao playbook)
- `test-certificates.sh` - Teste de certificados (incorporado ao playbook)
- `test-cloudflare.sh` - Teste da API Cloudflare (incorporado ao playbook)

## Gerenciamento de Serviços

Para gerenciar os serviços diretamente no servidor:

```bash
# Verificar status
sudo systemctl status somdomato-ergo
sudo systemctl status somdomato-webircgateway
sudo systemctl status nginx

# Reiniciar serviços
sudo systemctl restart somdomato-ergo
sudo systemctl restart somdomato-webircgateway
sudo systemctl restart nginx

# Ver logs
sudo journalctl -u somdomato-ergo -f
sudo journalctl -u somdomato-webircgateway -f
sudo journalctl -u nginx -f
```
