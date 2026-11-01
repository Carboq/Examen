#!/usr/bin/env bash
# Práctica 1: genera la configuración y recuerda el trabajo manual en Packet Tracer.
#
#   ./icd.sh p1 todo
#
# Packet Tracer no tiene API externa: la topología, el cableado y el DHCP/DNS
# se hacen en la GUI. Lo automatizable es el texto de configuración de R1-R4.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES="$HERE/valores.env"

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
  cat <<'EOF'
Uso: todo.sh

Genera p1/out/R1.txt .. R4.txt a partir de p1/valores.env.
La primera vez crea p1/valores.env desde el ejemplo y termina.
Packet Tracer no se puede automatizar: la topología, el cableado y el
DHCP/DNS se hacen en la GUI.
EOF
  exit 0
fi

if [[ ! -f $VALUES ]]; then
  cp "$HERE/valores.env.example" "$VALUES"
  printf '[icd] He creado %s\n' "$VALUES"
  printf '[icd] Edítalo con los valores del enunciado y vuelve a ejecutar:\n'
  printf '       ./icd.sh p1 todo\n'
  exit 0
fi

bash "$HERE/generar.sh"

cat <<'EOF'

Siguiente, en Packet Tracer:
  1. Monta la topología: 4 routers 2911, un switch 2960 por red, PCs y servidor.
  2. Abre la CLI de R1..R4 y pega el contenido de p1/out/R1.txt .. R4.txt.
  3. En Server0 -> Services, configura DHCP (un pool por red) y DNS.
  4. Comprueba ping entre redes, ipconfig /renew y nslookup.
Guía completa: p1/LEEME.md
EOF
