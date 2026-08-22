# Ponte IRC ↔ Telegram (Matterbridge)

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

## Arquitetura

```
Telegram (@somdomato) ⇄ Bot API ⇄ Matterbridge ⇄ IRC (nick "TelegramBridge") ⇄ Ergo (#somdomato)
```

O Matterbridge entra no canal `#somdomato` como **mais um cliente IRC comum**
(como o KiwiIRC, Gamja, The Lounge ou qualquer cliente IRC direto) — ele não
precisa de nenhuma mudança no Ergo, no WebIRC Gateway, no Nginx ou nos outros
clientes já configurados. É estritamente aditivo: se o Matterbridge cair ou
nunca for configurado, o resto da infraestrutura de chat continua funcionando
exatamente como antes.

Em ambos os ambientes (dev e produção) a instalação/habilitação da ponte é
**condicional às credenciais existirem** — sem elas, nenhuma peça relacionada
ao Telegram é tocada:

- **Dev (Podman):** vive num `compose.telegram.yml` separado, que só sobe com
  comando explícito (nunca junto do `podman compose up` padrão).
- **Produção (Ansible):** o bloco inteiro de tasks só roda se
  `telegram_bot_token` **e** `telegram_chat_id` existirem no vault.

## Mapa de arquivos

| O quê | Onde |
|---|---|
| Dev local (Podman) — build da imagem | `podman/Containerfile.matterbridge` (compila `42wim/matterbridge` do source, mesmo padrão do `Containerfile.webircgateway`) |
| Dev local (Podman) — stack opcional | `podman/compose.telegram.yml` (overlay sobre `compose.yml`, rede `sdm-chat-network` externa) |
| Dev local (Podman) — template de config | `podman/matterbridge.podman.toml.tmpl` (renderizado pelo `podman/matterbridge-entrypoint.sh` via `envsubst`) |
| Dev local (Podman) — segredos | `podman/.env` (copiado de `podman/.env.example`, nunca versionado — está no `.gitignore`) |
| Produção (Ansible) — build/instalação | Tasks `# ===== MATTERBRIDGE` em `ansible/playbook.yml` (compila do source, igual ao WebIRC Gateway, usando o Go já instalado pelo playbook) |
| Produção (Ansible) — template de config | `ansible/etc/matterbridge/matterbridge.toml.j2` → `/etc/matterbridge/matterbridge.toml` (modo `0640`, dono `matterbridge:matterbridge`) |
| Produção (Ansible) — serviço systemd | `ansible/etc/systemd/system/somdomato-matterbridge.service` → `somdomato-matterbridge.service` |
| Produção (Ansible) — segredos | `telegram_bot_token` e `telegram_chat_id` no `ansible/group_vars/vault.yml` (Ansible Vault) |
| Produção (Ansible) — variáveis | `matterbridge_user`, `matterbridge_group`, `matterbridge_irc_channel`, `app_dirs.matterbridge` em `ansible/group_vars/all.yml` |
| Canal IRC espelhado | `#somdomato` |
| Grupo Telegram | [t.me/somdomato](https://t.me/somdomato) |

## Criar o bot no Telegram

1. Fale com [@BotFather](https://t.me/BotFather) e crie um bot (`/newbot`) — copie o token gerado (formato `123456:ABC-DEF...`).
2. Desative o modo privacidade do bot (senão ele só recebe comandos, não o histórico de mensagens do grupo): `/setprivacy` → escolha o bot → `Disable`.
3. Adicione o bot ao grupo [Som do Mato](https://t.me/somdomato) como membro (não precisa ser admin).
4. Descubra o `chat_id` do grupo (é um número negativo, ex: `-1001234567890`):
   - envie qualquer mensagem no grupo e acesse `https://api.telegram.org/bot<TOKEN>/getUpdates` no navegador, ou
   - adicione temporariamente o [@getidsbot](https://t.me/getidsbot) ao grupo.

## Configurar em dev local (Podman)

Não sobe junto com `make deploy` / `podman compose -f podman/compose.yml up -d`
padrão — é uma stack separada, só necessária se for testar a ponte:

```bash
# 1. A stack principal já precisa estar no ar
make deploy
# (ou: podman compose -f podman/compose.yml up -d)

# 2. Configurar credenciais
cp podman/.env.example podman/.env
$EDITOR podman/.env    # preencher TELEGRAM_BOT_TOKEN e TELEGRAM_CHAT_ID

# 3. Subir a ponte
podman compose -f podman/compose.telegram.yml up -d --build
# ou, via Makefile (a partir da raiz do repo):
make up-telegram
```

Verifique os logs para confirmar que conectou nos dois lados:

```bash
make logs-matterbridge
# ou
podman compose -f podman/compose.telegram.yml logs -f matterbridge
```

Envie uma mensagem em `#somdomato` (KiwiIRC em `http://localhost:9080`, Gamja
em `http://localhost:9081` ou qualquer cliente IRC em `localhost:6667`) e
confirme que ela aparece no grupo do Telegram, e vice-versa.

Outros alvos úteis do Makefile:

```bash
make down-telegram          # para e remove o container da ponte
make build-matterbridge     # reconstrói a imagem depois de mudar o template/config
make matterbridge-shell     # shell dentro do container
make matterbridge-restart   # reinicia só o container matterbridge
```

### Como o template é renderizado (dev)

`podman/matterbridge-entrypoint.sh` roda no `ENTRYPOINT` do container: pega
`podman/matterbridge.podman.toml.tmpl`, substitui `${TELEGRAM_BOT_TOKEN}` e
`${TELEGRAM_CHAT_ID}` pelas variáveis de ambiente (vindas de `podman/.env`
via `compose.telegram.yml`) usando `envsubst`, escreve o resultado em
`/opt/matterbridge/matterbridge.toml` dentro do container, e só então inicia
o binário. O `.toml` final nunca é versionado — só o `.tmpl` com os
placeholders.

## Configurar em produção (Ansible)

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

O que o playbook faz (resumo das tasks em `ansible/playbook.yml`):

1. Cria o grupo e o usuário de sistema `matterbridge` (sem shell/home).
2. Clona `github.com/42wim/matterbridge` em `/tmp/matterbridge_build` e
   compila com `go build` (Go já vem instalado pelo playbook para o WebIRC
   Gateway) — só recompila se o binário ainda não existir em
   `/opt/matterbridge/matterbridge`.
3. Instala o binário em `/opt/matterbridge/matterbridge`.
4. Renderiza `ansible/etc/matterbridge/matterbridge.toml.j2` →
   `/etc/matterbridge/matterbridge.toml` (modo `0640`, dono
   `matterbridge:matterbridge`), preenchendo `telegram_bot_token` e
   `telegram_chat_id` a partir do vault.
5. Copia `ansible/etc/systemd/system/somdomato-matterbridge.service` e
   habilita/inicia o serviço.

O Matterbridge roda como usuário de sistema dedicado (`matterbridge`, sem
shell/home) e conecta ao Ergo via `127.0.0.1:6667` (loopback) — **não abre
nenhuma porta nova no firewall**, já que ele só faz conexões de saída (para o
Ergo local e para a API do Telegram).

Verificação:

```bash
sudo systemctl status somdomato-matterbridge
sudo journalctl -u somdomato-matterbridge -n 50 -f
```

### Atualizar/reconfigurar

Trocar o token, o `chat_id` ou o canal IRC espelhado:

```bash
./scripts/vault.sh edit     # editar telegram_bot_token / telegram_chat_id
# matterbridge_irc_channel fica em ansible/group_vars/all.yml (texto plano)
./scripts/ansible.sh
```

O template `matterbridge.toml.j2` é reaplicado e o serviço reinicia
automaticamente (handler `Reiniciar Matterbridge`) só quando o arquivo de
config ou a unit systemd mudam.

## Segurança

- O token do bot fica **só** no vault criptografado (Ansible Vault) e no
  arquivo `/etc/matterbridge/matterbridge.toml` gerado em produção, com modo
  `0640` e dono `matterbridge:matterbridge` — nunca em texto plano no
  repositório (`podman/.env` está no `.gitignore`).
- O usuário de sistema `matterbridge` roda com `NoNewPrivileges`,
  `PrivateTmp` e `ProtectSystem=strict` na unit systemd (mesma prática de
  hardening usada em `somdomato-soju.service`).
- O bot vê e retransmite **todo** o histórico do grupo do Telegram e do
  canal IRC — trate o token com o mesmo cuidado de uma senha de admin do
  grupo.
- Sem porta nova exposta: a conexão com o Ergo é sempre via loopback
  (`127.0.0.1:6667`) em produção, ou via rede interna do Podman em dev.

## Troubleshooting

| Sintoma | Causa provável |
|---|---|
| Container/serviço reinicia em loop | `TELEGRAM_BOT_TOKEN`/`telegram_bot_token` errado ou vazio — confira `podman/.env` (dev) ou o vault (prod) |
| Mensagens do IRC não chegam no Telegram | Bot não está no grupo, ou "Privacy Mode" ainda ativado no @BotFather (`/setprivacy` → `Disable`) |
| Mensagens do Telegram não chegam no IRC | `TELEGRAM_CHAT_ID`/`telegram_chat_id` errado — confirme que é o `chat_id` do grupo (negativo), não o `user_id` de alguém |
| `network sdm-chat-network not found` (dev) | Suba a stack principal primeiro: `make deploy` |
| Task "MATTERBRIDGE" pulada no playbook (nada acontece) | Esperado se `telegram_bot_token`/`telegram_chat_id` não estiverem no vault — rode `./scripts/vault.sh edit` |
| `somdomato-matterbridge` não inicia em produção | `sudo journalctl -u somdomato-matterbridge -n 50` — geralmente token/chat_id inválido ou Ergo (`127.0.0.1:6667`) fora do ar |

## Referências

- [Matterbridge](https://github.com/42wim/matterbridge) — projeto upstream
- [Documentação de configuração do Matterbridge](https://github.com/42wim/matterbridge/blob/master/matterbridge.toml.sample) — todas as opções TOML disponíveis (só um subconjunto é usado aqui)
- [t.me/somdomato](https://t.me/somdomato) — grupo Telegram espelhado
- Seção ["💬 Ponte IRC ↔ Telegram" no README.md](../README.md#-ponte-irc---telegram-matterbridge) — resumo rápido com link para este documento
