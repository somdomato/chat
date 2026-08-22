#!/bin/sh
# Renderiza o template TOML substituindo ${TELEGRAM_BOT_TOKEN} e
# ${TELEGRAM_CHAT_ID} pelas variáveis de ambiente do container (definidas via
# podman/.env) e então inicia o Matterbridge. Isso evita gravar segredos
# diretamente no arquivo de configuração versionado.
set -eu

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
    echo "[matterbridge] TELEGRAM_BOT_TOKEN e/ou TELEGRAM_CHAT_ID não definidos em podman/.env — a ponte não vai conectar ao Telegram." >&2
    echo "[matterbridge] Veja a seção 'Ponte IRC <-> Telegram (Matterbridge)' no README.md." >&2
fi

envsubst < /opt/matterbridge/matterbridge.toml.tmpl > /opt/matterbridge/matterbridge.toml

exec /opt/matterbridge/matterbridge -conf /opt/matterbridge/matterbridge.toml
