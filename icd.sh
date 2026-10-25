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
            ./icd.sh p1 todo       genera los bloques y muestra los pasos
            ./icd.sh p1            muestra la guía
  p2        RAID 5 con mdadm.          Ej.: ./icd.sh p2 todo sdb,sdc,sdd,sde
  p3        Prestaciones con fio/dd.   Ej.: ./icd.sh p3 todo
  p4        VM en Proxmox.             Ej.: ./icd.sh p4 todo
            Servicios dentro de la VM:  ./icd.sh p4 servicios app
  p5        pfSense en Proxmox.        Ej.: ./icd.sh p5 todo --mac-base MAC --pc 7

Cada script tiene su propia ayuda: ./icd.sh p2 help
Guía paso a paso: docs/GUIA_EJECUCION.md
EOF
}

case "${1:-}" in
  p1|packet|tracer)
    shift
    case "${1:-}" in
      generar) shift; exec bash "$HERE/p1/generar.sh" "$@" ;;
      todo|auto) shift; exec bash "$HERE/p1/todo.sh" "$@" ;;
    esac
    cat "$HERE/p1/LEEME.md"
    ;;
  p2|raid)
    shift
    if [[ ${1:-} == todo || ${1:-} == auto ]]; then
      shift
      exec bash "$HERE/p2/todo.sh" "$@"
    fi
    exec bash "$HERE/p2/raid.sh" "$@"
    ;;
  p3|bench)
    shift
    if [[ ${1:-} == todo || ${1:-} == auto ]]; then
      shift
      exec bash "$HERE/p3/todo.sh" "$@"
    fi
    exec bash "$HERE/p3/bench.sh" "$@"
    ;;
  p4|vms)
    shift
    case "${1:-}" in
      servicios) shift; exec bash "$HERE/p4/servicios.sh" "$@" ;;
      todo|auto) shift; exec bash "$HERE/p4/todo.sh" "$@" ;;
    esac
    exec bash "$HERE/p4/vms.sh" "$@"
    ;;
  p5|pfsense)
    shift
    if [[ ${1:-} == todo || ${1:-} == auto ]]; then
      shift
      exec bash "$HERE/p5/todo.sh" "$@"
    fi
    exec bash "$HERE/p5/pfsense.sh" "$@"
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
