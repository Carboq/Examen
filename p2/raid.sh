#!/usr/bin/env bash
# Práctica 2: RAID 5 con tres discos activos y uno de repuesto.
# También sirve de base para la Práctica 3 (matriz sobre la que medir).
#
#   ./raid.sh detect
#   ./raid.sh create --disks sdb,sdc,sdd,sde
#   ./raid.sh fail
#   ./raid.sh add sdb
#   ./raid.sh status
#   ./raid.sh cleanup

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
load_config "${CONFIG:-$HERE/../config.env}"

MD=${MD:-/dev/md0}
LEVEL=${LEVEL:-5}
ACTIVE=${ACTIVE:-3}
SPARES=${SPARES:-1}
FS=${FS:-ext4}
MNT=${MNT:-/mnt/raid5}
DISKS=${DISKS:-}
STATE=${STATE:-/run/icd-raid.devices}
FORCE=0
ASSUME_CLEAN=0

usage() {
  cat <<'EOF'
Uso: raid.sh <orden> [opciones]

Órdenes:
  detect                  Lista los discos que se pueden usar.
  create --disks LISTA    Crea la matriz. LISTA = sdb,sdc,sdd,sde
  fail [dispositivo]      Marca un disco como averiado y lo retira.
  add <dispositivo>       Reincorpora un disco a la matriz.
  status                  Muestra el estado de la matriz.
  cleanup                 Desmonta, para la matriz y borra las firmas.

Opciones:
  --disks LISTA   Discos separados por comas (sdb,sdc,...).
  --level N       Nivel de RAID (por defecto 5).
  --active N      Discos activos (por defecto 3).
  --spares N      Discos de repuesto (por defecto 1).
  --fs TIPO       Sistema de ficheros: ext4, xfs (por defecto ext4).
  --mount RUTA    Punto de montaje (por defecto /mnt/raid5).
  --md DISPOSITIVO  Matriz (por defecto /dev/md0).
  --force         Borra firmas existentes en los discos. DESTRUCTIVO.
  --assume-clean  Omite la sincronización inicial (rápido en laboratorio).
  --yes           No pedir confirmación.
  -h, --help      Esta ayuda.

El número total de discos debe ser --active + --spares.
EOF
}

# --- utilidades ------------------------------------------------------

disk_row() {
  local d=$1
  lsblk -dn -o SIZE,MODEL,SERIAL "$d" | awk '{printf "%-8s %-28s %s\n", $1, $2, $3}'
}

list_devs() {
  local d
  for d in "$@"; do
    printf '  %-10s %s\n' "$d" "$(disk_row "$d")"
  done
}

# --- órdenes ---------------------------------------------------------

cmd_detect() {
  require_root
  need lsblk
  need wipefs

  local root_src root_disk name size type model
  root_src=$(findmnt -n -o SOURCE / || true)
  root_disk=""
  if [[ -n $root_src ]]; then
    root_disk=$(lsblk -nlo PKNAME "$root_src" 2>/dev/null | head -n1 || true)
    [[ -n $root_disk ]] || root_disk=$(basename "$root_src")
  fi

  log "Disco del sistema: ${root_disk:-no identificado}"
  printf '\n%-12s %-8s %-10s %s\n' "DISCO" "TAMAÑO" "TIPO" "MODELO"

  while read -r name size type model; do
    [[ $type == disk ]] || continue
    [[ $(basename "$name") == "$root_disk" ]] && continue
    lsblk -nlo MOUNTPOINT "$name" | grep -q . && continue
    lsblk -nlo TYPE "$name" | grep -q '^raid' && continue

    local note=""
    wipefs -n "$name" 2>/dev/null | grep -q . && note=" (con firmas: usa --force)"
    printf '%-12s %-8s %-10s %s%s\n' "$name" "$size" "$type" "$model" "$note"
  done < <(lsblk -dnpo NAME,SIZE,TYPE,MODEL)

  printf '\nSugerencia: ./icd.sh p2 create --disks sdb,sdc,sdd,sde\n'
}

