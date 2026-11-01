#!/usr/bin/env bash
# Práctica 5: configura los servicios de apoyo DENTRO de un LXC Debian 12.
#
#   ./servicios.sh dmz-web --ip 192.168.50.11
#   ./servicios.sh intra-web --ip 192.168.100.11
#   ./servicios.sh db --ip 192.168.100.12 --app-ip 192.168.100.13
#   ./servicios.sh app --ip 192.168.100.13 --db-host 192.168.100.12
#
# pfSense NO se configura aquí: es una VM FreeBSD aparte.
# Se ejecuta como root dentro de cada contenedor, no en el host Proxmox.

set -euo pipefail

ROLE=""
IP=""
DB_HOST=""
APP_IP=""
DB_PASS="${ICD_DB_PASS:-icd2026}"
STUDENT="${ICD_STUDENT:-Carles Luis Boquera}"
NO_APT=0
APT_UPDATED=0

log()  { printf '[icd] %s\n' "$*"; }
warn() { printf '[icd] AVISO: %s\n' "$*" >&2; }
die()  { printf '[icd] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Uso: servicios.sh <dmz-web|intra-web|db|app> [opciones]

Roles:
  dmz-web     Apache con la página de la DMZ.
  intra-web   Apache con la página de la intranet.
  db          MariaDB con la base de datos 'icd'.
  app         Flask + nginx, conecta con la base de datos remota.

Opciones:
  --ip DIRECCION      IP de este contenedor. Por defecto:
                        dmz-web   -> 192.168.50.11
                        intra-web -> 192.168.100.11
                        db        -> 192.168.100.12
                        app       -> 192.168.100.13
  --db-host DIRECCION IP de MariaDB para el rol app (por defecto 192.168.100.12).
  --app-ip DIRECCION  IP de la app que puede conectarse a MariaDB en el rol db
                      (por defecto 192.168.100.13).
  --db-pass CLAVE     Contraseña del usuario 'icd' (por defecto icd2026).
  --student NOMBRE    Nombre que aparece en las páginas.
  --no-apt            No instalar paquetes (plantilla que ya los trae).
  -h, --help          Esta ayuda.

Ejemplos:
  sudo ./servicios.sh dmz-web --ip 192.168.50.11
  sudo ./servicios.sh db --ip 192.168.100.12 --app-ip 192.168.100.13
  sudo ./servicios.sh app --ip 192.168.100.13 --db-host 192.168.100.12
EOF
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Ejecuta como root (sudo)."
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Falta el programa '$1'."
}

