# AGENTS.md

Instruções para agentes de IA (Claude Code e similares) trabalhando neste
repositório. Leia isto antes de editar qualquer coisa em `docker/` ou
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
| Dev local | Docker/Podman Compose | `docker/docker-compose.yml` (+ overlays opcionais como `docker-compose.telegram.yml`, `jitsi/docker-compose.yml`) |
| Produção (VPS Oracle Linux, ARM) | Ansible | `ansible/playbook.yml` (sem Docker — tudo nativo no host) |

Uma mudança de configuração normalmente precisa ser replicada **nos dois**
(ex.: `docker/ircd.docker.yaml` e um equivalente gerenciado pelo playbook) —
não assuma que editar um lado propaga para o outro.

## Regras de segurança ao mexer neste repo

1. **Nunca commite segredos.** Tokens, senhas e chaves privadas vão em
   `ansible/group_vars/vault.yml` (criptografado via `./scripts/vault.sh`) ou
   em `docker/.env` (gitignored). Antes de `git add`, confira `git status` e
   o conteúdo de qualquer arquivo novo em `docker/` ou `ansible/` que pareça
   ter credenciais.
2. **Você não tem a senha do vault.** Não tente editar
   `ansible/group_vars/vault.yml` (é AES256 criptografado — editar às cegas
   corrompe o arquivo). Se uma feature precisa de uma nova chave no vault,
   documente a chave esperada (nome + exemplo) no README e deixe o humano
   rodar `./scripts/vault.sh edit`.
3. **Novas integrações devem ser aditivas e opcionais por padrão.** Siga o
   padrão já usado por Jitsi e pela ponte Telegram: uma stack
   Docker/systemd **separada**, que só é instalada/habilitada se as
   credenciais necessárias existirem (`when: telegram_bot_token is defined
   and telegram_chat_id is defined` no playbook), e que nunca aparece nos
   comandos padrão (`docker compose up`, `./scripts/ansible.sh`) sem opt-in
   explícito. O objetivo é nunca quebrar o Ergo/KiwiIRC/Gamja/The Lounge que
   já estão em produção só por causa de uma feature nova.
4. **Valide antes de reportar sucesso:**
   - YAML: `python3 -c "import yaml; yaml.safe_load(open('arquivo.yml'))"`
     (rápido, não requer Ansible instalado nem a senha do vault).
   - `ansible-playbook ansible/playbook.yml --syntax-check` requer a senha
     do vault (`ansible/.vault_pass`) — se você não a tem, use o check YAML
     acima como substituto e avise o humano para rodar o syntax-check real.
   - Compose: `podman compose -f docker/docker-compose.yml config` (ou
     `docker compose ... config`) renderiza e valida sem subir nada.
5. **Não rode `./scripts/ansible.sh` nem qualquer comando que toque a VPS de
   produção** a menos que o usuário peça explicitamente — isso aplica mudanças
   reais no servidor ao vivo.
6. **Diretórios `working/` e `.secrets/`** contêm backup/estado real da VPS —
   trate como dado de produção, não como scratch space.

## Convenções do repositório (siga ao adicionar algo novo)

- **Serviços Go de terceiros são compilados do source**, não baixados como
  binário de release nem via imagem Docker de terceiros — veja
  `docker/Dockerfile.webircgateway` e as tasks "Compilar WebIRC Gateway" /
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
- **Stacks Docker opcionais** (Jitsi, Telegram) usam um `docker-compose.*.yml`
  separado, nunca incluído no `docker-compose.yml` principal — veja
  `docker/jitsi/docker-compose.yml` e `docker/docker-compose.telegram.yml`.
- **Toda feature nova é documentada no README.md** com: uma tabela "O quê |
  Onde" listando os arquivos tocados, passos para dev local, passos para
  produção, e uma nota de segurança se lidar com credenciais — veja as
  seções "🔌 Soju IRC Bouncer", "📹 Conferência (Jitsi Meet)" e "💬 Ponte IRC
  <-> Telegram (Matterbridge)" como modelo.

## Ponte IRC ↔ Telegram (Matterbridge) — mapa rápido

Adicionada para espelhar `#somdomato` (Ergo) no grupo
[t.me/somdomato](https://t.me/somdomato). Detalhes completos, incluindo
como criar o bot no @BotFather e obter o `chat_id`, estão no README em
"💬 Ponte IRC <-> Telegram (Matterbridge)". Resumo dos arquivos:

| Arquivo | Papel |
|---|---|
| `docker/Dockerfile.matterbridge` | Build da imagem (compila `42wim/matterbridge` do source) |
| `docker/matterbridge-entrypoint.sh` | Renderiza o TOML via `envsubst` a partir das env vars e inicia o binário |
| `docker/matterbridge.docker.toml.tmpl` | Template da config para dev (placeholders `${TELEGRAM_BOT_TOKEN}` / `${TELEGRAM_CHAT_ID}`) |
| `docker/docker-compose.telegram.yml` | Stack opcional, overlay sobre `docker-compose.yml` (rede `sdm-chat-network` externa) |
| `docker/.env.example` | Template de `docker/.env` (segredos locais, gitignored) |
| `ansible/etc/matterbridge/matterbridge.toml.j2` | Template da config de produção (usa `telegram_bot_token`/`telegram_chat_id` do vault) |
| `ansible/etc/systemd/system/somdomato-matterbridge.service` | Unit systemd de produção |
| Tasks `# ===== MATTERBRIDGE` em `ansible/playbook.yml` | Instalação/config condicionada a `telegram_bot_token`/`telegram_chat_id` definidos no vault |
| `matterbridge_user`, `matterbridge_group`, `matterbridge_irc_channel`, `app_dirs.matterbridge` em `ansible/group_vars/all.yml` | Variáveis de configuração |

Pontos a lembrar se for mexer nisso:

- O Matterbridge entra no Ergo como **cliente IRC comum** — não precisa (e
  não deve precisar) de nenhuma mudança em `ircd.docker.yaml` /
  `ansible/usr/share/ergo/ircd.yaml`.
- Em produção conecta em `127.0.0.1:6667` (loopback) — não abre porta nova
  no firewall. Se um dia precisar rodar em outro host, use TLS (`6697`) em
  vez de plaintext.
- Sem `telegram_bot_token`/`telegram_chat_id` no vault, o bloco inteiro do
  playbook é pulado — isso é intencional, não um bug.
