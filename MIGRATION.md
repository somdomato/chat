# Guia de Migração para Oracle Linux 9

## 🎯 Resumo das Mudanças

Este guia documenta as mudanças necessárias para migrar sua VPS existente para a nova estrutura.

## 📍 Mudanças de Diretórios

| Aplicação | Caminho Antigo | Caminho Novo |
|-----------|----------------|--------------|
| Ergo IRC | `/opt/ergo` | `/usr/share/ergo` |
| KiwiIRC | `/var/www/irc.somdomato.com` | `/usr/share/kiwiirc` |
| WebIRC Gateway | (novo) | `/opt/webircgateway` |

## ⚠️ IMPORTANTE: Leia Antes de Executar

**A VPS está rodando em produção.** As mudanças foram projetadas para serem minimamente invasivas:

- ✅ O playbook não sobrescreve configurações existentes automaticamente
- ✅ Handlers só reiniciam serviços quando arquivos mudam
- ✅ Validação de nginx antes de reiniciar
- ✅ Opção `refresh_apps: false` desabilita sincronização

## 🔄 Estratégias de Migração

### Opção A: Migração Gradual (RECOMENDADO)

Execute o playbook SEM mudar os diretórios primeiro, para validar:

```bash
# 1. Editar ansible/group_vars/all.yml
# Mantenha os caminhos antigos temporariamente:
app_dirs:
  ergo: "/opt/ergo"  # Mantém caminho atual
  kiwiirc: "/var/www/irc.somdomato.com"  # Mantém caminho atual
  webircgateway: "/opt/webircgateway"

# 2. Desabilitar sincronização de apps
refresh_apps: false

# 3. Executar em modo check (dry-run)
cd ansible
ansible-playbook playbook.yml -i ananke, --vault-password-file=.vault_pass --check

# 4. Se não houver erros, executar de verdade
./scripts/ansible.sh

# 5. Verificar se tudo funciona
ssh root@ananke -p 2200
sudo systemctl status somdomato-ergo
sudo systemctl status nginx
```

**Depois que validar que está tudo funcionando, faça a migração dos diretórios:**

```bash
# Na VPS
ssh root@ananke -p 2200

# Parar serviços
sudo systemctl stop somdomato-ergo
sudo systemctl stop nginx

# Backup
sudo cp -r /opt/ergo /opt/ergo.backup
sudo cp -r /var/www/irc.somdomato.com /var/www/irc.somdomato.com.backup

# Mover para novos locais
sudo mv /opt/ergo /usr/share/ergo
sudo mv /var/www/irc.somdomato.com /usr/share/kiwiirc

# Ajustar SELinux (Oracle Linux)
sudo restorecon -Rv /usr/share/ergo
sudo restorecon -Rv /usr/share/kiwiirc

# Ajustar permissões
sudo chown -R ergo:ergo /usr/share/ergo
sudo chown -R nginx:nginx /usr/share/kiwiirc
```

**Atualizar configurações locais:**

```bash
# No seu computador local
# Editar ansible/group_vars/all.yml com os caminhos novos:
app_dirs:
  ergo: "/usr/share/ergo"
  kiwiirc: "/usr/share/kiwiirc"
  webircgateway: "/opt/webircgateway"

# Executar playbook novamente para atualizar configs
./scripts/ansible.sh
```

**Na VPS, reiniciar:**

```bash
sudo systemctl daemon-reload
sudo systemctl start somdomato-ergo
sudo systemctl start somdomato-webircgateway
sudo systemctl start nginx

# Verificar logs
sudo journalctl -u somdomato-ergo -n 50
sudo journalctl -u nginx -n 50
```

### Opção B: Servidor de Teste Primeiro

Se você tem acesso a outra VPS para teste:

```bash
# 1. Configure uma VPS de teste com Oracle Linux 9
# 2. Execute o playbook completo na VPS de teste
./scripts/ansible.sh

# 3. Valide tudo na VPS de teste
# 4. Aplique na produção com confiança
```

### Opção C: Reinstalação Limpa (Menos Recomendado)

**⚠️ AVISO: Isso causará downtime**

```bash
# 1. Backup completo de TUDO
ssh root@ananke -p 2200
sudo tar -czf /root/backup-chat-$(date +%Y%m%d).tar.gz \
  /opt/ergo \
  /var/www/irc.somdomato.com \
  /etc/nginx/sites.d \
  /etc/systemd/system/somdomato-*.service \
  /etc/letsencrypt

# 2. Download do backup
scp -P 2200 root@ananke:/root/backup-chat-*.tar.gz ./

# 3. Remover instalação antiga
sudo systemctl stop somdomato-ergo nginx
sudo rm -rf /opt/ergo
sudo rm -rf /var/www/irc.somdomato.com

# 4. Executar playbook (instala tudo do zero)
./scripts/ansible.sh
```

