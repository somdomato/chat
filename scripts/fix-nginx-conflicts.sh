#!/usr/bin/env bash

# Script para corrigir conflitos de server_name no Nginx
echo "🔧 Corrigindo conflitos de server_name no Nginx..."

echo "📋 Primeiro vamos testar se há conflitos atuais..."
ssh root@ananke -p 2200 'nginx -t' || echo "❌ Há erros na configuração atual"

echo ""
echo "🔄 Aplicando playbook apenas para configurações do Nginx..."

# Executar apenas a parte do Nginx do playbook
MACHINE="ananke"
ROOT="$(dirname "$(readlink -f "$0")")/.."
ANSIBLE_DIR="${ROOT}/ansible"
VAULT_PASSWORD_FILE="${ANSIBLE_DIR}/.vault_pass"

# Verificar vault
if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
    echo "❌ Execute primeiro: ./scripts/vault.sh setup"
    exit 1
fi

# Criar playbook temporário apenas para Nginx
cat > /tmp/nginx-only.yml << 'EOF'
---
- name: Corrigir configurações do Nginx
  hosts: all
  become: true
  remote_user: root
  vars_files:
    - group_vars/vault.yml
    - group_vars/all.yml

  tasks:
    - name: Fazer backup das configurações atuais do Nginx
      ansible.builtin.command: >
        cp -r /etc/nginx/sites.d /etc/nginx/sites.d.backup.{{ ansible_date_time.epoch }}
      ignore_errors: true

    - name: Copiar configurações corrigidas do Nginx
      ansible.builtin.copy:
        src: "etc/nginx/sites.d/{{ item }}"
        dest: "/etc/nginx/sites.d/{{ item }}"
        owner: root
        group: root
        mode: '0644'
        force: true
        backup: yes
      loop:
        - "50-{{ domains.irc }}.conf"
        - "51-{{ domains.gamja }}.conf"
        - "52-{{ domains.chat }}.conf"

    - name: Testar configuração do Nginx
      ansible.builtin.command: nginx -t
      register: nginx_test
      failed_when: false

    - name: Mostrar resultado do teste
      ansible.builtin.debug:
        msg:
          - "Teste do Nginx: {{ 'PASSOU' if nginx_test.rc == 0 else 'FALHOU' }}"
          - "{{ nginx_test.stdout }}"
          - "{{ nginx_test.stderr }}"

    - name: Recarregar Nginx se configuração estiver OK
      ansible.builtin.systemd:
        name: nginx
        state: reloaded
      when: nginx_test.rc == 0

    - name: Falhar se configuração inválida
      ansible.builtin.fail:
        msg: "Configuração do Nginx inválida após correção"
      when: nginx_test.rc != 0
EOF

echo "🚀 Executando correção..."
ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
ansible-playbook \
    --vault-password-file="$VAULT_PASSWORD_FILE" \
    --inventory="$MACHINE," \
    -e "ansible_python_interpreter=auto_silent" \
    /tmp/nginx-only.yml

# Limpar
rm /tmp/nginx-only.yml

echo ""
echo "✅ Correção concluída!"
echo "🔍 Verificando resultado..."

ssh root@ananke -p 2200 << 'EOF'
echo "🧪 Teste final da configuração:"
nginx -t

echo ""
echo "📊 Status do Nginx:"
systemctl status nginx --no-pager -l | head -10

echo ""
echo "🌐 Testando resposta HTTP:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost/ || echo "Erro na requisição"
EOF

echo "🎉 Se não houver erros acima, o problema foi resolvido!"