#!/usr/bin/env bash

MACHINE="ananke"
OPTS="ansible_port=2200"
ROOT="$(dirname "$(readlink -f "$0")")/.."

# if  [ "$(uname -s)" = "Darwin" ] || [ "$(lsb_release -is)" == "Arch" ] || [ "$(lsb_release -is)" == "VoidLinux" ]; then
#   ansible-playbook -e "ansible_port=2200 ansible_python_interpreter=/usr/bin/python3" "$ROOT/ansible/playbook.yml" -i ananke,
# else
#   ansible-playbook --connection=local -e "ansible_port=2200" "$ROOT/ansible/playbook.yml" -i localhost,
# fi

if [ "$(lsb_release -s)" == "Darwin" ] || [ "$(lsb_release -is)" == "Void" ] || [ "$(lsb_release -is)" == "Arch" ]; then
  ANSIBLE_PYTHON_INTERPRETER=auto_silent \
  ANSIBLE_CONFIG="${ROOT}/../ansible/ansible.cfg" \
  ansible-playbook -e "$OPTS" "${ROOT}/ansible/playbook.yml" -i $MACHINE,
else
  ANSIBLE_PYTHON_INTERPRETER=auto_silent \
  ANSIBLE_CONFIG="${ROOT}/../ansible/ansible.cfg" \
  ansible-playbook --connection=local -e "$OPTS" "${ROOT}/ansible/playbook.yml" -i localhost,
fi