## 🔍 Verificações Pós-Migração

### 1. Serviços

```bash
# Status
sudo systemctl status somdomato-ergo
sudo systemctl status somdomato-webircgateway
sudo systemctl status nginx

# Se algum falhou
sudo systemctl restart somdomato-ergo
sudo journalctl -u somdomato-ergo -n 50
```

### 2. Nginx

```bash
# Testar configuração
sudo nginx -t

# Se houver erro
sudo journalctl -u nginx -n 50
```

### 3. Certificados SSL

```bash
# Listar certificados
sudo certbot certificates

# Testar renovação
sudo certbot renew --dry-run
```

### 4. Conectividade

```bash
# Testar WebSocket do Ergo
curl -v http://localhost:8067/webirc

# Testar WebIRC Gateway
curl -v http://localhost:8088/

# Testar KiwiIRC
curl -I https://chat.somdomato.com
```

### 5. SELinux (Oracle Linux)

```bash
# Verificar se está em modo Enforcing
sudo getenforce

# Ver alertas (deve estar vazio)
sudo ausearch -m avc -ts recent

# Se houver alertas, aplicar contextos novamente
sudo restorecon -Rv /usr/share/ergo
sudo restorecon -Rv /usr/share/kiwiirc
sudo restorecon -Rv /opt/webircgateway
```

## 🐛 Problemas Comuns

### Erro: "Permission Denied" no Ergo

```bash
# Verificar permissões
ls -la /usr/share/ergo

# Corrigir
sudo chown -R ergo:ergo /usr/share/ergo
sudo chmod 755 /usr/share/ergo
sudo chmod 644 /usr/share/ergo/*.yaml
sudo chmod 600 /usr/share/ergo/*.pem
```

### Erro: Nginx 403 Forbidden

```bash
# Verificar permissões
ls -la /usr/share/kiwiirc

# Corrigir
sudo chown -R nginx:nginx /usr/share/kiwiirc
sudo chmod 755 /usr/share/kiwiirc
sudo restorecon -Rv /usr/share/kiwiirc  # Se Oracle Linux
```

### Erro: SELinux bloqueando

```bash
# Ver alertas
sudo ausearch -m avc -ts recent | audit2why

# Gerar política temporária (use com cautela)
sudo ausearch -m avc -ts recent | audit2allow -M mypolicy
sudo semodule -i mypolicy.pp

# Melhor: corrigir contextos
sudo restorecon -Rv /usr/share/ergo
sudo setsebool -P httpd_can_network_connect on
```

### Erro: Certificados não encontrados

```bash
# Verificar links simbólicos
ls -la /etc/letsencrypt/live/

# Recriar links se necessário
sudo ln -sf /etc/letsencrypt/live/irc.somdomato.com /etc/letsencrypt/live/chat.somdomato.com
```

## 📋 Checklist Final

- [ ] Backup completo criado
- [ ] Playbook executado sem erros
- [ ] Serviços systemd rodando
- [ ] Nginx configurado e rodando
- [ ] Certificados SSL válidos
- [ ] SELinux em modo Enforcing (Oracle Linux)
- [ ] Firewall configurado
- [ ] https://chat.somdomato.com acessível
- [ ] https://irc.somdomato.com acessível
- [ ] WebSocket conectando corretamente
- [ ] Logs sem erros críticos

## 🆘 Rollback (Se necessário)

Se algo der errado:

```bash
# 1. Parar serviços
sudo systemctl stop somdomato-ergo nginx

# 2. Restaurar backup
sudo rm -rf /usr/share/ergo /usr/share/kiwiirc
sudo tar -xzf /root/backup-chat-XXXXXXXX.tar.gz -C /

# 3. Restaurar configurações antigas
# (Use os arquivos de backup)

# 4. Reiniciar
sudo systemctl daemon-reload
sudo systemctl start somdomato-ergo nginx
```

## 📞 Suporte

Se encontrar problemas:

1. Verifique logs: `sudo journalctl -u somdomato-ergo -n 100`
2. Teste configuração: `sudo nginx -t`
3. Verifique SELinux: `sudo ausearch -m avc -ts recent`
4. Consulte [CHANGELOG.md](CHANGELOG.md) para detalhes das mudanças

---

**Boa sorte com a migração! 🚀**
