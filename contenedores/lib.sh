#!/usr/bin/env bash
# Funciones comunes para los contenedores LXC de P4 y P5.
# Se cargan con `source`; no se ejecutan directamente.

# Comprueba que estamos en el host Proxmox y que existen las herramientas.
lxc_require() {
  require_root
  need pct
  need pveam
  need pvesm
  [[ -d /etc/pve ]] \
    || die "Este script debe ejecutarse en el host Proxmox, no dentro de una VM."
  pvesm status >/dev/null 2>&1 \
    || die "pvesm no responde. ¿Estás en el host Proxmox?"
}

# Extrae el almacenamiento de un volid de plantilla: local:vztmpl/x -> local.
lxc_template_storage() {
  printf '%s\n' "${1%%:*}"
}

# Comprueba que la plantilla está descargada.
lxc_check_template() {
  local tpl=$1 store name
  store=$(lxc_template_storage "$tpl")
  name=$(basename "$tpl")
  pveam list "$store" 2>/dev/null | grep -Fq "$name" \
    || die "No encuentro la plantilla $tpl. Descárgala en el host con:
  pveam update
  pveam download $store $name"
}

lxc_exists() {
  pct status "$1" >/dev/null 2>&1
}

# Espera a que el contenedor acepte comandos.
lxc_wait() {
  local id=$1 i
  for i in {1..60}; do
    if pct exec "$id" -- true >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  die "El contenedor $id no ha arrancado o no acepta comandos."
}

lxc_ensure_started() {
  local id=$1
  if ! pct status "$id" 2>/dev/null | grep -q running; then
    log "Arrancando el contenedor $id..."
    pct start "$id"
  fi
  lxc_wait "$id"
}

# Crea un contenedor si no existe.
# Uso:
#   lxc_create ID NOMBRE IP BRIDGE GW PLANTILLA STORAGE RAM vCPU DISCO \
#              PASSWORD DNS UNPRIVILEGED SWAP FEATURES
lxc_create() {
  local id=$1 name=$2 ip=$3 bridge=$4 gw=$5 tpl=$6 storage=$7
  local mem=$8 cores=$9 disk=${10} pass=${11} dns=${12}
  local unpriv=${13} swap=${14} features=${15}
  local args=()

  if lxc_exists "$id"; then
    warn "El contenedor $id ($name) ya existe; se omite."
    return 0
  fi

  args=(
    --hostname "$name"
    --memory "$mem"
    --cores "$cores"
    --swap "$swap"
    --rootfs "$storage:$disk"
    --net0 "name=eth0,bridge=$bridge,ip=$ip/24,gw=$gw"
    --nameserver "$dns"
    --onboot 1
    --start 1
    --unprivileged "$unpriv"
  )
  [[ -n $pass ]] && args+=(--password "$pass")
  [[ -n $features ]] && args+=(--features "$features")

  log "Creando LXC $id ($name): $ip/24 por $bridge, gw $gw"
  pct create "$id" "$tpl" "${args[@]}"
  lxc_wait "$id"
}

# Copia un script al contenedor y lo ejecuta como root.
# Uso: lxc_copy_and_run ID /ruta/script.sh [argumentos...]
lxc_copy_and_run() {
  local id=$1 script=$2 base
  shift 2
  base=$(basename "$script")
  pct push "$id" "$script" "/root/$base" --perms 755
  pct exec "$id" -- "/root/$base" "$@"
}

lxc_status_one() {
  local id=$1
  if ! lxc_exists "$id"; then
    printf '  %-6s no existe\n' "$id"
    return 0
  fi
  pct status "$id"
  pct exec "$id" -- hostname 2>/dev/null || true
  pct exec "$id" -- sh -c 'ip -4 -br addr show eth0 2>/dev/null || true' || true
}

lxc_destroy() {
  local id=$1
  if ! lxc_exists "$id"; then
    warn "El contenedor $id no existe; se omite."
    return 0
  fi
  confirm "¿Eliminar el contenedor $id y su disco?" || die "Cancelado."
  pct stop "$id" 2>/dev/null || true
  pct destroy "$id" --purge
}
