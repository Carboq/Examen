#!/usr/bin/env bash
# Práctica 4 con contenedores LXC de Proxmox.
#
#   ./icd.sh p4 lxc create
#   ./icd.sh p4 lxc services
#   ./icd.sh p4 lxc status
#   ./icd.sh p4 lxc destroy
#
# Se ejecuta en el HOST PROXMOX, no dentro de la VM Debian.
# pfSense no se toca aquí: sigue siendo una VM de P5.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib.sh
source "$HERE/../lib.sh"
load_config "${CONFIG:-$ROOT/config.env}"

TEMPLATE=${LXC_TEMPLATE:-local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst}
STORAGE=${LXC_STORAGE:-local-lvm}
BRIDGE=${LXC_BRIDGE:-${BRIDGE:-vmbr1}}
GW=${LXC_GW:-192.168.50.1}
DNS=${LXC_DNS:-1.1.1.1}
MEMORY=${LXC_MEMORY:-2048}
CORES=${LXC_CORES:-2}
DISK=${LXC_DISK:-32}
PASSWORD=${LXC_PASSWORD:-icd2026}
DB_PASS=${ICD_DB_PASS:-${P4_DB_PASS:-icd2026}}
UNPRIVILEGED=${LXC_UNPRIVILEGED:-1}
SWAP=${LXC_SWAP:-512}
FEATURES=${LXC_FEATURES:-nesting=1,keyctl=1}

P4_WEB1_ID=${P4_WEB1_ID:-201}
P4_WEB2_ID=${P4_WEB2_ID:-202}
P4_APP_ID=${P4_APP_ID:-203}
P4_WEB1_IP=${P4_WEB1_IP:-192.168.50.11}
P4_WEB2_IP=${P4_WEB2_IP:-192.168.50.12}
P4_APP_IP=${P4_APP_IP:-192.168.50.13}

SERVICES=1

usage() {
  cat <<'EOF'
Uso: lxc.sh <orden> [opciones]

Órdenes:
  create [opciones]     Crea los LXC web1, web2 y app y configura los servicios.
  services [rol]        Configura servicios en los LXC existentes (web1, web2 o app).
  status                Muestra el estado y la IP de cada LXC.
  list                  Equivale a `pct list`.
  destroy [--yes]       Elimina los tres LXC y sus discos.

Opciones de create:
  --template VOLID      Plantilla Debian 12 (por defecto LXC_TEMPLATE).
  --storage STORAGE     Almacenamiento de los discos (por defecto local-lvm).
  --bridge BRIDGE       Bridge de los contenedores (por defecto vmbr1).
  --gw IP               Puerta de enlace (por defecto 192.168.50.1).
  --dns IP              DNS de los contenedores (por defecto 1.1.1.1).
  --password CLAVE      Contraseña de root de los contenedores.
  --memory MB           RAM por contenedor (por defecto 2048).
  --cores N             vCPU por contenedor (por defecto 2).
  --disk GB             Disco por contenedor (por defecto 32).
  --no-services         Crea los LXC pero no instala Apache/MariaDB/Flask/nginx.
  -h, --help            Esta ayuda.

Variables principales: LXC_TEMPLATE, LXC_STORAGE, LXC_PASSWORD, LXC_DNS,
P4_WEB1_ID, P4_WEB2_ID, P4_APP_ID, P4_WEB1_IP, P4_WEB2_IP, P4_APP_IP.

Antes de crear, comprueba que la plantilla existe:
  pveam list local

Ejemplo:
  ./icd.sh p4 lxc create --bridge vmbr1 --gw 192.168.50.1
EOF
}

specs() {
  printf '%s|%s|%s|%s\n' "$P4_WEB1_ID" web1 "$P4_WEB1_IP" web1
  printf '%s|%s|%s|%s\n' "$P4_WEB2_ID" web2 "$P4_WEB2_IP" web2
  printf '%s|%s|%s|%s\n' "$P4_APP_ID" app "$P4_APP_IP" app
}

