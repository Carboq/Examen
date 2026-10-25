#!/usr/bin/env bash
# Genera las configuraciones de la P1 sustituyendo los marcadores {{ }} por
# los valores de un fichero .env.
#
#   cp valores.env.example valores.env
#   $EDITOR valores.env
#   ./generar.sh
#
# El resultado queda en out/ listo para pegar en la CLI de Packet Tracer.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

VALUES=${1:-$HERE/valores.env}
OUT=${OUT:-$HERE/out}
CONFIGS=${CONFIGS:-$HERE/configs}

[[ -f $VALUES ]] || die "No existe $VALUES. Copia valores.env.example a valores.env."
[[ -d $CONFIGS ]] || die "No existe el directorio $CONFIGS."

mapfile -t files < <(find "$CONFIGS" -maxdepth 1 -name '*.txt' | sort)
[[ ${#files[@]} -gt 0 ]] || die "No hay ficheros .txt en $CONFIGS."

mkdir -p "$OUT"
rm -f "$OUT"/*.txt

# Lee clave=valor; ignora comentarios y líneas vacías. Recorta espacios.
load_values() {
  local line key val
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    [[ -z ${line// /} ]] && continue
    [[ $line == \#* ]] && continue
    line=${line#export }
    key=${line%%=*}
    val=${line#*=}
    key=${key//[[:space:]]/}
    val=${val#"${val%%[![:space:]]*}"}
    val=${val%"${val##*[![:space:]]}"}
    val=${val%\"}
    val=${val#\"}
    [[ -n $key ]] || continue
    printf '%s=%s\n' "$key" "$val"
  done < "$VALUES"
}

declare -A values=()
while IFS='=' read -r k v; do
  [[ -n $k ]] && values[$k]=$v
done < <(load_values)

[[ ${#values[@]} -gt 0 ]] || die "No he leído ningún valor de $VALUES."

pending=0
for src in "${files[@]}"; do
  name=$(basename "$src")
  dst="$OUT/$name"
  cp "$src" "$dst"

  for k in "${!values[@]}"; do
    # Sustitución literal: los valores no contienen caracteres especiales de sed.
    sed -i "s|{{$k}}|${values[$k]}|g" "$dst"
  done

  if grep -q '{{' "$dst"; then
    warn "$name: quedan marcadores sin sustituir:"
    grep -o '{{[^}]*}}' "$dst" | sort -u | sed 's/^/    /' >&2
    (( pending++ ))
  else
    log "$name: completo"
  fi
done

if (( pending > 0 )); then
  warn "Hay $pending fichero(s) con marcadores. Revisa $VALUES y vuelve a ejecutar."
  exit 2
fi

log "Configuraciones generadas en $OUT"
