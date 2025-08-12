#!/usr/bin/env bash

ROOT="$(dirname "$(readlink -f "$0")")/.."

if  [ "$(uname -s)" = "Darwin" ] || [ "$(lsb_release -is)" == "Arch" ] || [ "$(lsb_release -is)" == "VoidLinux" ]; then
  ansible-playbook -e "ansible_port=2200 ansible_python_interpreter=/usr/bin/python3" "$ROOT/ansible/playbook.yml" -i ananke,
else
  ansible-playbook --connection=local -e "ansible_port=2200" "$ROOT/ansible/playbook.yml" -i localhost,
fi