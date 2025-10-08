#!/usr/bin/env bash

# Diagnóstico rápido e simples
echo "🔍 Diagnóstico rápido do chat IRC..."

echo ""
echo "1. 📡 Testando conectividade básica..."
if ping -c 1 ananke >/dev/null 2>&1; then
    echo "✅ Servidor acessível"
else
    echo "❌ Servidor inacessível"
    exit 1
fi

echo ""
echo "2. 🔑 Testando SSH..."
if ssh -o ConnectTimeout=5 root@ananke -p 2200 'echo OK' >/dev/null 2>&1; then
    echo "✅ SSH funcionando"
else
    echo "❌ SSH não funciona"
    exit 1
fi

echo ""
echo "3. 🌐 Testando resolução DNS..."
for domain in irc.somdomato.com gamja.somdomato.com chat.somdomato.com; do
    if ping -c 1 $domain >/dev/null 2>&1; then
        echo "✅ $domain resolve"
    else
        echo "❌ $domain não resolve"
    fi
done

echo ""
echo "4. 🔧 Status dos serviços no servidor..."
ssh root@ananke -p 2200 '
echo "Nginx: $(systemctl is-active nginx 2>/dev/null || echo "parado")"
echo "Ergo: $(systemctl is-active somdomato-ergo.service 2>/dev/null || echo "parado")"
echo "KiwiIRC: $(systemctl is-active somdomato-kiwiirc.service 2>/dev/null || echo "parado")"

echo ""
echo "🔒 Certificados:"
for domain in irc.somdomato.com gamja.somdomato.com chat.somdomato.com; do
    if [[ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]]; then
        echo "✅ $domain: certificado OK"
    else
        echo "❌ $domain: sem certificado"
    fi
done
'

echo ""
echo "5. 🌍 Testando conectividade HTTP..."
for domain in irc.somdomato.com gamja.somdomato.com chat.somdomato.com; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$domain --connect-timeout 5 2>/dev/null || echo "000")
    HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://$domain --connect-timeout 5 --insecure 2>/dev/null || echo "000")
    
    echo "$domain: HTTP=$HTTP_CODE HTTPS=$HTTPS_CODE"
done

echo ""
echo "✅ Diagnóstico concluído!"
echo ""
echo "🔧 Se algo não funciona:"
echo "   - Serviços parados: ./scripts/start-services.sh"
echo "   - Certificados: ./scripts/fix-certificates.sh"
echo "   - Diagnóstico completo: ./scripts/diagnose.sh"