#!/usr/bin/env bash
# Práctica 4: creación de máquinas virtuales en Proxmox con qm.
#
#   ./vms.sh list
#   ./vms.sh create --file vms.conf
#   ./vms.sh start 210
#   ./vms.sh destroy 210

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
load_config "${CONFIG:-$HERE/../config.env}"

STORAGE=${STORAGE:-local-lvm}
FILE="$HERE/vms.conf"

usage() {
  cat <<'EOF'
Uso: vms.sh <orden> [opciones]

Órdenes:
  list                 Lista las VM del host (qm list).
  create [--file F]    Crea las VM descritas en el fichero.
  start <vmid>         Arranca una VM.
  stop <vmid>          Para una VM.
  destroy <vmid>       Elimina una VM (pide confirmación).

Formato del fichero (una VM por línea, campos separados por |):
  nombre|vmid|RAM_MB|vCPU|disco_GB|bridge|mac|iso

  - mac e iso pueden quedar vacíos.
  - Las líneas que empiezan por # y las vacías se ignoran.

Ejemplo:
  web1|210|2048|2|16|vmbr1||local:iso/debian-12-netinst.iso
  web2|211|2048|2|16|vmbr1||
EOF
}

need_qm() {
  require_root
  need qm
  pvesm status >/dev/null 2>&1 || die "pvesm no responde: ¿estás en el host Proxmox?"
}

cmd_list() {
  need_qm
  qm list
}

cmd_create() {
  need_qm
  [[ -f $FILE ]] || die "No existe $FILE. Copia vms.conf.example o indica --file."

  local created=0 name vmid mem cores disk bridge mac iso extra
  while IFS='|' read -r name vmid mem cores disk bridge mac iso; do
    [[ -z ${name// /} ]] && continue
    [[ $name == \#* ]] && continue
    [[ -n ${vmid// /} ]] || die "Línea sin vmid: $name"

    if qm status "$vmid" >/dev/null 2>&1; then
      warn "La VM $vmid ya existe; se omite."
      continue
    fi

    local net="virtio,bridge=$bridge"
    [[ -n ${mac// /} ]] && net+=",macaddr=$mac"

    local args=(--name "$name" --memory "$mem" --cores "$cores" --ostype l26
                --scsihw virtio-scsi-pci --scsi0 "$STORAGE:$disk" --net0 "$net")

    if [[ -n ${iso// /} ]]; then
      args+=(--ide2 "$iso,media=cdrom" --boot order=ide2)
    fi

    log "Creando VM $vmid ($name): ${mem} MB, ${cores} vCPU, ${disk} GB, $bridge"
    qm create "$vmid" "${args[@]}"
    (( created++ ))
  done < "$FILE"

  log "VM creadas: $created. Instala el sistema operativo desde la consola."
  log "Tras instalar, quita la ISO y arranca del disco: qm set <vmid> --delete ide2 --boot order=scsi0"
  qm list
}

cmd_start() {
  need_qm
  local vmid=${1:-}; [[ -n $vmid ]] || die "Indica el vmid."
  qm start "$vmid"
}

cmd_stop() {
  need_qm
  local vmid=${1:-}; [[ -n $vmid ]] || die "Indica el vmid."
  qm shutdown "$vmid" || qm stop "$vmid"
}

cmd_destroy() {
  need_qm
  local vmid=${1:-}; [[ -n $vmid ]] || die "Indica el vmid."
  confirm "¿Eliminar la VM $vmid y sus discos?" || die "Cancelado."
  qm stop "$vmid" 2>/dev/null || true
  qm destroy "$vmid" --purge
}

CMD=${1:-help}
shift || true

case "$CMD" in
  list)    cmd_list ;;
  create)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --file) FILE=${2:?}; shift 2 ;;
        --file=*) FILE=${1#*=}; shift ;;
        *) die "Opción desconocida: $1" ;;
      esac
    done
    cmd_create ;;
  start)   cmd_start "${1:-}" ;;
  stop)    cmd_stop "${1:-}" ;;
  destroy) cmd_destroy "${1:-}" ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
