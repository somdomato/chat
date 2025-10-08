#!/usr/bin/env bash

# Script para diagnosticar problemas de conectividade
echo "🔍 Diagnosticando conectividade e serviços..."

echo "1. 🌐 Testando conectividade básica com o servidor..."
if ping -c 3 ananke >/dev/null 2>&1; then
    echo "✅ Servidor ananke está acessível via ping"
else
    echo "❌ Servidor ananke não responde ao ping"
    echo "🔧 Verifique se o servidor está ligado e a rede está funcionando"
    exit 1
fi

echo ""
echo "2. 🔌 Testando conectividade SSH..."
if ssh -o ConnectTimeout=5 root@ananke -p 2200 'echo "SSH OK"' 2>/dev/null; then
    echo "✅ SSH funcionando corretamente"
else
    echo "❌ Não foi possível conectar via SSH"
    echo "🔧 Verifique se o servidor SSH está rodando na porta 2200"
    exit 1
fi

echo ""
echo "3. 🌍 Testando resolução DNS dos domínios..."
for domain in irc.somdomato.com gamja.somdomato.com chat.somdomato.com; do
    # Tentar diferentes métodos de resolução DNS
    if command -v dig >/dev/null 2>&1; then
        IP=$(dig +short $domain | head -1)
    elif command -v host >/dev/null 2>&1; then
        IP=$(host $domain | grep "has address" | awk '{print $4}' | head -1)
    elif command -v getent >/dev/null 2>&1; then
        IP=$(getent hosts $domain | awk '{print $1}' | head -1)
    else
        # Fallback usando ping
        IP=$(ping -c 1 $domain 2>/dev/null | grep "PING" | awk -F'[()]' '{print $2}')
    fi
    
    if [[ -n "$IP" && "$IP" != "" ]]; then
        echo "✅ $domain resolve para: $IP"
    else
        echo "❌ $domain não resolve"
    fi
done

echo ""
echo "4. 📋 Verificando status dos serviços no servidor..."
ssh root@ananke -p 2200 << 'EOF'
echo "🔍 Status dos serviços principais:"
echo ""

echo "📊 Nginx:"
systemctl is-active nginx && echo "✅ Nginx está rodando" || echo "❌ Nginx não está rodando"
systemctl is-enabled nginx && echo "✅ Nginx está habilitado" || echo "❌ Nginx não está habilitado"

echo ""
echo "📊 Ergo IRC:"
systemctl is-active somdomato-ergo.service && echo "✅ Ergo está rodando" || echo "❌ Ergo não está rodando"
systemctl is-enabled somdomato-ergo.service && echo "✅ Ergo está habilitado" || echo "❌ Ergo não está habilitado"

echo ""
echo "📊 KiwiIRC:"
systemctl is-active somdomato-kiwiirc.service && echo "✅ KiwiIRC está rodando" || echo "❌ KiwiIRC não está rodando"
systemctl is-enabled somdomato-kiwiirc.service && echo "✅ KiwiIRC está habilitado" || echo "❌ KiwiIRC não está habilitado"

echo ""
echo "🌐 Portas em uso:"
if command -v netstat >/dev/null 2>&1; then
    netstat -tulpn | grep -E ":(80|443|6667|6697|8097)" | head -10
elif command -v ss >/dev/null 2>&1; then
    ss -tulpn | grep -E ":(80|443|6667|6697|8097)" | head -10
else
    echo "⚠️  Comando para verificar portas não disponível"
    # Alternativa usando lsof se disponível
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :80,443,6667,6697,8097 | head -10
    fi
fi

echo ""
echo "🔒 Certificados SSL:"
for domain in irc.somdomato.com gamja.somdomato.com chat.somdomato.com; do
    if [[ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]]; then
        echo "✅ Certificado $domain: OK"
        # Verificar validade
        openssl x509 -in "/etc/letsencrypt/live/$domain/fullchain.pem" -noout -dates | head -2
    else
        echo "❌ Certificado $domain: Não encontrado"
    fi
done

echo ""
echo "📝 Logs recentes do Nginx (últimas 5 linhas):"
journalctl -u nginx --no-pager -n 5

echo ""
echo "📝 Logs recentes do Ergo (últimas 5 linhas):"
journalctl -u somdomato-ergo.service --no-pager -n 5

echo ""
echo "🧪 Teste de configuração do Nginx:"
nginx -t
EOF

echo ""
echo "5. 🌐 Testando conectividade HTTP/HTTPS..."
for domain in irc.somdomato.com gamja.somdomato.com chat.somdomato.com; do
    echo "🔗 Testando $domain..."
    
    # Teste HTTP
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$domain --connect-timeout 10 || echo "000")
    if [[ "$HTTP_STATUS" == "301" || "$HTTP_STATUS" == "302" ]]; then
        echo "✅ HTTP $domain: Redirecionamento OK ($HTTP_STATUS)"
    else
        echo "❌ HTTP $domain: Status $HTTP_STATUS"
    fi
    
    # Teste HTTPS
    HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$domain --connect-timeout 10 --insecure || echo "000")
    if [[ "$HTTPS_STATUS" == "200" ]]; then
        echo "✅ HTTPS $domain: OK ($HTTPS_STATUS)"
    else
        echo "❌ HTTPS $domain: Status $HTTPS_STATUS"
    fi
done

echo ""
echo "✅ Diagnóstico concluído!"
echo ""
echo "🔧 Próximos passos se houver problemas:"
echo "   - Se serviços estão parados: systemctl start <service>"
echo "   - Se Nginx tem erro: nginx -t e corrigir configuração"
echo "   - Se DNS não resolve: verificar configuração do domínio"
echo "   - Se certificados estão com problema: ./scripts/fix-certificates.sh"