#!/usr/bin/env bash
# Comprobaciones del examen de 7 puntos: Evaluación de Prestaciones.
# Ejecutar dentro de la VM Debian, preferiblemente con sudo.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$HERE/resultados}"

log()  { printf '[check] %s\n' "$*"; }
warn() { printf '[check] AVISO: %s\n' "$*" >&2; }
die()  { printf '[check] ERROR: %s\n' "$*" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "Falta el programa '$1'."
}

need lsblk
need findmnt
need df
need mountpoint

log "Disco del sistema:"
findmnt -n -o SOURCE / || true
lsblk -s -nlo NAME,TYPE "$(findmnt -n -o SOURCE /)" 2>/dev/null || true

echo
log "Discos y particiones:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL,SERIAL,MOUNTPOINT

echo
for target in /mnt/HDD /mnt/SDD /mnt/RAID; do
  if mountpoint -q "$target"; then
    log "OK: $target es un punto de montaje."
    df -h "$target" | tail -n 1
  else
    warn "FALLO: $target no es un punto de montaje."
  fi
done

echo
if [[ -e /dev/md0 ]]; then
  log "Estado del RAID:"
  cat /proc/mdstat || true
  echo
  mdadm --detail /dev/md0 2>/dev/null || warn "No se pudo leer mdadm --detail /dev/md0."
else
  warn "No existe /dev/md0."
fi

echo
if [[ -f "$OUT/lectura.csv" && -f "$OUT/escritura.csv" ]]; then
  log "CSV encontrados en $OUT"
  wc -l "$OUT/lectura.csv" "$OUT/escritura.csv"
else
  warn "Todavía no están los CSV en $OUT."
fi

echo
log "Comprobación terminada. Revisa los AVISOS antes de entregar."