valid_ip() {
  local ip=$1 IFS=. a b c d
  [[ $ip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  read -r a b c d <<< "$ip"
  (( 10#$a <= 255 && 10#$b <= 255 && 10#$c <= 255 && 10#$d <= 255 ))
}

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
      -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

ensure_packages() {
  local p missing=()
  for p in "$@"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log "Paquetes ya instalados: $*"
    return 0
  fi

  if [[ $NO_APT -eq 1 ]]; then
    die "Faltan paquetes (${missing[*]}) y se pidió --no-apt."
  fi

  log "Instalando: ${missing[*]}"
  export DEBIAN_FRONTEND=noninteractive
  if [[ $APT_UPDATED -eq 0 ]]; then
    apt-get -o DPkg::Lock::Timeout=60 update -qq \
      || warn "apt-get update ha fallado; intento instalar igualmente."
    APT_UPDATED=1
  fi
  apt-get -o DPkg::Lock::Timeout=60 install -y --no-install-recommends "${missing[@]}" \
    || die "No se pudieron instalar los paquetes. ¿Hay red y repositorios?"
}

check_env() {
  require_root
  [[ -f /etc/debian_version ]] || die "Este script está pensado para Debian 12."
  [[ ! -d /etc/pve ]] \
    || die "Estás en el host Proxmox. Ejecuta este script DENTRO del contenedor."
  need systemctl
  need dpkg
  if ! command -v ip >/dev/null 2>&1; then
    ensure_packages iproute2
  fi
  need ip
}

check_ip() {
  if ip -4 -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | grep -qx "$IP"; then
    log "La IP $IP está configurada en este contenedor."
  else
    warn "La IP $IP no aparece en 'ip a'. Revisa la red del contenedor."
  fi
}

write_web() {
  local title="ICD - $ROLE" extra="" student_html
  case "$ROLE" in
    dmz-web)   extra='  <p>Servidor de la DMZ</p>' ;;
    intra-web) extra='  <p>Servidor de la intranet</p>' ;;
  esac
  student_html=$(printf '%s' "$STUDENT" | html_escape)

  cat > /var/www/html/index.html <<EOF
<!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>$title</title></head>
<body>
  <h1>Infraestructura Informática para Centros de Datos</h1>
  <p>Servidor: $ROLE</p>
  <p>Estudiante: $student_html</p>
  <p>IP: $IP</p>
  <p>Fecha: $(date +%d/%m/%Y)</p>
$extra
</body></html>
EOF

  systemctl enable apache2 >/dev/null 2>&1 || true
  systemctl restart apache2
  curl -fsS --max-time 5 http://127.0.0.1/ >/dev/null \
    || die "Apache no responde en 127.0.0.1:80."
  log "Apache responde. Página en http://$IP/"
}

setup_db() {
  ensure_packages mariadb-server

  systemctl enable mariadb >/dev/null 2>&1 || true
  systemctl restart mariadb

  local confs=() f
  while IFS= read -r f; do
    [[ -f $f ]] || continue
    if grep -qE '^[[:space:]]*bind-address[[:space:]]*=' "$f"; then
      confs+=("$f")
    fi
  done < <(find /etc/mysql -type f -name '*.cnf' 2>/dev/null)

  if [[ ${#confs[@]} -eq 0 ]]; then
    f=/etc/mysql/mariadb.conf.d/50-server.cnf
    mkdir -p "$(dirname "$f")"
    if [[ -f $f ]] && grep -q '^\[mysqld\]' "$f"; then
      printf '\nbind-address = 0.0.0.0\n' >> "$f"
    else
      printf '\n[mysqld]\nbind-address = 0.0.0.0\n' >> "$f"
    fi
  else
    for f in "${confs[@]}"; do
      sed -i -E 's/^[[:space:]]*bind-address[[:space:]]*=.*/bind-address = 0.0.0.0/' "$f"
    done
  fi
  systemctl restart mariadb

  local client
  client=$(command -v mariadb || command -v mysql || true)
  [[ -n $client ]] || die "No encuentro el cliente de MariaDB."

  local i
  for i in {1..20}; do
    "$client" -e 'SELECT 1' >/dev/null 2>&1 && break
    sleep 1
  done
  "$client" -e 'SELECT 1' >/dev/null 2>&1 \
    || die "MariaDB no responde después de arrancarlo."

  local sql
  sql=$(mktemp)
  chmod 600 "$sql"
  cat > "$sql" <<SQL
CREATE DATABASE IF NOT EXISTS icd
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'icd'@'$APP_IP' IDENTIFIED BY '$DB_PASS';
ALTER USER 'icd'@'$APP_IP' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON icd.* TO 'icd'@'$APP_IP';
CREATE USER IF NOT EXISTS 'icd'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER 'icd'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON icd.* TO 'icd'@'localhost';
FLUSH PRIVILEGES;
USE icd;
CREATE TABLE IF NOT EXISTS productos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL,
  precio DECIMAL(8,2) NOT NULL,
  stock INT NOT NULL
);
SQL

  if ! "$client" < "$sql"; then
    rm -f "$sql"
    die "Error al crear la base de datos o el usuario."
  fi
  rm -f "$sql"

  local count
  count=$("$client" -N -B -e 'SELECT COUNT(*) FROM icd.productos' 2>/dev/null || echo 0)
  if [[ ${count:-0} -eq 0 ]]; then
    "$client" icd <<'SQL'
INSERT INTO productos (nombre, precio, stock) VALUES
('Teclado', 25.50, 10),
('Ratón', 15.00, 20),
('Monitor', 120.00, 5),
('Disco SSD', 80.00, 8),
('Memoria RAM', 45.00, 12);
SQL
  fi

  log "Base de datos 'icd' y usuario 'icd'@'$APP_IP' listos."
}

write_app() {
  ensure_packages python3-flask python3-pymysql gunicorn curl
  mkdir -p /opt/icdapp

  cat > /opt/icdapp/app.py <<'PY'
import os

from flask import Flask, jsonify, render_template_string
import pymysql

app = Flask(__name__)

DB = dict(
    host=os.environ.get("ICD_DB_HOST", "127.0.0.1"),
    user=os.environ.get("ICD_DB_USER", "icd"),
    password=os.environ.get("ICD_DB_PASS", ""),
    database=os.environ.get("ICD_DB_NAME", "icd"),
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
)
ESTUDIANTE = os.environ.get("ICD_STUDENT", "")
SERVIDOR = os.environ.get("ICD_SERVER", "app")


def filas():
    c = pymysql.connect(**DB)
    try:
        with c.cursor() as q:
            q.execute("SELECT id, nombre, precio, stock FROM productos ORDER BY id")
            return q.fetchall()
    finally:
        c.close()


PLANTILLA = """<!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>ICD - app</title></head>
<body>
  <h1>Infraestructura Informática para Centros de Datos</h1>
  <p>Estudiante: {{ estudiante }}</p>
  <p>Servidor: {{ servidor }}</p>
  <table border="1">
    <tr><th>ID</th><th>Nombre</th><th>Precio</th><th>Stock</th></tr>
    {% for f in filas %}
    <tr><td>{{ f.id }}</td><td>{{ f.nombre }}</td><td>{{ f.precio }}</td><td>{{ f.stock }}</td></tr>
    {% endfor %}
  </table>
</body></html>"""


@app.route("/")
def index():
    return render_template_string(
        PLANTILLA, filas=filas(), estudiante=ESTUDIANTE, servidor=SERVIDOR
    )


@app.route("/salud")
def salud():
    try:
        return jsonify(estado="ok", servicio="icdapp", productos=len(filas()))
    except Exception as e:
        return jsonify(estado="error", servicio="icdapp", detalle=str(e)), 500


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
PY

  cat > /etc/icdapp.env <<EOF
ICD_DB_HOST=$DB_HOST
ICD_DB_USER=icd
ICD_DB_PASS=$DB_PASS
ICD_DB_NAME=icd
ICD_STUDENT="$STUDENT"
ICD_SERVER="$ROLE ($IP)"
EOF
  chmod 600 /etc/icdapp.env

  cat > /etc/systemd/system/icdapp.service <<'EOF'
[Unit]
Description=Aplicacion Flask ICD
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/icdapp
EnvironmentFile=/etc/icdapp.env
ExecStart=/usr/bin/gunicorn --workers 2 --bind 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable icdapp >/dev/null 2>&1 || true
  if ! systemctl restart icdapp; then
    systemctl status icdapp --no-pager || true
    journalctl -u icdapp -n 30 --no-pager || true
    die "No se pudo arrancar icdapp."
  fi

  local i
  for i in {1..15}; do
    curl -fsS --max-time 2 http://127.0.0.1:5000/salud >/dev/null 2>&1 && break
    sleep 1
  done
  curl -fsS --max-time 3 http://127.0.0.1:5000/salud >/dev/null \
    || {
      systemctl status icdapp --no-pager || true
      journalctl -u icdapp -n 30 --no-pager || true
      die "La aplicación no responde en /salud (127.0.0.1:5000)."
    }

  log "Aplicación Flask respondiendo en 127.0.0.1:5000."
}

setup_nginx() {
  if dpkg -s apache2 >/dev/null 2>&1; then
    systemctl disable apache2 >/dev/null 2>&1 || true
    if systemctl is-active --quiet apache2 2>/dev/null; then
      warn "Apache está activo en app; lo paro para que nginx use el puerto 80."
      systemctl stop apache2 || true
    fi
  fi

  ensure_packages nginx

  cat > /etc/nginx/sites-available/icdapp <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/icdapp /etc/nginx/sites-enabled/icdapp
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl enable nginx >/dev/null 2>&1 || true
  systemctl restart nginx

  local i
  for i in {1..10}; do
    curl -fsS --max-time 2 http://127.0.0.1/salud >/dev/null 2>&1 && break
    sleep 1
  done
  curl -fsS --max-time 5 http://127.0.0.1/salud >/dev/null \
    || die "nginx no responde en 127.0.0.1:80/salud."
  log "nginx responde. Prueba: curl http://$IP/salud"
}

# --- argumentos ------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    dmz-web|intra-web|db|app) ROLE=$1; shift ;;
    --ip) IP=${2:?}; shift 2 ;;
    --ip=*) IP=${1#*=}; shift ;;
    --db-host) DB_HOST=${2:?}; shift 2 ;;
    --db-host=*) DB_HOST=${1#*=}; shift ;;
    --app-ip) APP_IP=${2:?}; shift 2 ;;
    --app-ip=*) APP_IP=${1#*=}; shift ;;
    --db-pass) DB_PASS=${2:?}; shift 2 ;;
    --db-pass=*) DB_PASS=${1#*=}; shift ;;
    --student) STUDENT=${2:?}; shift 2 ;;
    --student=*) STUDENT=${1#*=}; shift ;;
    --no-apt) NO_APT=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    *) die "Opción desconocida: $1 (usa --help)" ;;
  esac
