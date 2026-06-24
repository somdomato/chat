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

### Webcam/conferência do Jitsi Meet trava em "loading" infinito

Esse sintoma teve **quatro causas distintas e independentes**, todas no mesmo
fluxo (conferência embutida via plugin "conference" do KiwiIRC + Jitsi Meet
self-hosted). Todas já estão corrigidas no playbook, mas documentado aqui
porque qualquer uma pode voltar a aparecer isoladamente (ex.: reinstalação
parcial, novo domínio adicionado, upgrade de versão do plugin/Jitsi).

Para diagnosticar de novo do zero, **nessa ordem**:

1. **Cliente nunca tenta conectar nada (zero atividade em jicofo/jvb/prosody
   durante a tentativa)** → o problema é no navegador, antes de qualquer rede.
   Abra o DevTools (F12 → Console) e tente de novo.
   - Erro `Uncaught DOMException: Permission denied to access property
     "__v_isRef" on cross-origin object`, geralmente em milhares de linhas
     repetidas, vindo de `external_api.js`/`plugin-conference.js`: bug do
     `kiwiirc/plugin-conference` com Vue 3. `this.api = new
     window.JitsiMeetExternalAPI(...)` é guardado numa propriedade reativa do
     Vue (`data() { return { api: null } }`); o Vue tenta observar essa
     instância recursivamente, e como ela guarda uma referência ao `Window`
     do iframe (cross-origin), toda mensagem que o iframe manda (nível de
     áudio, stats — várias por segundo) dispara o bloqueio do Firefox.
     Resultado: o evento `videoConferenceJoined` nunca dispara → loading
     infinito. Corrigido envolvendo a instância com `kiwi.Vue.markRaw()`
     (ver task "Patch: remover reatividade do Vue..." no playbook, que
     também já corrige um bug relacionado e mais antigo — `configOverwrite`/
     `interfaceConfigOverwrite` reativos sendo clonados via
     `JSON.parse(JSON.stringify(...))`).

2. **Cliente conecta e autentica via XMPP, mas o JVB nunca aparece
   disponível** → cheque `tail -f /var/log/jitsi/jvb.log` no servidor.
   - `CertificateException: ... does not authenticate
     auth.{{ domains.meet }}` em loop (e o arquivo crescendo sem parar, já
     vimos 8GB): `auth.{{ domains.meet }}` é um vhost XMPP **interno**
     (jicofo/JVB só), nunca terá certificado público válido — não tente
     emitir um para ele. Corrigido com `DISABLE_CERTIFICATE_VERIFICATION =
     true` no `jvb.conf` e `disable-certificate-verification = true` no
     `jicofo.conf` (gerados pelo playbook).
   - Se for **só** o domínio público (`{{ domains.meet }}`) que está fora do
     certificado: o certbot do playbook usa `--keep-until-expiring`, que
     **não expande** o SAN de um certificado já válido mesmo que a lista de
     `-d` tenha mudado — ele simplesmente não faz nada (ou, sem
     `--cert-name`, cria uma lineage **duplicada** sem afetar a em uso).
     Corrigido com `--cert-name {{ domains.irc }} --expand` na task
     "Obter certificados SSL para todos os domínios".

3. **JVB/jicofo conectam e ficam saudáveis, log não cresce mais, mas o
   navegador mostra `Strophe error ... "reason":"service-unavailable"
   ... "operation":"conference request (IQ)" ...
   "targetJid":"focus.{{ domains.meet }}"`**, e o `jicofo.log` não registra
   **nenhuma** tentativa (nem erro, nem sucesso) → o componente
   `Component "focus.{{ domains.meet }}" "client_proxy"` (que expõe o
   jicofo pro cliente web) depende de uma **assinatura de roster** (presence
   subscription) prévia com `focus@auth.{{ domains.meet }}`, criada pelo
   próprio `mod_client_proxy.lua` **uma única vez**, no boot do Prosody. Se o
   jicofo (Java, mais lento pra subir) ainda não tiver autenticado nesse
   exato instante, a assinatura se perde pra sempre — sem ela, todo IQ de
   criação de conferência recebe `service-unavailable` sem nunca chegar no
   jicofo. Resolvido manualmente uma vez com:
   ```bash
   prosodyctl mod_roster_command subscribe focus.{{ domains.meet }} focus@auth.{{ domains.meet }}
   ```
   e persistido no playbook (task "Assinar roster do client_proxy -> focus",
   guardada por um marker em `/etc/jitsi/.client_proxy_roster_subscribed`
   pra não reexecutar — e não reiniciar os serviços jitsi — em toda run).
   Comentário do próprio autor do `mod_roster_command.lua`: *"Used by
   Ansible to subscribe focus.\<domain\> to focus@auth.\<domain\>"*.

4. **Área do vídeo muito pequena dentro do widget de chat** (não trava,
   só visual): `viewHeight` do plugin "conference" no `client.json` do
   KiwiIRC tem default de `40%`. Ajustado para `80%`.

Pra forçar a re-checagem do passo 3 manualmente (ex.: se o roster for
apagado por algum motivo): `rm /etc/jitsi/.client_proxy_roster_subscribed`
no servidor e rode o playbook de novo — ele detecta a ausência do marker,
reassina e reinicia jicofo/jvb/prosody sozinho.

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
