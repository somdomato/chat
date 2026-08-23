# AGENTS.md

Instruções para agentes de IA (Claude Code e similares) trabalhando neste
repositório. Leia isto antes de editar qualquer coisa em `podman/` ou
`ansible/` — este repo espelha infraestrutura que está **rodando em
produção** (chat.somdomato.com), então mudanças descuidadas afetam pessoas
reais usando o chat da rádio agora.

## O que é este repositório

Infraestrutura de chat da Rádio Som do Mato: servidor IRC ([Ergo](https://ergo.chat/))
mais três clientes web ([KiwiIRC](https://kiwiirc.com/), [Gamja](https://sr.ht/~emersion/gamja/),
[The Lounge](https://thelounge.chat/)), bouncer IRC ([soju](https://soju.im/)),
conferência de vídeo ([Jitsi Meet](https://jitsi.org/) self-hosted) e, mais
recentemente, uma ponte com o grupo do Telegram
([Matterbridge](https://github.com/42wim/matterbridge)). Faz parte do
monorepo `sdm` — este diretório (`chat/`) é o submódulo/repo linkado ao
projeto principal (`somdomato/somdomato`).

Há **dois ambientes** e o playbook/compose de cada um são independentes:

| Ambiente | Ferramenta | Onde |
|---|---|---|
| Dev local | Podman Compose | `podman/compose.yml` (+ overlays opcionais como `compose.telegram.yml`, `jitsi/compose.yml`) |
| Produção (VPS Oracle Linux, ARM) | Ansible | `ansible/playbook.yml` (sem containers — tudo nativo no host) |

Uma mudança de configuração normalmente precisa ser replicada **nos dois**
(ex.: `podman/ircd.podman.yaml` e um equivalente gerenciado pelo playbook) —
não assuma que editar um lado propaga para o outro.

**Nota de nomenclatura:** o repositório usa exclusivamente Podman (não
Docker) — imagens são `Containerfile.*` (não `Dockerfile.*`) em `podman/`
(não `docker/`), e os comandos são `podman compose ...`. Se você encontrar
`docker`/`Dockerfile`/`docker-compose` em algum lugar deste repo fora de
`FROM public.ecr.aws/docker/library/...` (registro, não a ferramenta) ou de
menções ao projeto vendorizado `docker-jitsi-meet` (nome upstream, não
renomeável), é resíduo que deveria ter sido migrado — corrija para o padrão
Podman ao encontrar.

## Regras de segurança ao mexer neste repo

1. **Nunca commite segredos.** Tokens, senhas e chaves privadas vão em
   `ansible/group_vars/vault.yml` (criptografado via `./scripts/vault.sh`) ou
   em `podman/.env` (gitignored). Antes de `git add`, confira `git status` e
   o conteúdo de qualquer arquivo novo em `podman/` ou `ansible/` que pareça
   ter credenciais.
2. **Você não tem a senha do vault.** Não tente editar
   `ansible/group_vars/vault.yml` (é AES256 criptografado — editar às cegas
   corrompe o arquivo). Se uma feature precisa de uma nova chave no vault,
   documente a chave esperada (nome + exemplo) no README e deixe o humano
   rodar `./scripts/vault.sh edit`.
3. **Novas integrações devem ser aditivas e opcionais por padrão.** Siga o
   padrão já usado por Jitsi e pela ponte Telegram: uma stack
   Podman/systemd **separada**, que só é instalada/habilitada se as
   credenciais necessárias existirem **e não estiverem vazias** — veja
   `matterbridge_enabled` (`set_fact` calculado uma vez no início do bloco
   "MATTERBRIDGE" em `ansible/playbook.yml`, usado por todas as ~14
   tasks/handler daquele bloco em vez de repetir `is defined` em cada uma —
   uma chave presente no vault mas vazia não deve contar como configurada).
   A stack nunca aparece nos comandos padrão (`podman compose up`,
   `./scripts/ansible.sh`) sem opt-in explícito. O objetivo é nunca quebrar
   o Ergo/KiwiIRC/Gamja/The Lounge que já estão em produção só por causa de
   uma feature nova — inclusive handlers de uma feature opcional devem ser
   defensivos o bastante para nunca falhar o play inteiro (veja o handler
   "Reiniciar Matterbridge": confere `stat` da unit antes de reiniciar).
4. **Valide antes de reportar sucesso:**
   - YAML: `python3 -c "import yaml; yaml.safe_load(open('arquivo.yml'))"`
     (rápido, não requer Ansible instalado nem a senha do vault).
   - `ansible-playbook ansible/playbook.yml --syntax-check` requer a senha
     do vault (`ansible/.vault_pass`) — se você não a tem, use o check YAML
     acima como substituto e avise o humano para rodar o syntax-check real.
   - Compose: `podman compose -f podman/compose.yml config` renderiza e
     valida sem subir nada.
5. **Não rode `./scripts/ansible.sh` nem qualquer comando que toque a VPS de
   produção** a menos que o usuário peça explicitamente — isso aplica mudanças
   reais no servidor ao vivo.
6. **Diretórios `working/` e `.secrets/`** contêm backup/estado real da VPS —
   trate como dado de produção, não como scratch space.

## Convenções do repositório (siga ao adicionar algo novo)

- **Serviços Go de terceiros são compilados do source**, não baixados como
  binário de release nem via imagem de terceiros — veja
  `podman/Containerfile.webircgateway` e as tasks "Compilar WebIRC Gateway" /
  "Compilar Matterbridge" em `ansible/playbook.yml` (builder Alpine + `go
  build`, ou `go build` direto no host de produção usando o Go já instalado
  pelo playbook).
- **Um serviço systemd por app**, nomeado `somdomato-<app>.service`, com
  hardening básico (`NoNewPrivileges`, `PrivateTmp`, e `ProtectSystem=strict`
  quando fizer sentido) — veja `ansible/etc/systemd/system/`.
- **Cada app roda com um usuário de sistema dedicado** (sem home/shell) —
  veja os pares `ergo_user`/`ergo_group`, `soju_user`/`soju_group`,
  `matterbridge_user`/`matterbridge_group` em `ansible/group_vars/all.yml`.
- **Templates Jinja2** para qualquer config que precise de valores do vault
  ou de `group_vars/all.yml` (`.j2` em `ansible/etc/`); configs estáticas
  ficam como arquivo puro (copiadas com `ansible.builtin.copy`).
- **Stacks Podman opcionais** (Jitsi, Telegram) usam um `compose.*.yml`
  separado, nunca incluído no `compose.yml` principal — veja
  `podman/jitsi/compose.yml` e `podman/compose.telegram.yml`.
- **Toda feature nova é documentada.** Features simples (uma seção) ficam
  direto no README.md com uma tabela "O quê | Onde" listando os arquivos
  tocados, passos para dev local, passos para produção, e uma nota de
  segurança se lidar com credenciais — veja "🔌 Soju IRC Bouncer" e
  "📹 Conferência (Jitsi Meet)" como modelo. Features maiores/com runbook
  próprio ganham um arquivo dedicado em `docs/` (ex.: `docs/TELEGRAM_BRIDGE.md`),
  com o README trazendo só um resumo curto + link — não duplique o conteúdo
  completo nos dois lugares.
- **`make deploy` é o comando único para subir/atualizar o ambiente de dev
  local** (`.env` + build + up, idempotente) — não existe um Makefile de
  monorepo em `sdm/` fora deste repo; não invente referência a um.

## Ponte IRC ↔ Telegram (Matterbridge) — mapa rápido

Adicionada para espelhar `#somdomato` (Ergo) no grupo
[t.me/somdomato](https://t.me/somdomato). Documentação completa (arquitetura,
criação do bot no @BotFather, passos de dev/produção, segurança e
troubleshooting) está em **[docs/TELEGRAM_BRIDGE.md](docs/TELEGRAM_BRIDGE.md)**.
Resumo dos arquivos:

| Arquivo | Papel |
|---|---|
| `podman/Containerfile.matterbridge` | Build da imagem (compila `42wim/matterbridge` do source) |
| `podman/matterbridge-entrypoint.sh` | Renderiza o TOML via `envsubst` a partir das env vars e inicia o binário |
| `podman/matterbridge.podman.toml.tmpl` | Template da config para dev (placeholders `${TELEGRAM_BOT_TOKEN}` / `${TELEGRAM_CHAT_ID}`) |
| `podman/compose.telegram.yml` | Stack opcional, overlay sobre `compose.yml` (rede `sdm-chat-network` externa) |
| `podman/.env.example` | Template de `podman/.env` (segredos locais, gitignored) |
| `ansible/etc/matterbridge/matterbridge.toml.j2` | Template da config de produção (usa `telegram_bot_token`/`telegram_chat_id` do vault) |
| `ansible/etc/systemd/system/somdomato-matterbridge.service` | Unit systemd de produção |
| Tasks `# ===== MATTERBRIDGE` em `ansible/playbook.yml` | Instalação/config condicionada a `telegram_bot_token`/`telegram_chat_id` definidos no vault |
| `matterbridge_user`, `matterbridge_group`, `matterbridge_irc_channel`, `app_dirs.matterbridge` em `ansible/group_vars/all.yml` | Variáveis de configuração |

Pontos a lembrar se for mexer nisso:

- O Matterbridge entra no Ergo como **cliente IRC comum** — não precisa (e
  não deve precisar) de nenhuma mudança em `ircd.podman.yaml` /
  `ansible/usr/share/ergo/ircd.yaml`.
- Em produção conecta em `127.0.0.1:6667` (loopback) — não abre porta nova
  no firewall. Se um dia precisar rodar em outro host, use TLS (`6697`) em
  vez de plaintext.
- Sem `telegram_bot_token`/`telegram_chat_id` no vault, o bloco inteiro do
  playbook é pulado — isso é intencional, não um bug.
- **Multi-grupo Telegram (bridgear `#somdomato` em mais de um grupo) está
  documentado mas NÃO implementado** — há blocos comentados como referência
  em `podman/matterbridge.podman.toml.tmpl` e
  `ansible/etc/matterbridge/matterbridge.toml.j2`, e o plano completo está em
  "Bridging para múltiplos grupos" no `docs/TELEGRAM_BRIDGE.md`. Não
  implemente isso a menos que o usuário peça explicitamente — ele ainda está
  decidindo quais grupos entram.