cmd_create() {
  lxc_require
  lxc_check_template "$TEMPLATE"

  local id name ip role
  while IFS='|' read -r id name ip role; do
    lxc_create "$id" "$name" "$ip" "$BRIDGE" "$GW" \
      "$TEMPLATE" "$STORAGE" "$MEMORY" "$CORES" "$DISK" \
      "$PASSWORD" "$DNS" "$UNPRIVILEGED" "$SWAP" "$FEATURES"
  done < <(specs)

  if [[ $SERVICES -eq 1 ]]; then
    cmd_services
  else
    log "Contenedores creados. Ejecuta: ./icd.sh p4 lxc services"
  fi
}

cmd_services() {
  lxc_require
  local filter=${1:-}
  local id name ip role

  while IFS='|' read -r id name ip role; do
    if [[ -n $filter && $filter != "$name" && $filter != "$role" ]]; then
      continue
    fi
    lxc_exists "$id" || die "No existe el contenedor $id ($name). Crea primero los LXC."
    lxc_ensure_started "$id"

    local args=("$role" --ip "$ip" --db-pass "$DB_PASS")
    [[ -n ${ICD_STUDENT:-} ]] && args+=(--student "$ICD_STUDENT")

    log "Configurando $name ($id) como $role..."
    lxc_copy_and_run "$id" "$ROOT/p4/servicios.sh" "${args[@]}"
  done < <(specs)

  log "Servicios de P4 configurados."
}

cmd_status() {
  lxc_require
  pct list
  printf '\n'
  local id name ip role
  while IFS='|' read -r id name ip role; do
    printf '\n%s (%s) -> %s\n' "$name" "$id" "$ip"
    lxc_status_one "$id"
  done < <(specs)
}

cmd_destroy() {
  lxc_require
  local id name ip role
  while IFS='|' read -r id name ip role; do
    lxc_destroy "$id"
  done < <(specs)
  log "Contenedores de P4 eliminados."
}

CMD=${1:-help}
shift || true

case "$CMD" in
  create)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --template) TEMPLATE=${2:?}; shift 2 ;;
        --template=*) TEMPLATE=${1#*=}; shift ;;
        --storage) STORAGE=${2:?}; shift 2 ;;
        --storage=*) STORAGE=${1#*=}; shift ;;
        --bridge) BRIDGE=${2:?}; shift 2 ;;
        --bridge=*) BRIDGE=${1#*=}; shift ;;
        --gw) GW=${2:?}; shift 2 ;;
        --gw=*) GW=${1#*=}; shift ;;
        --dns) DNS=${2:?}; shift 2 ;;
        --dns=*) DNS=${1#*=}; shift ;;
        --password) PASSWORD=${2:?}; shift 2 ;;
        --password=*) PASSWORD=${1#*=}; shift ;;
        --memory) MEMORY=${2:?}; shift 2 ;;
        --memory=*) MEMORY=${1#*=}; shift ;;
        --cores) CORES=${2:?}; shift 2 ;;
        --cores=*) CORES=${1#*=}; shift ;;
        --disk) DISK=${2:?}; shift 2 ;;
        --disk=*) DISK=${1#*=}; shift ;;
        --no-services) SERVICES=0; shift ;;
        -h|--help|help) usage; exit 0 ;;
        *) die "Opción desconocida: $1" ;;
      esac
    done
    cmd_create ;;
  services)
    cmd_services "${1:-}" ;;
  status)
    cmd_status ;;
  list)
    lxc_require
    pct list ;;
  destroy)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --yes) ASSUME_YES=1; shift ;;
        -h|--help|help) usage; exit 0 ;;
        *) die "Opción desconocida: $1" ;;
      esac
    done
    cmd_destroy ;;
  -h|--help|help)
    usage ;;
  *)
    usage
    exit 1 ;;
esac
