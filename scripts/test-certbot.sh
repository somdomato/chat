#!/usr/bin/env bash

# Script para testar certbot manualmente
echo "🧪 Testando certbot manualmente..."

# Conectar ao servidor e executar certbot
ssh root@ananke -p 2200 << 'EOF'
echo "📋 Verificando arquivo de credenciais..."
if [[ -f /etc/letsencrypt/cloudflare.ini ]]; then
    echo "✅ Arquivo de credenciais existe"
    echo "📄 Conteúdo (mascarado):"
    sed 's/\(.*=\s*\).*/\1***MASCARADO***/' /etc/letsencrypt/cloudflare.ini
else
    echo "❌ Arquivo de credenciais não encontrado"
    exit 1
fi

echo ""
echo "🔍 Executando certbot em modo dry-run..."
certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
    --email admin@somdomato.com \
    --agree-tos \
    --non-interactive \
    --dry-run \
    --verbose \
    -d irc.somdomato.com \
    -d gamja.somdomato.com \
    -d chat.somdomato.com

echo ""
echo "📊 Status do dry-run: $?"

echo ""
echo "📁 Verificando diretório de certificados..."
ls -la /etc/letsencrypt/live/ 2>/dev/null || echo "Diretório não existe ainda"

echo ""
echo "📝 Últimas linhas do log:"
tail -n 20 /var/log/letsencrypt/letsencrypt.log 2>/dev/null || echo "Log não encontrado"
EOF

echo ""
echo "🔧 Para executar certbot real (não dry-run), conecte-se manualmente:"
echo "   ssh root@ananke -p 2200"
echo "   certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini -d irc.somdomato.com -d gamja.somdomato.com -d chat.somdomato.com --email admin@somdomato.com --agree-tos --non-interactive"