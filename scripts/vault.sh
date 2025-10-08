#!/usr/bin/env bash

# Script para gerenciar o ansible-vault
ROOT="$(dirname "$(readlink -f "$0")")/.."
ANSIBLE_DIR="${ROOT}/ansible"
VAULT_FILE="${ANSIBLE_DIR}/group_vars/vault.yml"
VAULT_PASSWORD_FILE="${ANSIBLE_DIR}/.vault_pass"

show_help() {
    echo "🔐 Gerenciador do Ansible Vault"
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  edit        - Editar o arquivo vault.yml"
    echo "  view        - Visualizar o arquivo vault.yml"
    echo "  encrypt     - Criptografar o arquivo vault.yml"
    echo "  decrypt     - Descriptografar o arquivo vault.yml"
    echo "  rekey       - Alterar a senha do vault"
    echo "  setup       - Configuração inicial do vault"
    echo "  help        - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 setup    # Primeira configuração"
    echo "  $0 edit     # Editar variáveis sensíveis"
    echo "  $0 view     # Ver conteúdo do vault"
}

check_vault_password() {
    if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
        echo "❌ Arquivo de senha do vault não encontrado: $VAULT_PASSWORD_FILE"
        echo "🔧 Execute: $0 setup"
        return 1
    fi
    return 0
}

setup_vault() {
    echo "🔧 Configuração inicial do ansible-vault"
    echo ""
    
    # Criar senha do vault
    echo "1. Criando arquivo de senha do vault..."
    read -s -p "Digite a senha para o vault: " vault_password
    echo ""
    echo "$vault_password" > "$VAULT_PASSWORD_FILE"
    chmod 600 "$VAULT_PASSWORD_FILE"
    echo "✅ Senha do vault salva em: $VAULT_PASSWORD_FILE"
    
    # Criptografar o arquivo vault.yml se ele existir e não estiver criptografado
    if [[ -f "$VAULT_FILE" ]]; then
        if ! ansible-vault view "$VAULT_FILE" --vault-password-file="$VAULT_PASSWORD_FILE" >/dev/null 2>&1; then
            echo "2. Criptografando arquivo vault.yml..."
            ansible-vault encrypt "$VAULT_FILE" --vault-password-file="$VAULT_PASSWORD_FILE"
            echo "✅ Arquivo vault.yml criptografado"
        else
            echo "2. Arquivo vault.yml já está criptografado"
        fi
    else
        echo "❌ Arquivo vault.yml não encontrado: $VAULT_FILE"
        return 1
    fi
    
    echo ""
    echo "✅ Configuração inicial concluída!"
    echo "📝 Agora você pode editar o vault com: $0 edit"
}

case "${1:-help}" in
    "edit")
        check_vault_password || exit 1
        ansible-vault edit "$VAULT_FILE" --vault-password-file="$VAULT_PASSWORD_FILE"
        ;;
    "view")
        check_vault_password || exit 1
        ansible-vault view "$VAULT_FILE" --vault-password-file="$VAULT_PASSWORD_FILE"
        ;;
    "encrypt")
        check_vault_password || exit 1
        ansible-vault encrypt "$VAULT_FILE" --vault-password-file="$VAULT_PASSWORD_FILE"
        ;;
    "decrypt")
        check_vault_password || exit 1
        ansible-vault decrypt "$VAULT_FILE" --vault-password-file="$VAULT_PASSWORD_FILE"
        ;;
    "rekey")
        check_vault_password || exit 1
        ansible-vault rekey "$VAULT_FILE" --vault-password-file="$VAULT_PASSWORD_FILE"
        ;;
    "setup")
        setup_vault
        ;;
    "help"|*)
        show_help
        ;;
esac