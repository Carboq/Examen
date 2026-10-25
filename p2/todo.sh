#!/usr/bin/env bash
# Práctica 2 completa: crear RAID 5, simular un fallo y reponer el disco.
#
#   ./icd.sh p2 todo sdb,sdc,sdd,sde
#   ./icd.sh p2 todo --disks sdb,sdc,sdd,sde --yes
#
# Es DESTRUCTIVO: usa solo discos que puedas borrar.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
load_config "${CONFIG:-$HERE/../config.env}"

MD=${MD:-/dev/md0}
DISKS=${DISKS:-}
YES=0
CLEAN=0

usage() {
  cat <<'EOF'
Uso: todo.sh [discos] [opciones]

  discos            Lista separada por comas: sdb,sdc,sdd,sde
  --disks LISTA     La misma lista, con nombre de opción.
  --yes             No pedir confirmación al crear la matriz.
  --assume-clean    Omite la sincronización inicial (más rápido).
  -h, --help        Esta ayuda.

Sin discos, muestra los discos detectados y termina.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --disks) DISKS=${2:?}; shift 2 ;;
    --disks=*) DISKS=${1#*=}; shift ;;
    --yes) YES=1; shift ;;
    --assume-clean) CLEAN=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    -*) die "Opción desconocida: $1" ;;
    *) DISKS=$1; shift ;;
  esac
done

if [[ -z ${DISKS// /} ]]; then
  bash "$HERE/raid.sh" detect
  printf '\nIndica los discos: ./icd.sh p2 todo sdb,sdc,sdd,sde\n'
  exit 0
fi

warn "Vas a crear una matriz RAID y a simular un fallo. Usa solo discos libres."

args=(create --disks "$DISKS")
[[ $YES -eq 1 ]] && args+=(--yes)
[[ $CLEAN -eq 1 ]] && args+=(--assume-clean)
bash "$HERE/raid.sh" "${args[@]}"
bash "$HERE/raid.sh" status

need mdadm
dev=$(mdadm --detail "$MD" | awk '/active sync/ {print $NF; exit}')
[[ -n $dev ]] || die "No encuentro un disco activo para simular el fallo."

log "Fallo simulado sobre $dev"
bash "$HERE/raid.sh" fail "$dev"
bash "$HERE/raid.sh" add "$dev"
bash "$HERE/raid.sh" status

log "Práctica 2 completada: matriz creada, fallo simulado y disco repuesto."
