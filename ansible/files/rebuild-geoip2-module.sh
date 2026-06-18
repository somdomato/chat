#!/usr/bin/env bash
# Recompila o ngx_http_geoip2_module contra a versão instalada do nginx.
#
# O nginx nesta VPS vem do repositório oficial nginx-stable (nginx.org), que
# não empacota o módulo geoip2 — por isso ele é compilado manualmente a partir
# do source. Quando o nginx.org libera uma versão nova e o dnf update a
# instala, o módulo antigo passa a ter ABI incompatível
# ("module ... version X instead of Y") até ser recompilado.
#
# Idempotente: só recompila se a versão instalada do nginx for diferente da
# versão registrada no marcador. Saída usada pelo Ansible para decidir
# changed_when: "SKIP" (nada mudou) ou "REBUILT" (módulo recompilado).
set -euo pipefail

MODULES_DIR=/usr/lib64/nginx/modules
MARKER_FILE="${MODULES_DIR}/.geoip2_built_for_version"
BUILD_DIR=/usr/local/src
GEOIP2_REPO=https://github.com/leev/ngx_http_geoip2_module.git

nginx_version="$(nginx -v 2>&1 | sed -n 's#.*nginx/\([0-9.]*\).*#\1#p')"
configure_args="$(nginx -V 2>&1 | sed -n 's/^configure arguments: //p')"

if [[ -z "$nginx_version" || -z "$configure_args" ]]; then
    echo "ERRO: não foi possível detectar a versão/configure arguments do nginx instalado" >&2
    exit 1
fi

if [[ -f "$MARKER_FILE" && "$(cat "$MARKER_FILE")" == "$nginx_version" ]]; then
    echo "SKIP: módulo geoip2 já compilado para o nginx ${nginx_version}"
    exit 0
fi

echo "Recompilando módulo geoip2 para o nginx ${nginx_version}..."

dnf install -y gcc make pcre2-devel zlib-devel openssl-devel libmaxminddb-devel git

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [[ ! -d "nginx-${nginx_version}" ]]; then
    curl -fsSLO "http://nginx.org/download/nginx-${nginx_version}.tar.gz"
    tar xzf "nginx-${nginx_version}.tar.gz"
fi

rm -rf ngx_http_geoip2_module
git clone --depth 1 "$GEOIP2_REPO" ngx_http_geoip2_module

cd "nginx-${nginx_version}"
# shellcheck disable=SC2086
eval ./configure $configure_args --add-dynamic-module=../ngx_http_geoip2_module
make modules

install -m 0644 objs/ngx_http_geoip2_module.so "${MODULES_DIR}/ngx_http_geoip2_module.so"
echo "$nginx_version" > "$MARKER_FILE"

echo "REBUILT: módulo geoip2 recompilado para o nginx ${nginx_version}"