cmd_create() {
  require_root
  need mdadm
  need wipefs
  need lsblk

  [[ -n $DISKS ]] || die "Indica los discos con --disks sdb,sdc,sdd,sde (o usa 'detect')."

  IFS=', ' read -r -a raw <<< "$DISKS"
  local devs=() d
  for d in "${raw[@]}"; do
    [[ -n $d ]] && devs+=("$(norm_dev "$d")")
  done

  local total=$((ACTIVE + SPARES))
  [[ ${#devs[@]} -eq $total ]] \
    || die "Se esperaban $total discos (activos + repuesto) y hay ${#devs[@]}."

  for d in "${devs[@]}"; do
    [[ -b $d ]] || die "$d no es un dispositivo de bloque."
  done

  if [[ -e $MD ]]; then
    die "Ya existe $MD. Usa 'status' o 'cleanup' antes de crear otra matriz."
  fi

  if [[ $FORCE -eq 1 ]]; then
    warn "Modo --force: se borrarán las firmas de los discos indicados."
    for d in "${devs[@]}"; do
      mdadm --zero-superblock "$d" 2>/dev/null || true
      wipefs -a "$d" >/dev/null 2>&1 || true
    done
  else
    for d in "${devs[@]}"; do
      if ! disk_is_free "$d"; then
        die "$d no está libre (montado, en una matriz o con firmas). Revisa con 'detect' o usa --force si estás seguro)."
      fi
    done
  fi

  log "Matriz a crear: $MD  nivel $LEVEL  activos $ACTIVE  repuesto $SPARES"
  list_devs "${devs[@]}"
  confirm "¿Crear la matriz y formatear $MD?" || die "Cancelado."

  local create_args=(--run --level="$LEVEL" --raid-devices="$ACTIVE" --spare-devices="$SPARES")
  [[ $ASSUME_CLEAN -eq 1 ]] && create_args+=(--assume-clean)

  mdadm --create "$MD" "${create_args[@]}" "${devs[@]}"

  printf '%s\n' "${devs[@]}" > "$STATE"

  log "Esperando a que termine la sincronización..."
  wait_sync "$MD" 300

  case "$FS" in
    ext4) mkfs.ext4 -F -L raid5 "$MD" ;;
    xfs)  mkfs.xfs -f -L raid5 "$MD" ;;
    *)    die "Sistema de ficheros no soportado: $FS" ;;
  esac

  mkdir -p "$MNT"
  mount "$MD" "$MNT"
  log "Montado en $MNT"

  log "Prueba de escritura y lectura..."
  dd if=/dev/urandom of="$MNT/prueba.bin" bs=1M count=64 status=none
  sync
  local h1 h2
  h1=$(sha256sum "$MNT/prueba.bin" | awk '{print $1}')
  echo 3 > /proc/sys/vm/drop_caches
  h2=$(sha256sum "$MNT/prueba.bin" | awk '{print $1}')
  [[ $h1 == $h2 ]] || die "La verificación de integridad ha fallado."
  log "Integridad verificada (sha256 coincide)."

  df -h "$MNT"
  printf '\n'
  mdadm --detail "$MD"
}

cmd_fail() {
  require_root
  need mdadm
  [[ -e $MD ]] || die "No existe $MD."

  local dev=${1:-}
  if [[ -z $dev ]]; then
    dev=$(mdadm --detail "$MD" | awk '/active sync/ {print $NF; exit}')
  fi
  [[ -n $dev ]] || die "No encuentro un disco activo en $MD."
  dev=$(norm_dev "$dev")

  log "Marcando $dev como averiado..."
  mdadm --fail "$MD" "$dev"
  mdadm --remove "$MD" "$dev" || true

  log "Esperando a que el repuesto reconstruya la matriz..."
  wait_sync "$MD" 300

  printf '\n'
  mdadm --detail "$MD"
  printf '\n'
  cat /proc/mdstat
}

cmd_add() {
  require_root
  need mdadm
  [[ -e $MD ]] || die "No existe $MD."
  local dev=${1:-}
  [[ -n $dev ]] || die "Indica el disco: ./raid.sh add sdb"
  dev=$(norm_dev "$dev")
  [[ -b $dev ]] || die "$dev no es un dispositivo de bloque."

  log "Añadiendo $dev a $MD..."
  mdadm --add "$MD" "$dev"
  wait_sync "$MD" 300
  mdadm --detail "$MD"
}

cmd_status() {
  require_root
  [[ -e $MD ]] || die "No existe $MD."
  cat /proc/mdstat
  printf '\n'
  mdadm --detail "$MD"
  if mountpoint -q "$MNT"; then
    printf '\n'
    df -h "$MNT"
  fi
}

cmd_cleanup() {
  require_root
  need mdadm

  if mountpoint -q "$MNT"; then
    log "Desmontando $MNT..."
    umount "$MNT" || die "No se pudo desmontar $MNT."
  fi

  if [[ -e $MD ]]; then
    log "Parando $MD..."
    mdadm --stop "$MD" || warn "No se pudo parar $MD."
  fi

  local devs=()
  if [[ -f $STATE ]]; then
    mapfile -t devs < "$STATE"
  fi

  if [[ ${#devs[@]} -eq 0 ]]; then
    warn "No hay lista de discos guardada; no borro firmas."
    warn "Si quieres borrarlas, pásalos a mano: mdadm --zero-superblock /dev/sdb ..."
    return 0
  fi

  local d
  for d in "${devs[@]}"; do
    [[ -b $d ]] || continue
    log "Borrando firma de $d..."
    mdadm --zero-superblock "$d" 2>/dev/null || true
    wipefs -a "$d" >/dev/null 2>&1 || true
  done
  rm -f "$STATE"
  log "Limpieza terminada."
}

# --- argumentos ------------------------------------------------------

CMD=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    detect|create|fail|add|status|cleanup) CMD=$1; shift ;;
    --disks) DISKS=${2:?}; shift 2 ;;
    --disks=*) DISKS=${1#*=}; shift ;;
    --level) LEVEL=${2:?}; shift 2 ;;
    --active) ACTIVE=${2:?}; shift 2 ;;
    --spares) SPARES=${2:?}; shift 2 ;;
    --fs) FS=${2:?}; shift 2 ;;
    --mount) MNT=${2:?}; shift 2 ;;
    --md) MD=${2:?}; shift 2 ;;
    --force) FORCE=1; shift ;;
    --assume-clean) ASSUME_CLEAN=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    -*) die "Opción desconocida: $1" ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

case "$CMD" in
  detect)  cmd_detect ;;
  create)  cmd_create ;;
  fail)    cmd_fail "${ARGS[0]:-}" ;;
  add)     cmd_add "${ARGS[0]:-}" ;;
  status)  cmd_status ;;
  cleanup) cmd_cleanup ;;
  *)       usage; exit 1 ;;
esac
