#!/usr/bin/env bash
# Práctica 5: VM de pfSense en Proxmox con tres tarjetas de red.
#
#   ./pfsense.sh mac BC:24:11:0A:1B:2C 7     # MAC reservada del laboratorio
#   ./pfsense.sh create                       # crea la VM
#   ./pfsense.sh start
#   ./pfsense.sh info
#
# La instalación de pfSense y la restauración del config.xml son manuales:
# ver p5/LEEME.md.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
load_config "${CONFIG:-$HERE/../config.env}"

VMID=${P5_VMID:-250}
NAME=${P5_NAME:-pfsense}
MEM=${P5_MEM:-2048}
CORES=${P5_CORES:-2}
DISK=${P5_DISK:-16}
STORAGE=${STORAGE:-local-lvm}
WAN=${P5_WAN_BRIDGE:-vmbr0}
LAN=${P5_LAN_BRIDGE:-vmbr1}
DMZ=${P5_DMZ_BRIDGE:-vmbr2}
ISO=${P5_ISO:-}
MAC=${P5_MAC:-}

usage() {
  cat <<'EOF'
Uso: pfsense.sh <orden>

Órdenes:
  mac <MAC_BASE> <PC>   Calcula la MAC reservada: conserva los 4 primeros
                        octetos y pone 11:<PC en hexadecimal>.
                        Ej.: mac BC:24:11:0A:1B:2C 7  ->  BC:24:11:0A:11:07
  create                Crea la VM (3 NIC, disco, ISO y MAC si está definida).
  start | stop          Arranca o para la VM.
  info                  Configuración actual de la VM.
  help                  Esta ayuda.

Variables (config.env): P5_VMID, P5_NAME, P5_MEM, P5_CORES, P5_DISK,
STORAGE, P5_WAN_BRIDGE, P5_LAN_BRIDGE, P5_DMZ_BRIDGE, P5_ISO, P5_MAC.

Tras crearla: instalar pfSense, asignar WAN=vtnet0, LAN=vtnet1, DMZ=vtnet2,
restaurar el config.xml y renovar la WAN. Ver p5/LEEME.md.
EOF
}

cmd_mac() {
  local base=${1:-} pc=${2:-}
  [[ -n $base && -n $pc ]] || die "Uso: pfsense.sh mac BC:24:11:0A:1B:2C 7"
  [[ $base =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] \
    || die "La MAC base no tiene el formato AA:BB:CC:DD:EE:FF."
  [[ $pc =~ ^[0-9]+$ ]] && (( pc >= 0 && pc <= 255 )) \
    || die "El número de PC debe estar entre 0 y 255."

  local prefix
  prefix=$(cut -d: -f1-4 <<< "$base")
  printf '%s:11:%02X\n' "$prefix" "$pc"
}

bridge_exists() {
  ip link show "$1" >/dev/null 2>&1
}

cmd_create() {
  require_root
  need qm

  [[ -n $ISO ]] || die "Define P5_ISO en config.env (volid de la ISO de pfSense)."
  qm status "$VMID" >/dev/null 2>&1 && die "Ya existe una VM con id $VMID."
  [[ $EUID -eq 0 ]] || die "Ejecuta como root."
  pvesm status >/dev/null 2>&1 || die "pvesm no responde: ¿estás en el host Proxmox?"

  local b
  for b in "$WAN" "$LAN" "$DMZ"; do
    bridge_exists "$b" || die "No existe el bridge $b en este host."
  done

  local nets=()
  nets+=(--net0 "virtio,bridge=$WAN${MAC:+,macaddr=$MAC}")
  nets+=(--net1 "virtio,bridge=$LAN")
  nets+=(--net2 "virtio,bridge=$DMZ")

  log "Creando VM $VMID ($NAME): ${MEM} MB, ${CORES} vCPU, ${DISK} GB"
  log "WAN=$WAN${MAC:+ MAC=$MAC}  LAN=$LAN  DMZ=$DMZ"
  confirm "¿Crear la VM?" || die "Cancelado."

  qm create "$VMID" \
    --name "$NAME" \
    --memory "$MEM" \
    --cores "$CORES" \
    --ostype other \
    --scsihw virtio-scsi-pci \
    --scsi0 "$STORAGE:$DISK" \
    --ide2 "$ISO,media=cdrom" \
    --boot order=ide2 \
    --serial0 socket \
    --vga std \
    "${nets[@]}"

  log "VM creada."
  printf '\nSiguientes pasos:\n'
  printf '  1. qm start %s\n' "$VMID"
  printf '  2. Instalar pfSense (aceptar, instalar, reiniciar, quitar la ISO).\n'
  printf '  3. Asignar WAN=vtnet0, LAN=vtnet1, DMZ=vtnet2.\n'
  printf '  4. Restaurar el config.xml y renovar la WAN. Ver p5/LEEME.md.\n'
}

cmd_start() {
  require_root; need qm
  qm start "$VMID"
}

cmd_stop() {
  require_root; need qm
  qm shutdown "$VMID" || qm stop "$VMID"
}

cmd_info() {
  require_root; need qm
  qm config "$VMID" | grep -E '^(name|memory|cores|net[0-9]|scsi0|ide2|boot)'
}

CMD=${1:-help}
shift || true

case "$CMD" in
  mac)    cmd_mac "${1:-}" "${2:-}" ;;
  create) cmd_create ;;
  start)  cmd_start ;;
  stop)   cmd_stop ;;
  info)   cmd_info ;;
  -h|--help|help) usage ;;
  *)      usage; exit 1 ;;
esac
