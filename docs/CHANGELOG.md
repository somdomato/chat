# Mudanças Implementadas - Janeiro 2026

## 🎯 Objetivo

Modernizar a infraestrutura IRC para Oracle Linux 9 com suporte multi-distro, melhorar segurança com SELinux e simplificar a manutenção.

## ✅ Principais Alterações

### 1. Suporte Multi-Distribuição

O playbook agora detecta automaticamente o sistema operacional e ajusta comandos:

- ✅ **Oracle Linux 9** (sistema principal recomendado)
- ✅ **Rocky Linux 8/9**
- ✅ **Debian 11/12**
- ✅ **Ubuntu 20.04/22.04/24.04**

**Implementação:**
- Detecção automática via `ansible_os_family`
- Gerenciadores de pacotes: `dnf` (Red Hat) e `apt` (Debian)
- Comandos condicionais baseados na distro detectada

### 2. Configuração Automática de SELinux

Para sistemas Oracle Linux/RHEL/Rocky com SELinux em modo `Enforcing`:

- ✅ Contextos SELinux configurados para todos os diretórios
- ✅ Booleans habilitados para nginx (`httpd_can_network_connect`, `httpd_can_network_relay`)
- ✅ Tipos de arquivo corretos (`httpd_sys_content_t` para conteúdo web, `bin_t` para executáveis)
- ✅ Aplicação automática de contextos com `restorecon`

### 3. Mudanças de Diretórios

Padronização seguindo o FHS (Filesystem Hierarchy Standard):

| Componente | Diretório Antigo | Diretório Novo | Motivo |
|------------|------------------|----------------|--------|
| Ergo IRC | `/opt/ergo` | `/usr/share/ergo` | Aplicações compartilhadas |
| KiwiIRC | `/var/www/irc.somdomato.com` | `/usr/share/kiwiirc` | Padronização |
| WebIRC Gateway | N/A | `/opt/webircgateway` | Serviço local opcional |

**Arquivos atualizados:**
- `ansible/etc/nginx/sites.d/*.conf` - Ajustado `root` paths
- `ansible/etc/systemd/system/*.service` - Ajustado `WorkingDirectory`
- `ansible/group_vars/all.yml` - Variáveis `app_dirs`

### 4. Gamja - Temporariamente Desabilitado

O cliente Gamja foi comentado no playbook:

- ❌ Tarefas de build do npm comentadas
- ❌ Sincronização de arquivos desabilitada
- ❌ Configuração do nginx comentada (`51-gamja.somdomato.com.conf`)
- ❌ Domínio removido dos certificados SSL

**Motivo:** Foco no KiwiIRC como cliente principal. Gamja pode ser reabilitado futuramente removendo os comentários.

### 5. KiwiIRC - Download Automático do GitHub

Anteriormente sincronizado manualmente, agora é baixado automaticamente:

