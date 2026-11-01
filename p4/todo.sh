#!/usr/bin/env bash
# Práctica 4 en el host Proxmox: crea las VM y las arranca.
#
#   ./icd.sh p4 todo
#   ./icd.sh p4 todo --file p4/vms.conf --no-start
#
# Después hay que instalar Debian dentro de cada VM y ejecutar
# p4/servicios.sh en cada una. Este script imprime los comandos exactos.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
load_config "${CONFIG:-$HERE/../config.env}"

FILE="$HERE/vms.conf"
START=1

usage() {
  cat <<'EOF'
Uso: todo.sh [opciones]

  --file FICHERO    Fichero de VM (por defecto p4/vms.conf).
  --no-start        Crea las VM pero no las arranca.
  -h, --help        Esta ayuda.

Formato de cada línea:
  nombre|vmid|RAM_MB|vCPU|disco_GB|bridge|mac|iso
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE=${2:?}; shift 2 ;;
    --file=*) FILE=${1#*=}; shift ;;
    --no-start) START=0; shift ;;
    -h|--help|help) usage; exit 0 ;;
    *) die "Opción desconocida: $1" ;;
  esac
done

if [[ ! -f $FILE ]]; then
  if [[ $FILE == "$HERE/vms.conf" && -f "$HERE/vms.conf.example" ]]; then
    cp "$HERE/vms.conf.example" "$FILE"
    warn "He creado $FILE desde el ejemplo. Revísalo antes de continuar."
  else
    die "No existe $FILE."
  fi
fi

bash "$HERE/vms.sh" create --file "$FILE"

if [[ $START -eq 1 ]]; then
  while IFS='|' read -r name vmid mem cores disk bridge mac iso; do
    [[ -z ${name// /} ]] && continue
    [[ $name == \#* ]] && continue
    [[ -n ${vmid// /} ]] || continue

    [[ -n ${iso// /} ]] \
      || warn "VM $name ($vmid) sin ISO: si el disco está vacío, instálala o clónala antes de arrancar."

    if qm status "$vmid" 2>/dev/null | grep -q running; then
      log "VM $vmid ($name) ya está arrancada."
    else
      log "Arrancando VM $vmid ($name)..."
      qm start "$vmid"
    fi
  done < "$FILE"
fi

printf '\n%-8s %-6s %-15s %s\n' "VM" "VMID" "IP sugerida" "Rol"
while IFS='|' read -r name vmid mem cores disk bridge mac iso; do
  [[ -z ${name// /} ]] && continue
  [[ $name == \#* ]] && continue
  [[ -n ${vmid// /} ]] || continue

  case "$name" in
    web1) ip=192.168.50.11 ;;
    web2) ip=192.168.50.12 ;;
    app)  ip=192.168.50.13 ;;
    *)    ip="<IP>" ;;
  esac
  printf '%-8s %-6s %-15s %s\n' "$name" "$vmid" "$ip" "$name"
done < "$FILE"

cat <<'EOF'

Siguiente:
  1. Instala Debian 12 en cada VM (consola de Proxmox) o clona una plantilla.
  2. Configura la IP de cada VM (docs/simulacros/P4.md, fase 2).
  3. Copia este repositorio a cada VM y ejecuta su rol:
       scp -r . root@192.168.50.11:/root/Examen
       ssh root@192.168.50.11 'cd /root/Examen && ./p4/servicios.sh web1'
     (repite con .12/web2 y .13/app)
  4. Valida desde otra VM:
       curl http://192.168.50.13/salud

Si no hay SSH, entra por la consola de Proxmox y ejecuta el mismo comando.
Guía completa: docs/simulacros/P4.md
EOF
