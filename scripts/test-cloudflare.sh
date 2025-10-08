#!/usr/bin/env bash

# Script para testar configuração do Cloudflare (modo legacy)
ROOT="$(dirname "$(readlink -f "$0")")/.."
ANSIBLE_DIR="${ROOT}/ansible"
VAULT_PASSWORD_FILE="${ANSIBLE_DIR}/.vault_pass"

echo "🔍 Testando configuração do Cloudflare (modo legacy)..."

# Verificar se o vault está configurado
if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
    echo "❌ Execute primeiro: ./scripts/vault.sh setup"
    exit 1
fi

# Extrair credenciais do vault
echo "📋 Extraindo credenciais do vault..."
VAULT_CONTENT=$(ansible-vault view "${ANSIBLE_DIR}/group_vars/vault.yml" --vault-password-file="$VAULT_PASSWORD_FILE")

EMAIL=$(echo "$VAULT_CONTENT" | grep cloudflare_email | cut -d'"' -f2)
API_KEY=$(echo "$VAULT_CONTENT" | grep cloudflare_api_key | cut -d'"' -f2)

if [[ "$EMAIL" == "your_cloudflare_email_here" || -z "$EMAIL" ]]; then
    echo "❌ Email não configurado. Execute: ./scripts/vault.sh edit"
    exit 1
fi

if [[ "$API_KEY" == "your_cloudflare_api_key_here" || -z "$API_KEY" ]]; then
    echo "❌ API Key não configurada. Execute: ./scripts/vault.sh edit"
    exit 1
fi

echo "� Email: $EMAIL"
echo "🔑 API Key encontrada (primeiros 10 chars): ${API_KEY:0:10}..."

# Testar credenciais com API do Cloudflare (modo legacy)
echo "🌐 Testando conectividade com Cloudflare API (modo legacy)..."
RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user" \
     -H "X-Auth-Email: $EMAIL" \
     -H "X-Auth-Key: $API_KEY" \
     -H "Content-Type: application/json")

SUCCESS=$(echo "$RESPONSE" | grep -o '"success":[^,]*' | cut -d':' -f2)

if [[ "$SUCCESS" == "true" ]]; then
    echo "✅ Credenciais do Cloudflare válidas!"
    
    # Mostrar informações do usuário
    echo "� Informações do usuário:"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null | grep -A 5 -B 2 "email\|first_name\|last_name" || echo "Não foi possível extrair informações"
else
    echo "❌ Credenciais inválidas!"
    echo "📄 Resposta da API:"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    echo ""
    echo "🔧 Para corrigir:"
    echo "1. Verifique se o email e API key estão corretos: ./scripts/vault.sh edit"
    echo "2. Obtenha a API key em: https://dash.cloudflare.com/profile/api-tokens"
    echo "3. Use a 'Global API Key', não um token personalizado"
    echo "4. Teste novamente: $0"
fi