#!/usr/bin/env bash
# Benchmark del examen de 7 puntos: Evaluación de Prestaciones.
#
# Ejecutar DENTRO de la VM Debian, con /mnt/HDD, /mnt/SDD y /mnt/RAID montados:
#
#   sudo ./bench_dd.sh
#   sudo ./bench_dd.sh --out resultados
#   sudo ./bench_dd.sh --targets "/mnt/HDD /mnt/SSD /mnt/RAID"
#
# Genera:
#   resultados/escritura.csv
#   resultados/lectura.csv
#   resultados/resumen.txt
#
# No crea ni formatea particiones. Es un script de medición.

set -euo pipefail

OUT="${PWD}/resultados"
TARGETS_STR="/mnt/HDD /mnt/SDD /mnt/RAID"
SIZES_STR="1k 2k 4k 8k 16k 32k 64k 128k 256k"
KEEP=0
BYTES=$((1024 * 1024 * 1024))

log()  { printf '[bench] %s\n' "$*"; }
warn() { printf '[bench] AVISO: %s\n' "$*" >&2; }
die()  { printf '[bench] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Uso: bench_dd.sh [opciones]

Opciones:
  --targets "RUTAS"  Puntos de montaje separados por espacios.
                     Por defecto: "/mnt/HDD /mnt/SDD /mnt/RAID".
  --sizes "LISTA"    Tamaños de bloque separados por espacios.
                     Por defecto: "1k 2k 4k 8k 16k 32k 64k 128k 256k".
  --out DIR          Carpeta de resultados. Por defecto: ./resultados.
  --keep             No borrar los ficheros temporales de 1 GiB.
  -h, --help         Esta ayuda.

El script debe ejecutarse como root (sudo), porque escribe en los puntos de
montaje. Antes de medir comprueba que los tres destinos son puntos de montaje.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets) TARGETS_STR=${2:?}; shift 2 ;;
    --targets=*) TARGETS_STR=${1#*=}; shift ;;
    --sizes) SIZES_STR=${2:?}; shift 2 ;;
    --sizes=*) SIZES_STR=${1#*=}; shift ;;
    --out) OUT=${2:?}; shift 2 ;;
    --out=*) OUT=${1#*=}; shift ;;
    --keep) KEEP=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    *) die "Opción desconocida: $1" ;;
  esac
done

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Ejecuta con sudo: sudo ./bench_dd.sh"

need() {
  command -v "$1" >/dev/null 2>&1 || die "Falta el programa '$1'."
}

need dd
need awk
need date
need mountpoint
need df
need sort

