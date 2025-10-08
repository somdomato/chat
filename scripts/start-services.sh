#!/usr/bin/env bash

# Script para iniciar todos os serviços necessários
echo "🚀 Iniciando todos os serviços do chat IRC..."

ssh root@ananke -p 2200 << 'EOF'
echo "🔄 Verificando e iniciando serviços..."

# Função para iniciar serviço se não estiver rodando
start_service_if_needed() {
    local service=$1
    local name=$2
    
    if systemctl is-active $service >/dev/null 2>&1; then
        echo "✅ $name já está rodando"
    else
        echo "🔄 Iniciando $name..."
        systemctl start $service
        if systemctl is-active $service >/dev/null 2>&1; then
            echo "✅ $name iniciado com sucesso"
        else
            echo "❌ Falha ao iniciar $name"
            systemctl status $service --no-pager -l
        fi
    fi
    
    # Habilitar para iniciar automaticamente
    if ! systemctl is-enabled $service >/dev/null 2>&1; then
        echo "🔧 Habilitando $name para iniciar automaticamente..."
        systemctl enable $service
    fi
}

# Iniciar Nginx
start_service_if_needed "nginx" "Nginx"

# Iniciar Ergo IRC
start_service_if_needed "somdomato-ergo.service" "Ergo IRC"

# Iniciar KiwiIRC
start_service_if_needed "somdomato-kiwiirc.service" "KiwiIRC"

echo ""
echo "📊 Status final dos serviços:"
for service in nginx somdomato-ergo.service somdomato-kiwiirc.service; do
    if systemctl is-active $service >/dev/null 2>&1; then
        echo "✅ $service: Rodando"
    else
        echo "❌ $service: Parado"
    fi
done

echo ""
echo "🌐 Portas abertas:"
if command -v netstat >/dev/null 2>&1; then
    netstat -tulpn | grep -E ":(80|443|6667|6697|8097)" || echo "Nenhuma porta encontrada"
elif command -v ss >/dev/null 2>&1; then
    ss -tulpn | grep -E ":(80|443|6667|6697|8097)" || echo "Nenhuma porta encontrada"
else
    echo "⚠️  Comando para verificar portas não disponível"
fi

echo ""
echo "🧪 Teste rápido de conectividade local:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost/ || echo "Erro ao conectar localmente"
EOF

echo ""
echo "✅ Tentativa de inicialização concluída!"
echo "🔍 Execute o diagnóstico para verificar: ./scripts/diagnose.sh"