done

[[ -n $ROLE ]] || { usage; die "Indica el rol: dmz-web, intra-web, db o app."; }

case "$ROLE" in
  dmz-web)   IP=${IP:-192.168.50.11} ;;
  intra-web) IP=${IP:-192.168.100.11} ;;
  db)        IP=${IP:-192.168.100.12} ;;
  app)       IP=${IP:-192.168.100.13} ;;
esac
DB_HOST=${DB_HOST:-192.168.100.12}
APP_IP=${APP_IP:-192.168.100.13}

valid_ip "$IP" || die "IP no válida: $IP"
valid_ip "$DB_HOST" || die "IP de la base de datos no válida: $DB_HOST"
valid_ip "$APP_IP" || die "IP de la app no válida: $APP_IP"
[[ $DB_PASS =~ ^[A-Za-z0-9_.-]+$ ]] \
  || die "La contraseña solo puede tener letras, números, punto, guion y guion bajo."
[[ $STUDENT != *$'\n'* && $STUDENT != *'"'* && $STUDENT != *\\* ]] \
  || die "El nombre no puede contener saltos de línea, comillas dobles ni barras."

case "$ROLE" in
  dmz-web|intra-web)
    check_env
    check_ip
    ensure_packages apache2 curl
    write_web
    ;;
  db)
    check_env
    check_ip
    setup_db
    ;;
  app)
    check_env
    check_ip
    ensure_packages curl
    write_app
    setup_nginx
    ;;
esac

printf '\n'
log "Rol $ROLE configurado."
case "$ROLE" in
  dmz-web|intra-web)
    printf '  Página:  http://%s/\n' "$IP"
    ;;
  db)
    printf '  Base de datos: %s\n' "$IP"
    printf '  Usuario permitido: icd@%s\n' "$APP_IP"
    ;;
  app)
    printf '  Página:  http://%s/\n' "$IP"
    printf '  Salud:   http://%s/salud\n' "$IP"
    printf '  Servicio: systemctl status icdapp nginx\n'
    ;;
esac
