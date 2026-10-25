#!/usr/bin/env bash
# Práctica 3: medición de prestaciones con fio.
#
#   ./bench.sh run --target /mnt/raid5
#   ./bench.sh report
#
# Genera resultados/resultados.csv y guarda la salida completa de fio en
# resultados/raw/. La tabla se puede pasar a la memoria.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
load_config "${CONFIG:-$HERE/../config.env}"

TARGET=${MNT:-/mnt/raid5}
SIZES=${SIZES:-"4k 64k 1M"}
RUNTIME=${RUNTIME:-15}
OUT="$HERE/resultados"
RAW="$OUT/raw"

usage() {
  cat <<'EOF'
Uso: bench.sh <orden> [opciones]

Órdenes:
  run       Ejecuta la batería de fio y escribe resultados.csv.
  report    Muestra la tabla de resultados.
  clean     Borra los resultados anteriores.

Opciones de run:
  --target RUTA     Punto de montaje a medir (por defecto /mnt/raid5).
  --sizes "LISTA"   Tamaños de bloque (por defecto "4k 64k 1M").
  --runtime S       Duración de cada prueba en segundos (por defecto 15).

Pruebas: lectura y escritura secuencial y aleatoria, con iodepth 16.
Requiere fio instalado en la MV.
EOF
}

parse_bw() {
  local file=$1 val unit
  read -r val unit < <(sed -n 's/.*BW=\([0-9.]*\)\([KMG]\)i\?B\/s.*/\1 \2/p' "$file" | head -n1) || true
  if [[ -z ${val:-} ]]; then
    echo 0
    return
  fi
  awk -v v="$val" -v u="$unit" 'BEGIN {
    if (u == "K") v /= 1024;
    else if (u == "G") v *= 1024;
    printf "%.1f", v
  }'
}

parse_iops() {
  local file=$1 iops
  iops=$(sed -n 's/.*IOPS=\([0-9.]*[kKmM]*\).*/\1/p' "$file" | head -n1)
  echo "${iops:-0}"
}

cmd_run() {
  need fio
  [[ -d $TARGET ]] || die "No existe $TARGET. Monta antes la matriz o el disco."
  mountpoint -q "$TARGET" || warn "$TARGET no es un punto de montaje; se mide el sistema de ficheros que lo contiene."

  mkdir -p "$RAW"
  local csv="$OUT/resultados.csv"
  printf 'prueba,bs,bw_MiB_s,iops\n' > "$csv"

  local bs rw bw iops
  for bs in $SIZES; do
    for rw in read write randread randwrite; do
      log "fio: $rw  bs=$bs  runtime=${RUNTIME}s"
      fio --name="$rw-$bs" \
          --filename="$TARGET/fio.dat" \
          --size=512M \
          --direct=1 \
          --rw="$rw" \
          --bs="$bs" \
          --ioengine=libaio \
          --iodepth=16 \
          --numjobs=1 \
          --runtime="$RUNTIME" \
          --time_based \
          --group_reporting \
          > "$RAW/$rw-$bs.txt" 2>&1 \
        || die "fio falló en $rw/$bs. Revisa $RAW/$rw-$bs.txt"

      bw=$(parse_bw "$RAW/$rw-$bs.txt")
      iops=$(parse_iops "$RAW/$rw-$bs.txt")
      printf '%s,%s,%s,%s\n' "$rw" "$bs" "$bw" "$iops" >> "$csv"
    done
  done

  log "Resultados en $csv"
  cmd_report
}

cmd_report() {
  [[ -f "$OUT/resultados.csv" ]] || die "Todavía no hay resultados: ejecuta 'run'."
  if command -v column >/dev/null 2>&1; then
    column -t -s, "$OUT/resultados.csv"
  else
    cat "$OUT/resultados.csv"
  fi
}

cmd_clean() {
  rm -rf "$OUT"
  log "Resultados borrados."
}

CMD=${1:-help}
shift || true

case "$CMD" in
  run)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --target) TARGET=${2:?}; shift 2 ;;
        --target=*) TARGET=${1#*=}; shift ;;
        --sizes) SIZES=${2:?}; shift 2 ;;
        --sizes=*) SIZES=${1#*=}; shift ;;
        --runtime) RUNTIME=${2:?}; shift 2 ;;
        --runtime=*) RUNTIME=${1#*=}; shift ;;
        *) die "Opción desconocida: $1" ;;
      esac
    done
    cmd_run ;;
  report) cmd_report ;;
  clean)  cmd_clean ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