read -r -a targets <<< "$TARGETS_STR"
read -r -a sizes <<< "$SIZES_STR"
[[ ${#targets[@]} -gt 0 ]] || die "No hay destinos."
[[ ${#sizes[@]} -gt 0 ]] || die "No hay tamaños de bloque."

for target in "${targets[@]}"; do
  [[ -d $target ]] || die "No existe el directorio $target."
  mountpoint -q "$target" || die "$target no es un punto de montaje. Monta antes HDD/SSD/RAID."
  avail=$(df -Pk "$target" | awk 'NR==2 {print $4}')
  (( avail > 2 * 1024 * 1024 )) \
    || die "$target tiene menos de 2 GiB libres; no cabe el fichero de 1 GiB."
done

mkdir -p "$OUT" "$OUT/logs"
write_csv="$OUT/escritura.csv"
read_csv="$OUT/lectura.csv"
summary="$OUT/resumen.txt"

printf 'DISPOSITIVO;BS;Tiempo;Tasa\n' > "$write_csv"
printf 'DISPOSITIVO;BS;Tiempo;Tasa\n' > "$read_csv"

run_dd() {
  # run_dd <log> <comando...>
  local logfile=$1
  shift
  "$@" >/dev/null 2>"$logfile"
}

measure_write() {
  local target=$1 name=$2 bs=$3 count=$4 file=$5 logfile=$6
  local start end elapsed rate

  rm -f "$file"
  start=$(date +%s%N)
  if ! run_dd "$logfile" dd if=/dev/zero of="$file" bs="$bs" count="$count" \
      oflag=direct conv=fsync status=none; then
    warn "Escritura directa falló en $name/$bs; reintento sin oflag=direct."
    start=$(date +%s%N)
    run_dd "$logfile" dd if=/dev/zero of="$file" bs="$bs" count="$count" \
      conv=fsync status=none
  fi
  end=$(date +%s%N)
  elapsed=$(awk -v ns="$((end - start))" 'BEGIN {printf "%.3f", ns / 1000000000}')
  rate=$(awk -v b="$BYTES" -v s="$elapsed" 'BEGIN {
    if (s <= 0) s = 0.001;
    printf "%.2f", (b / 1000000) / s
  }')
  printf '%s;%s;%s;%s\n' "$name" "$bs" "$elapsed" "$rate" >> "$write_csv"
  printf '  escritura %-4s %-4s %8s s %10s MB/s\n' "$name" "$bs" "$elapsed" "$rate"
}

measure_read() {
  local target=$1 name=$2 bs=$3 count=$4 file=$5 logfile=$6
  local start end elapsed rate

  sync
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
  fi

  start=$(date +%s%N)
  if ! run_dd "$logfile" dd if="$file" of=/dev/null bs="$bs" count="$count" \
      iflag=direct status=none; then
    warn "Lectura directa falló en $name/$bs; reintento sin iflag=direct."
    start=$(date +%s%N)
    run_dd "$logfile" dd if="$file" of=/dev/null bs="$bs" count="$count" status=none
  fi
  end=$(date +%s%N)
  elapsed=$(awk -v ns="$((end - start))" 'BEGIN {printf "%.3f", ns / 1000000000}')
  rate=$(awk -v b="$BYTES" -v s="$elapsed" 'BEGIN {
    if (s <= 0) s = 0.001;
    printf "%.2f", (b / 1000000) / s
  }')
  printf '%s;%s;%s;%s\n' "$name" "$bs" "$elapsed" "$rate" >> "$read_csv"
  printf '  lectura   %-4s %-4s %8s s %10s MB/s\n' "$name" "$bs" "$elapsed" "$rate"
}

log "Destinos: ${targets[*]}"
log "Tamaños:  ${sizes[*]}"
log "Salida:   $OUT"

for target in "${targets[@]}"; do
  name=$(basename "$target")
  for bs in "${sizes[@]}"; do
    [[ $bs == *k ]] || die "Tamaño no válido: $bs (usa 1k, 2k, ...)."
    count=$((BYTES / (${bs%k} * 1024)))
    file="$target/.icd_bench_${bs}.bin"
    log "== $name / $bs / count=$count =="
    measure_write "$target" "$name" "$bs" "$count" "$file" \
      "$OUT/logs/escritura_${name}_${bs}.err"
    measure_read "$target" "$name" "$bs" "$count" "$file" \
      "$OUT/logs/lectura_${name}_${bs}.err"
    [[ $KEEP -eq 1 ]] || rm -f "$file"
  done
done

{
  echo "Mejor bloque de LECTURA (mayor tasa):"
  awk -F';' 'NR > 1 && $4 + 0 > best[$1] { best[$1] = $4 + 0; bs[$1] = $2 }
    END { for (d in best) printf "  %-5s %-4s %10.2f MB/s\n", d, bs[d], best[d] }' \
    "$read_csv" | sort
  echo
  echo "Mejor bloque de ESCRITURA (mayor tasa):"
  awk -F';' 'NR > 1 && $4 + 0 > best[$1] { best[$1] = $4 + 0; bs[$1] = $2 }
    END { for (d in best) printf "  %-5s %-4s %10.2f MB/s\n", d, bs[d], best[d] }' \
    "$write_csv" | sort
} > "$summary"

log "Listo."
echo
cat "$summary"
echo
log "CSV: $write_csv"
log "CSV: $read_csv"
log "Resumen: $summary"
