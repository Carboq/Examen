#!/usr/bin/env bash
# Práctica 5 en el host Proxmox: calcula la MAC, crea la VM y la arranca.
#
#   ./icd.sh p5 todo --mac-base BC:24:11:0A:1B:2C --pc 7
#   ./icd.sh p5 todo --mac BC:24:11:0A:11:07
#
# La instalación de pfSense y la restauración del config.xml siguen siendo
# manuales: este script deja la VM preparada y recuerda los pasos.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
load_config "${CONFIG:-$HERE/../config.env}"

MAC_BASE=""
PC=""
MAC=${P5_MAC:-}
VMID_OVERRIDE=""
ISO_OVERRIDE=""
START=1
YES=0

usage() {
  cat <<'EOF'
Uso: todo.sh [opciones]

  --mac-base MAC    MAC de la primera VM (para calcular la reservada).
  --pc NUMERO       Número de PC (se usa con --mac-base).
  --mac MAC         MAC ya calculada (alternativa a --mac-base/--pc).
  --vmid ID         ID de la VM (sobrescribe P5_VMID).
  --iso VOLID       ISO de pfSense (sobrescribe P5_ISO).
  --no-start        Crea la VM pero no la arranca.
  --yes             No pedir confirmación.
  -h, --help        Esta ayuda.

La MAC se calcula conservando los 4 primeros octetos y poniendo
11:<PC en hexadecimal>. Ejemplo: BC:24:11:0A:1B:2C + PC 7 -> BC:24:11:0A:11:07
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mac-base) MAC_BASE=${2:?}; shift 2 ;;
    --mac-base=*) MAC_BASE=${1#*=}; shift ;;
    --pc) PC=${2:?}; shift 2 ;;
    --pc=*) PC=${1#*=}; shift ;;
    --mac) MAC=${2:?}; shift 2 ;;
    --mac=*) MAC=${1#*=}; shift ;;
    --vmid) VMID_OVERRIDE=${2:?}; shift 2 ;;
    --vmid=*) VMID_OVERRIDE=${1#*=}; shift ;;
    --iso) ISO_OVERRIDE=${2:?}; shift 2 ;;
    --iso=*) ISO_OVERRIDE=${1#*=}; shift ;;
    --no-start) START=0; shift ;;
    --yes) YES=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    *) die "Opción desconocida: $1" ;;
  esac
done

if [[ -n $MAC_BASE || -n $PC ]]; then
  [[ -n $MAC_BASE && -n $PC ]] || die "Indica --mac-base y --pc juntos."
  MAC=$(bash "$HERE/pfsense.sh" mac "$MAC_BASE" "$PC" | tail -n 1)
  log "MAC reservada calculada: $MAC"
fi

[[ -n ${MAC// /} ]] \
  || die "Define P5_MAC en config.env o pasa --mac / --mac-base + --pc."
[[ -n ${ISO_OVERRIDE:-${P5_ISO:-}} ]] \
  || die "Define P5_ISO en config.env o pasa --iso."

VMID=${VMID_OVERRIDE:-${P5_VMID:-250}}
require_root
need qm

if qm status "$VMID" >/dev/null 2>&1; then
  warn "La VM $VMID ya existe; no se crea otra."
else
  args=(create --mac "$MAC")
  [[ -n $VMID_OVERRIDE ]] && args+=(--vmid "$VMID_OVERRIDE")
  [[ -n $ISO_OVERRIDE ]] && args+=(--iso "$ISO_OVERRIDE")
  [[ $YES -eq 1 ]] && args+=(--yes)
  bash "$HERE/pfsense.sh" "${args[@]}"
fi

if [[ $START -eq 1 ]]; then
  if qm status "$VMID" 2>/dev/null | grep -q running; then
    log "La VM $VMID ya está arrancada."
  else
    qm start "$VMID"
  fi
fi

cat <<EOF

VM $VMID preparada con MAC de WAN $MAC.

Siguiente, en la consola de Proxmox:
  1. Instala pfSense (aceptar, instalar, reiniciar).
  2. Quita la ISO y arranca del disco:
       qm set $VMID --delete ide2 --boot order=scsi0
  3. Asigna las interfaces:
       WAN = vtnet0, LAN = vtnet1, DMZ = vtnet2
  4. Restaura p5/config.xml:
       Diagnostics -> Backup & Restore -> Restore
  5. Si cambian las redes, ajusta LAN/DMZ/DHCP/NAT después de restaurar.
  6. Renueva la WAN si se queda sin IP.

Guía completa: p5/LEEME.md
EOF
