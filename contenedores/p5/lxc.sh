#!/usr/bin/env bash
# Práctica 5: contenedores LXC de apoyo para los servidores de pfSense.
#
#   ./icd.sh p5 lxc create
#   ./icd.sh p5 lxc services
#   ./icd.sh p5 lxc status
#   ./icd.sh p5 lxc destroy
#
# pfSense NO se crea aquí: es una VM FreeBSD y se crea con p5/pfsense.sh.
# Este script se ejecuta en el HOST PROXMOX, no dentro de la VM Debian.

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
DNS=${LXC_DNS:-1.1.1.1}
MEMORY=${LXC_MEMORY:-2048}
CORES=${LXC_CORES:-2}
DISK=${LXC_DISK:-32}
PASSWORD=${LXC_PASSWORD:-icd2026}
DB_PASS=${ICD_DB_PASS:-${P5_DB_PASS:-icd2026}}
UNPRIVILEGED=${LXC_UNPRIVILEGED:-1}
SWAP=${LXC_SWAP:-512}
FEATURES=${LXC_FEATURES:-nesting=1,keyctl=1}

DMZ_BRIDGE=${P5_DMZ_BRIDGE:-vmbr2}
LAN_BRIDGE=${P5_LAN_BRIDGE:-vmbr1}
DMZ_GW=${P5_DMZ_GW:-192.168.50.1}
LAN_GW=${P5_LAN_GW:-192.168.100.1}

P5_DMZ_WEB_ID=${P5_DMZ_WEB_ID:-211}
P5_INTRA_WEB_ID=${P5_INTRA_WEB_ID:-212}
P5_DB_ID=${P5_DB_ID:-213}
P5_APP_ID=${P5_APP_ID:-214}
P5_DMZ_WEB_IP=${P5_DMZ_WEB_IP:-192.168.50.11}
P5_INTRA_WEB_IP=${P5_INTRA_WEB_IP:-192.168.100.11}
P5_DB_IP=${P5_DB_IP:-192.168.100.12}
P5_APP_IP=${P5_APP_IP:-192.168.100.13}

SERVICES=1

usage() {
  cat <<'EOF'
Uso: lxc.sh <orden> [opciones]

Órdenes:
  create [opciones]     Crea dmz-web, intra-web, db y app; configura servicios.
  services [rol]        Configura un rol existente (dmz-web, intra-web, db o app).
  status                Muestra el estado y la IP de cada LXC.
  list                  Equivale a `pct list`.
  destroy [--yes]       Elimina los cuatro LXC y sus discos.

Opciones de create:
  --template VOLID      Plantilla Debian 12 (por defecto LXC_TEMPLATE).
  --storage STORAGE     Almacenamiento de los discos (por defecto local-lvm).
  --dmz-bridge BRIDGE   Bridge de la DMZ (por defecto vmbr2).
  --lan-bridge BRIDGE   Bridge de la LAN (por defecto vmbr1).
  --dmz-gw IP           Puerta de enlace de la DMZ (por defecto 192.168.50.1).
  --lan-gw IP           Puerta de enlace de la LAN (por defecto 192.168.100.1).
  --dns IP              DNS de los contenedores (por defecto 1.1.1.1).
  --password CLAVE      Contraseña de root de los contenedores.
  --memory MB           RAM por contenedor (por defecto 2048).
  --cores N             vCPU por contenedor (por defecto 2).
  --disk GB             Disco por contenedor (por defecto 32).
  --no-services         Crea los LXC pero no instala los servicios.
  -h, --help            Esta ayuda.

Variables principales: P5_DMZ_BRIDGE, P5_LAN_BRIDGE, P5_DMZ_GW, P5_LAN_GW,
P5_DMZ_WEB_ID, P5_INTRA_WEB_ID, P5_DB_ID, P5_APP_ID, P5_DMZ_WEB_IP,
P5_INTRA_WEB_IP, P5_DB_IP, P5_APP_IP, LXC_TEMPLATE, LXC_STORAGE.

Antes de crear, comprueba que la VM pfSense tiene LAN y DMZ configuradas y que
los bridges existen. pfSense se crea aparte con: ./icd.sh p5 todo
EOF
}

