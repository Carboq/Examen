#!/usr/bin/env bash
# Entrada única del repositorio de examen.
# Uso: ./icd.sh <practica> <orden> [opciones]

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Uso: ./icd.sh <practica> [argumentos...]

Prácticas:
  p1        Packet Tracer: procedimiento y bloques de configuración.
            ./icd.sh p1            muestra la guía
            ./icd.sh p1 generar    genera los bloques desde p1/valores.env
  p2        RAID 5 con mdadm.          Ej.: ./icd.sh p2 detect
  p3        Prestaciones con fio/dd.   Ej.: ./icd.sh p3 run --target /mnt/raid5
  p4        VM en Proxmox.             Ej.: ./icd.sh p4 list
  p5        pfSense en Proxmox.        Ej.: ./icd.sh p5 mac BC:24:11:0A:1B:2C 7

Cada script tiene su propia ayuda: ./icd.sh p2 help
EOF
}

case "${1:-}" in
  p1|packet|tracer)
    shift
    if [[ ${1:-} == generar ]]; then
      exec "$HERE/p1/generar.sh"
    fi
    cat "$HERE/p1/LEEME.md"
    ;;
  p2|raid)
    shift
    exec "$HERE/p2/raid.sh" "$@"
    ;;
  p3|bench)
    shift
    exec "$HERE/p3/bench.sh" "$@"
    ;;
  p4|vms)
    shift
    exec "$HERE/p4/vms.sh" "$@"
    ;;
  p5|pfsense)
    shift
    exec "$HERE/p5/pfsense.sh" "$@"
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
