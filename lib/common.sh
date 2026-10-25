#!/usr/bin/env bash
# Funciones compartidas por los scripts del repositorio.
# No se ejecuta directamente: se carga con `source`.

if [[ -t 1 ]]; then
  C_BLUE=$'\033[1;34m'
  C_YEL=$'\033[1;33m'
  C_RED=$'\033[1;31m'
  C_OFF=$'\033[0m'
else
  C_BLUE=; C_YEL=; C_RED=; C_OFF=
fi

log()  { printf '%s[icd]%s %s\n' "$C_BLUE" "$C_OFF" "$*"; }
warn() { printf '%s[icd]%s %s\n' "$C_YEL" "$C_OFF" "$*" >&2; }
die()  { printf '%s[icd]%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "Falta el programa '$1'. Instálalo antes de continuar."
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Ejecuta este script como root (sudo)."
}

confirm() {
  local msg=${1:-"¿Continuar?"}
  if [[ ${ASSUME_YES:-0} -eq 1 ]]; then
    log "$msg -> sí (--yes)"
    return 0
  fi
  local r
  read -r -p "$msg [s/N] " r
  [[ $r == s || $r == S || $r == y || $r == Y ]]
}

load_config() {
  local f=${1:-}
  if [[ -n $f && -f $f ]]; then
    # shellcheck disable=SC1090
    source "$f"
    log "Configuración cargada: $f"
  fi
}

# Devuelve el dispositivo normalizado: sdb -> /dev/sdb
norm_dev() {
  local d=$1
  [[ $d == /dev/* ]] && printf '%s\n' "$d" || printf '/dev/%s\n' "$d"
}

# Comprueba que un disco se puede usar sin perder datos.
# Uso: disk_is_free /dev/sdb
disk_is_free() {
  local d=$1
  [[ -b $d ]] || return 1

  # Alguna partición (o el propio disco) montada.
  if lsblk -nlo MOUNTPOINT "$d" | grep -q .; then
    return 1
  fi

  # Ya forma parte de una matriz md.
  if lsblk -nlo TYPE "$d" | grep -q '^raid'; then
    return 1
  fi

  # Tiene alguna firma (tabla de particiones, sistema de ficheros, md...).
  if wipefs -n "$d" 2>/dev/null | grep -q .; then
    return 1
  fi

  return 0
}

# Espera a que la matriz termine de sincronizar.
# Uso: wait_sync /dev/md0 [segundos]
wait_sync() {
  local md=$1 timeout=${2:-600} i=0 name
  name=$(basename "$md")
  local action="/sys/block/$name/md/sync_action"

  [[ -r $action ]] || return 0
  while [[ $(cat "$action") != idle ]]; do
    (( i++ ))
    (( i * 5 >= timeout )) && { warn "La sincronización sigue en curso; continúo."; return 0; }
    sleep 5
  done
}
