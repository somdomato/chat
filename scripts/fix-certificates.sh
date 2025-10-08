#!/usr/bin/env bash

# Script para verificar e corrigir certificados SSL
echo "🔍 Verificando certificados SSL no servidor..."

ssh root@ananke -p 2200 << 'EOF'
echo "📋 Verificando certificados criados..."
ls -la /etc/letsencrypt/live/

echo ""
echo "🔍 Verificando certificado principal (irc.somdomato.com)..."
if [[ -d "/etc/letsencrypt/live/irc.somdomato.com" ]]; then
    echo "✅ Certificado principal encontrado"
    ls -la /etc/letsencrypt/live/irc.somdomato.com/
    
    echo ""
    echo "🔗 Criando links simbólicos para outros domínios..."
    
    # Criar links para gamja.somdomato.com
    if [[ ! -d "/etc/letsencrypt/live/gamja.somdomato.com" ]]; then
        ln -sf /etc/letsencrypt/live/irc.somdomato.com /etc/letsencrypt/live/gamja.somdomato.com
        echo "✅ Link criado: gamja.somdomato.com -> irc.somdomato.com"
    else
        echo "ℹ️  gamja.somdomato.com já existe"
    fi
    
    # Criar links para chat.somdomato.com
    if [[ ! -d "/etc/letsencrypt/live/chat.somdomato.com" ]]; then
        ln -sf /etc/letsencrypt/live/irc.somdomato.com /etc/letsencrypt/live/chat.somdomato.com
        echo "✅ Link criado: chat.somdomato.com -> irc.somdomato.com"
    else
        echo "ℹ️  chat.somdomato.com já existe"
    fi
    
    echo ""
    echo "📋 Verificando todos os certificados após links..."
    for domain in irc.somdomato.com gamja.somdomato.com chat.somdomato.com; do
        if [[ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]]; then
            echo "✅ $domain: OK"
        else
            echo "❌ $domain: Não encontrado"
        fi
    done
    
    echo ""
    echo "🧪 Testando configuração do Nginx..."
    nginx -t
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Configuração do Nginx OK"
        echo "🔄 Reiniciando Nginx..."
        systemctl restart nginx
        echo "🎯 Status do Nginx:"
        systemctl status nginx --no-pager -l
    else
        echo "❌ Erro na configuração do Nginx"
        echo "📋 Verificando erros específicos..."
        nginx -T 2>&1 | grep -i error || echo "Nenhum erro específico encontrado"
    fi
    
else
    echo "❌ Certificado principal não encontrado!"
    echo "📋 Arquivos disponíveis em /etc/letsencrypt/live/:"
    ls -la /etc/letsencrypt/live/ || echo "Diretório não existe"
fi
EOF

echo ""
echo "✅ Verificação concluída!"
echo "📝 Se tudo estiver OK, execute novamente: ./scripts/ansible.sh"