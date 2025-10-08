#!/usr/bin/env bash

# Script para executar apenas as partes essenciais do playbook
# Útil para testar sem a instalação do Node.js

MACHINE="ananke"
ROOT="$(dirname "$(readlink -f "$0")")/.."
ANSIBLE_DIR="${ROOT}/ansible"
VAULT_PASSWORD_FILE="${ANSIBLE_DIR}/.vault_pass"

# Verificar se o arquivo de senha do vault existe
if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
    echo "❌ Arquivo de senha do vault não encontrado: $VAULT_PASSWORD_FILE"
    echo "📋 Execute: ./scripts/vault.sh setup"
    exit 1
fi

echo "🚀 Executando playbook Ansible (modo essencial)..."
echo "📍 Máquina: $MACHINE"
echo "📁 Diretório: $ANSIBLE_DIR"

# Executar apenas tags específicas (pular Node.js)
ANSIBLE_PYTHON_INTERPRETER=auto_silent \
ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
ansible-playbook \
    --vault-password-file="$VAULT_PASSWORD_FILE" \
    --inventory="$MACHINE," \
    "${ANSIBLE_DIR}/playbook.yml" \
    --diff \
    --skip-tags nodejs,gamja_build

exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    echo "✅ Playbook executado com sucesso!"
    echo "📝 Para instalar Node.js separadamente:"
    echo "   ssh root@$MACHINE -p 2200 'snap install node --classic'"
else
    echo "❌ Erro na execução do playbook (código: $exit_code)"
fi

exit $exit_code