- ✅ Download da versão v1.7.1 do [GitHub releases](https://github.com/kiwiirc/kiwiirc/releases)
- ✅ Descompactação automática em `/usr/share/kiwiirc`
- ✅ Aplicação de temas personalizados após download
- ✅ Propriedades corretas para usuário nginx

**Vantagens:**
- Atualizações mais simples (basta mudar a URL da versão)
- Build oficial do projeto
- Reduz tamanho do repositório

### 6. WebIRC Gateway - Configuração Completa

Adicionadas tarefas para configurar o WebIRC Gateway:

- ✅ Criação de diretório `/opt/webircgateway`
- ✅ Cópia do binário do diretório `working/`
- ✅ Configuração em `/etc/webircgateway/config.conf`
- ✅ Serviço systemd `somdomato-webircgateway.service`
- ✅ Usuário/grupo: nginx
- ✅ Porta: 8088

**Serviço systemd:**
- Inicia após `somdomato-ergo.service`
- Restart automático em caso de falha
- Proteções de segurança (`NoNewPrivileges`, `PrivateTmp`, `ProtectSystem`)

### 7. Limpeza do Diretório scripts/

Scripts redundantes movidos para `scripts/legacy/`:

**Mantidos (essenciais):**
- ✅ `ansible.sh` - Execução principal
- ✅ `ansible-essentials.sh` - Instalação de pré-requisitos
- ✅ `vault.sh` - Gerenciamento de credenciais
- ✅ `sync.sh` - Sincronização de arquivos

**Movidos para legacy/ (depreciados):**
- `diagnose.sh`
- `fix-certificates.sh`
- `fix-nginx-conflicts.sh`
- `quick-check.sh`
- `start-services.sh`
- `test-certbot.sh`
- `test-certificates.sh`
- `test-cloudflare.sh`

**Motivo:** Funcionalidades incorporadas ao playbook Ansible ou scripts redundantes.

### 8. Documentação Atualizada

**README.md principal:**
- ✅ Instruções simplificadas e diretas
- ✅ Seção dedicada ao SELinux
- ✅ Troubleshooting expandido
- ✅ Comandos úteis organizados
- ✅ Arquitetura do sistema explicada
- ✅ Suporte multi-distro documentado

**scripts/README.md (novo):**
- ✅ Documentação de cada script
- ✅ Exemplos de uso
- ✅ Explicação dos scripts legados

## 🔧 Como Migrar de VPS Existente

Se você já tem uma VPS rodando com os diretórios antigos:

### Opção 1: Migração Manual (Recomendado para produção)

```bash
# 1. Backup completo
sudo rsync -av /opt/ergo/ /opt/ergo.backup/
sudo rsync -av /var/www/irc.somdomato.com/ /var/www/irc.somdomato.com.backup/

# 2. Parar serviços
sudo systemctl stop somdomato-ergo
sudo systemctl stop nginx

# 3. Mover arquivos
sudo mv /opt/ergo /usr/share/ergo
sudo mv /var/www/irc.somdomato.com /usr/share/kiwiirc

# 4. Atualizar SELinux (Oracle Linux)
sudo restorecon -Rv /usr/share/ergo
sudo restorecon -Rv /usr/share/kiwiirc

# 5. Atualizar configurações nginx manualmente
sudo vim /etc/nginx/sites.d/*.conf

# 6. Atualizar serviços systemd
sudo vim /etc/systemd/system/somdomato-ergo.service
sudo systemctl daemon-reload

# 7. Reiniciar
sudo systemctl start somdomato-ergo
sudo systemctl start nginx
```

### Opção 2: Reinstalação Limpa (Mais simples)

```bash
# 1. Backup de configurações importantes
scp root@vps:/usr/share/ergo/ircd.yaml ./backup/
scp root@vps:/etc/kiwiirc/client.json ./backup/

# 2. Execute o playbook (ele reconfigura tudo)
./scripts/ansible.sh

# 3. Restaure configurações personalizadas se necessário
```

## 🎯 Modo de Operação Cauteloso

Para evitar quebrar a VPS em produção, o playbook:

- ✅ Usa `creates:` em tarefas sensíveis para não sobrescrever
- ✅ Permite `refresh_apps: false` para não sincronizar arquivos
- ✅ Usa handlers para reiniciar serviços apenas quando necessário
- ✅ Testa configuração do nginx antes de reiniciar
- ✅ Falha gracefully com mensagens claras

## 📝 Próximos Passos (Opcional)

1. **Habilitar Gamja** (se desejado):
   - Descomentar linhas no playbook.yml
   - Descomentar domínio em group_vars/all.yml
   - Adicionar domínio de volta aos certificados SSL

2. **Compilar WebIRC Gateway** (se não tiver binário):
   - Adicionar tarefa para compilar do fonte
   - Instalar Go no servidor
   - Build automático

3. **Monitoramento**:
   - Adicionar Prometheus/Grafana
   - Alertas automáticos

4. **Backup Automático**:
   - Script de backup periódico
   - Upload para S3/Backblaze

## ⚠️ Avisos Importantes

1. **Testar primeiro**: Execute em ambiente de teste antes de produção
2. **Backup**: Sempre faça backup antes de mudanças
3. **SELinux**: Mantenha em modo `Enforcing` para segurança
4. **Firewall**: Configure portas corretamente
5. **DNS**: Certifique-se que registros estão corretos

## 🔗 Referências

- [Ergo IRC Documentation](https://ergo.chat/docs.html)
- [KiwiIRC GitHub](https://github.com/kiwiirc/kiwiirc)
- [SELinux User's Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/using_selinux/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

---

**Data:** 31 de Janeiro de 2026  
**Autor:** GitHub Copilot  
**Versão:** 2.0
