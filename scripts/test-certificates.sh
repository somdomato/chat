#!/usr/bin/env bash

# Script simplificado apenas para obter certificados
MACHINE="ananke"
ROOT="$(dirname "$(readlink -f "$0")")/.."
ANSIBLE_DIR="${ROOT}/ansible"
VAULT_PASSWORD_FILE="${ANSIBLE_DIR}/.vault_pass"

echo "🔒 Executando apenas obtenção de certificados SSL..."

# Verificar vault
if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
    echo "❌ Execute primeiro: ./scripts/vault.sh setup"
    exit 1
fi

# Criar playbook temporário só para certificados
cat > /tmp/cert-only.yml << 'EOF'
---
- name: Obter apenas certificados SSL
  hosts: all
  become: true
  remote_user: root
  vars_files:
    - group_vars/vault.yml
    - group_vars/all.yml

  tasks:
    - name: Criar arquivo de credenciais do Cloudflare
      ansible.builtin.copy:
        content: |
          dns_cloudflare_email = {{ cloudflare_email }}
          dns_cloudflare_api_key = {{ cloudflare_api_key }}
        dest: /etc/letsencrypt/cloudflare.ini
        owner: root
        group: root
        mode: '0600'

    - name: Obter certificados SSL
      ansible.builtin.command: >
        certbot certonly
        --dns-cloudflare
        --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini
        --email {{ letsencrypt_email }}
        --agree-tos
        --non-interactive
        --force-renewal
        -d {{ domains.irc }}
        -d {{ domains.gamja }}
        -d {{ domains.chat }}
      register: certbot_result

    - name: Mostrar resultado
      ansible.builtin.debug:
        msg:
          - "Return code: {{ certbot_result.rc }}"
          - "STDOUT: {{ certbot_result.stdout }}"
          - "STDERR: {{ certbot_result.stderr }}"

    - name: Verificar certificados
      ansible.builtin.stat:
        path: "/etc/letsencrypt/live/{{ domains.irc }}/fullchain.pem"
      register: cert_check

    - name: Status final
      ansible.builtin.debug:
        msg: "Certificados criados: {{ 'Sim' if cert_check.stat.exists else 'Não' }}"
EOF

# Executar playbook temporário
ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
ansible-playbook \
    --vault-password-file="$VAULT_PASSWORD_FILE" \
    --inventory="$MACHINE," \
    -e "ansible_python_interpreter=auto_silent" \
    /tmp/cert-only.yml

# Limpar
rm /tmp/cert-only.yml

echo "✅ Teste de certificados concluído"