#!/usr/bin/env bash
# Práctica 3: instala fio si hace falta y ejecuta la batería de medidas.
#
#   ./icd.sh p3 todo
#   ./icd.sh p3 todo --target /mnt/raid5 --runtime 10
#
# Antes debe existir la matriz montada (P2).

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
load_config "${CONFIG:-$HERE/../config.env}"

TARGET=${MNT:-/mnt/raid5}
SIZES=${SIZES:-"4k 64k 1M"}
RUNTIME=${RUNTIME:-15}
NO_INSTALL=0

usage() {
  cat <<'EOF'
Uso: todo.sh [opciones]

  --target RUTA     Punto de montaje a medir (por defecto /mnt/raid5).
  --sizes "LISTA"   Tamaños de bloque (por defecto "4k 64k 1M").
  --runtime S       Duración de cada prueba (por defecto 15 s).
  --no-install      No intentar instalar fio.
  -h, --help        Esta ayuda.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET=${2:?}; shift 2 ;;
    --target=*) TARGET=${1#*=}; shift ;;
    --sizes) SIZES=${2:?}; shift 2 ;;
    --sizes=*) SIZES=${1#*=}; shift ;;
    --runtime) RUNTIME=${2:?}; shift 2 ;;
    --runtime=*) RUNTIME=${1#*=}; shift ;;
    --no-install) NO_INSTALL=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    *) die "Opción desconocida: $1" ;;
  esac
done

if ! command -v fio >/dev/null 2>&1; then
  [[ $NO_INSTALL -eq 0 ]] || die "fio no está instalado y se pidió --no-install."
  require_root
  command -v apt-get >/dev/null 2>&1 || die "No hay apt-get; instala fio a mano."
  log "Instalando fio..."
  apt-get -o DPkg::Lock::Timeout=60 update -qq \
    || warn "apt-get update ha fallado; intento instalar igualmente."
  DEBIAN_FRONTEND=noninteractive \
    apt-get -o DPkg::Lock::Timeout=60 install -y fio \
    || die "No se pudo instalar fio."
fi

mountpoint -q "$TARGET" \
  || die "$TARGET no es un punto de montaje. Ejecuta primero la P2 y monta la matriz."

bash "$HERE/bench.sh" run --target "$TARGET" --sizes "$SIZES" --runtime "$RUNTIME"