specs() {
  printf '%s|%s|%s|%s|%s|%s\n' \
    "$P5_DMZ_WEB_ID" dmz-web "$P5_DMZ_WEB_IP" "$DMZ_BRIDGE" "$DMZ_GW" dmz-web
  printf '%s|%s|%s|%s|%s|%s\n' \
    "$P5_INTRA_WEB_ID" intra-web "$P5_INTRA_WEB_IP" "$LAN_BRIDGE" "$LAN_GW" intra-web
  printf '%s|%s|%s|%s|%s|%s\n' \
    "$P5_DB_ID" db "$P5_DB_IP" "$LAN_BRIDGE" "$LAN_GW" db
  printf '%s|%s|%s|%s|%s|%s\n' \
    "$P5_APP_ID" app "$P5_APP_IP" "$LAN_BRIDGE" "$LAN_GW" app
}

cmd_create() {
  lxc_require
  lxc_check_template "$TEMPLATE"

  local id name ip bridge gw role
  while IFS='|' read -r id name ip bridge gw role; do
    lxc_create "$id" "$name" "$ip" "$bridge" "$gw" \
      "$TEMPLATE" "$STORAGE" "$MEMORY" "$CORES" "$DISK" \
      "$PASSWORD" "$DNS" "$UNPRIVILEGED" "$SWAP" "$FEATURES"
  done < <(specs)

  if [[ $SERVICES -eq 1 ]]; then
    cmd_services
  else
    log "Contenedores creados. Ejecuta: ./icd.sh p5 lxc services"
  fi
}

cmd_services() {
  lxc_require
  local filter=${1:-}
  local id name ip bridge gw role

  while IFS='|' read -r id name ip bridge gw role; do
    if [[ -n $filter && $filter != "$name" && $filter != "$role" ]]; then
      continue
    fi
    lxc_exists "$id" || die "No existe el contenedor $id ($name). Crea primero los LXC."
    lxc_ensure_started "$id"

    local args=("$role" --ip "$ip" --db-pass "$DB_PASS")
    case "$role" in
      db)  args+=(--app-ip "$P5_APP_IP") ;;
      app) args+=(--db-host "$P5_DB_IP") ;;
    esac
    [[ -n ${ICD_STUDENT:-} ]] && args+=(--student "$ICD_STUDENT")

    log "Configurando $name ($id) como $role..."
    lxc_copy_and_run "$id" "$ROOT/contenedores/p5/servicios.sh" "${args[@]}"
  done < <(specs)

  log "Servicios de P5 configurados."
}

cmd_status() {
  lxc_require
  pct list
  printf '\n'
  local id name ip bridge gw role
  while IFS='|' read -r id name ip bridge gw role; do
    printf '\n%s (%s) -> %s por %s\n' "$name" "$id" "$ip" "$bridge"
    lxc_status_one "$id"
  done < <(specs)
}

cmd_destroy() {
  lxc_require
  local id name ip bridge gw role
  while IFS='|' read -r id name ip bridge gw role; do
    lxc_destroy "$id"
  done < <(specs)
  log "Contenedores de P5 eliminados."
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
        --dmz-bridge) DMZ_BRIDGE=${2:?}; shift 2 ;;
        --dmz-bridge=*) DMZ_BRIDGE=${1#*=}; shift ;;
        --lan-bridge) LAN_BRIDGE=${2:?}; shift 2 ;;
        --lan-bridge=*) LAN_BRIDGE=${1#*=}; shift ;;
        --dmz-gw) DMZ_GW=${2:?}; shift 2 ;;
        --dmz-gw=*) DMZ_GW=${1#*=}; shift ;;
        --lan-gw) LAN_GW=${2:?}; shift 2 ;;
        --lan-gw=*) LAN_GW=${1#*=}; shift ;;
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
