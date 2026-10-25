# Guía de ejecución — las cinco prácticas

Esta guía explica **dónde** se ejecuta cada script y **en qué orden**, desde que
descargas el repositorio hasta que validas la práctica. No sustituye al
enunciado: si el profesor cambia una IP, un ID o una red, se cambia en
`config.env` o en el fichero que corresponda.

> Los scripts son de Linux. En Windows solo se descarga y se edita; para
> ejecutar P2, P3, P4 y P5 hace falta el host Proxmox o una VM Debian. La P1 se
> puede generar con Git Bash, pero el montaje es en Packet Tracer.

## 0. Dónde se ejecuta cada cosa

| Sitio | Qué se hace allí |
|---|---|
| Tu PC con Windows | Descargar el repo, editar `config.env`, generar la P1 y llevar el repo al laboratorio. |
| Host Proxmox (root) | Crear/arrancar las VM de P4 y P5. |
| VM Debian (root) | P2 (RAID), P3 (fio) y los servicios de P4. |
| Packet Tracer | P1: topología, cableado, DHCP/DNS y pegar la configuración. |

No ejecutes `./icd.sh p2` en el host Proxmox: la matriz se crea dentro de una VM
Debian, con discos que puedas borrar. Tampoco ejecutes `p4/servicios.sh` en el
host: va dentro de cada VM.

En Windows, abre **Git Bash** en la carpeta del repo (clic derecho → *Git Bash
Here*) y ejecuta `bash icd.sh ...`. Eso sirve para la P1. Para P2, P3, P4 y P5
entra en la VM Debian o en el host Proxmox; Windows no tiene `mdadm`, `qm` ni
`apt`.

## 1. Descargar y preparar el repositorio

En el PC, con la cuenta de GitHub `Carboq`:

- **GitHub Desktop**: `File → Clone repository → URL` y pega la URL del repo.
- **Web**: abre el repo, botón verde **Code → Download ZIP** y descomprime.
- **Terminal**: `git clone <URL> icd-examen`.

El repo es privado: sin iniciar sesión verás un 404. En el PC del examen no hay
internet, así que descárgalo antes y llévalo en un USB o cópialo al host
Proxmox. El detalle de la descarga y de la MAC está en el documento local
`ICD/GUIA_MAC_Y_DESCARGA.md` (ese no se sube al repositorio).

Dentro de la carpeta:

```bash
cp config.env.example config.env
cp p1/valores.env.example p1/valores.env
cp p4/vms.conf.example p4/vms.conf
```

Edita `config.env` con los valores del laboratorio: discos de P2, `STORAGE`,
`BRIDGE`, `ISO`, bridges y datos de P5. Los ficheros `config.env`,
`p4/vms.conf`, `p1/valores.env`, `p1/out/` y `p5/config.xml` no se suben.

Si al descomprimir el ZIP los scripts pierden el permiso de ejecución:

```bash
chmod +x icd.sh p1/*.sh p2/*.sh p3/*.sh p4/*.sh p5/*.sh
# o ejecuta siempre con: bash icd.sh ...
```

Comprueba que responde:

```bash
./icd.sh --help
```

---

## 2. P1 — Packet Tracer

**Dónde:** PC con Git Bash o VM Linux para generar los textos; Packet Tracer para
el montaje.

```bash
./icd.sh p1 todo
```

La primera vez crea `p1/valores.env` y termina. Edítalo con las redes, enlaces,
servidor y dominio del enunciado, y vuelve a ejecutar:

```bash
./icd.sh p1 todo
```

Genera `p1/out/R1.txt` … `R4.txt`. Si avisa de marcadores `{{ }}` pendientes, es
que falta un valor en `valores.env`.

Después, en Packet Tracer:

1. Monta 4 routers 2911, un switch 2960 por red, los PCs y el servidor.
2. Cablea con cobre recto; los enlaces entre routers son GigabitEthernet.
3. Abre la CLI de R1–R4 y pega el fichero correspondiente. Termina con `end` y
   `write memory`.
4. En `Server0 → Services`, crea un pool DHCP por red y los registros DNS.
5. Verifica: `ping` entre redes, `ipconfig /renew`, `nslookup` y `show ip route`.

**Tiempo:** 30–45 min. **No automatizable:** la topología y la GUI de Packet
Tracer. Lo que ahorra el script es escribir y revisar la configuración.

---

## 3. P2 — RAID 5

**Dónde:** VM Debian, como root, con 4 discos libres (o los que pida el
enunciado).

Primero mira qué discos hay. **No adivines las letras:**

```bash
./icd.sh p2 detect
```

Crea la matriz y comprueba el estado:

```bash
./icd.sh p2 create --disks sdb,sdc,sdd,sde
./icd.sh p2 status
```

Si el enunciado pide además simular un fallo y reponer el disco, tienes dos
opciones.

**Paso a paso** (recomendado para aprender y para el examen):

```bash
./icd.sh p2 fail sdb
./icd.sh p2 add sdb
./icd.sh p2 status
```

**De una vez** (crea, falla y repone):

```bash
./icd.sh p2 todo sdb,sdc,sdd,sde
```

El script muestra modelo y número de serie antes de crear, y pide confirmación.
`--yes` evita la pregunta; úsalo solo si estás seguro. `--assume-clean` omite la
sincronización inicial y va más rápido en el laboratorio. `--force` borra firmas
existentes: es destructivo.

Comprobaciones:

```bash
cat /proc/mdstat
mdadm --detail /dev/md0
df -h /mnt/raid5
```

**Tiempo:** 12–15 min. **Manual:** elegir los discos correctos y decidir si el
enunciado pide 3 activos + 1 repuesto o 4 activos.

Al terminar, si quieres dejar los discos limpios:

```bash
./icd.sh p2 cleanup
```

---

## 4. P3 — Prestaciones

**Dónde:** la misma VM Debian, con la matriz de P2 montada en `/mnt/raid5`.

```bash
./icd.sh p3 todo
```

El script instala `fio` si falta, comprueba que el destino es un punto de montaje
y ejecuta lecturas/escrituras secuenciales y aleatorias con varios tamaños de
bloque. Los resultados quedan en:

```
p3/resultados/resultados.csv
p3/resultados/raw/*.txt
```

Para ver solo la tabla:

```bash
./icd.sh p3 report
```

Si no hay internet y `fio` ya está instalado en la plantilla:

```bash
./icd.sh p3 todo --no-install
```

Opciones útiles si el enunciado cambia las pruebas:

```bash
./icd.sh p3 todo --target /mnt/raid5 --sizes "4k 1M" --runtime 10
```

**Tiempo:** 25–35 min. **Manual:** interpretar los resultados y pasarlos a la
memoria.

---

## 5. P4 — VM en Proxmox y servicios

**Dónde:** el host Proxmox para crear las VM; cada VM Debian para los servicios.

### 5.1 Preparar `p4/vms.conf`

Una VM por línea:

```
nombre|vmid|RAM_MB|vCPU|disco_GB|bridge|mac|iso
```

Ejemplo del simulacro:

```
web1|201|2048|2|32|vmbr1||local:iso/debian-12-netinst.iso
web2|202|2048|2|32|vmbr1||
app|203|2048|2|32|vmbr1||
```

Cambia el `volid` de la ISO por el que exista en el laboratorio
(`pvesm list local | grep -i iso`). Si no hay ISO, deja el campo vacío y usa una
plantilla.

### 5.2 Crear y arrancar

```bash
./icd.sh p4 todo
```

El script crea las VM, arranca las que ya existen y muestra una tabla con la IP
sugerida. Si quieres crear pero no arrancar:

```bash
./icd.sh p4 todo --no-start
```

### 5.3 Instalar Debian o clonar

- **Con plantilla:** clona la plantilla tres veces y asigna MAC e IP.
- **Sin plantilla:** instala Debian en `web1`, apaga, quita la ISO y clona
  `web1` para `web2` y `app`. En cada clon cambia hostname, `/etc/hosts`,
  `machine-id` y claves SSH.

La red de cada VM se configura en `/etc/network/interfaces` o en el fichero de
`interfaces.d` de la plantilla. La guía detallada, con los comandos de clonado y
las IPs del simulacro, está en [`docs/simulacros/P4.md`](simulacros/P4.md).

### 5.4 Copiar el repo y ejecutar los servicios

Desde el host, si las VM tienen SSH:

```bash
scp -r . root@192.168.50.11:/root/Examen
scp -r . root@192.168.50.12:/root/Examen
scp -r . root@192.168.50.13:/root/Examen
```

O entra por la consola de Proxmox y copia el repo por USB. Después, **dentro de
cada VM**:

```bash
cd /root/Examen
sudo ./p4/servicios.sh web1     # en web1
sudo ./p4/servicios.sh web2     # en web2
sudo ./p4/servicios.sh app      # en app
```

El script de `app` instala y configura MariaDB, Flask, systemd y nginx. El de
`web1`/`web2` instala Apache y escribe la página con la fecha. Es idempotente:
si algo falla, corriges y lo vuelves a ejecutar.

Si la plantilla ya trae los paquetes y no hay internet:

```bash
sudo ./p4/servicios.sh app --no-apt
```

Opciones: `--ip`, `--db-host`, `--db-pass`, `--student`.

### 5.5 Validar

Desde `web1`:

```bash
curl -s http://192.168.50.12 | head
curl -s http://192.168.50.13 | head
curl -s http://192.168.50.13/salud
```

Debe salir un JSON con `estado`, `servicio` y `productos`. Desde `web2`, la base
de datos debe rechazar la conexión:

```bash
mariadb -h 192.168.50.13 -u icd -picd2026 -e 'SELECT 1'
```

**Tiempo:** 20–30 min con plantilla; 40–50 min si instalas Debian desde cero.
**Manual:** instalar Debian y configurar la red. **Automático:** creación de VM
y servicios.

---

## 6. P5 — pfSense

**Dónde:** host Proxmox.

### 6.1 Calcular la MAC

Con la MAC de la primera VM del laboratorio y tu número de PC:

```bash
./icd.sh p5 mac BC:24:11:0A:1B:2C 7
# BC:24:11:0A:11:07
```

La regla: conserva los cuatro primeros octetos y sustituye los dos últimos por
`11:<PC en hexadecimal>`. Si el laboratorio te da la MAC ya calculada, úsala
tal cual.

### 6.2 Preparar `config.env`

```bash
P5_VMID=250
P5_MAC=BC:24:11:0A:11:07
P5_ISO=local:iso/pfSense-CE-2.7.2-RELEASE-amd64.iso
P5_WAN_BRIDGE=vmbr0
P5_LAN_BRIDGE=vmbr1
P5_DMZ_BRIDGE=vmbr2
```

Comprueba que los bridges existen (`ip -br link`) y que el `volid` de la ISO es
el correcto (`pvesm list local | grep -i pfsense`).

### 6.3 Crear y arrancar

```bash
./icd.sh p5 todo --mac-base BC:24:11:0A:1B:2C --pc 7
```

o, si ya tienes la MAC:

```bash
./icd.sh p5 todo --mac BC:24:11:0A:11:07
```

El script crea la VM con tres NIC, fija la MAC de la WAN y la arranca.

### 6.4 Instalar y restaurar

1. En la consola: aceptar, instalar pfSense y reiniciar.
2. Quitar la ISO y arrancar del disco:

   ```bash
   qm set 250 --delete ide2 --boot order=scsi0
   ```

3. Asignar WAN = `vtnet0`, LAN = `vtnet1`, DMZ = `vtnet2`.
4. `Diagnostics → Backup & Restore → Restore` y subir `p5/config.xml`.
5. Si el enunciado cambia las redes, ajusta LAN/DMZ, DHCP, reglas y NAT después
   de restaurar.
6. Si la WAN se queda sin IP: `Interfaces → WAN → Release/Renew`.

### 6.5 Validar

```bash
ping -c 3 www.upv.es
pfctl -sn
pfctl -sr
```

Y desde un cliente de la LAN: DHCP, DNS y acceso a los servicios publicados.

**Tiempo:** 25–30 min. **Manual:** instalación de pfSense y restauración del
`config.xml`. **Automático:** VM, NICs y MAC.

---

## 7. Orden en los 90 minutos

| Fase | Tiempo |
|---|---|
| Leer el enunciado y anotar los cambios | 5 min |
| P1 Packet Tracer | 35–45 min |
| P2 RAID 5 | 12–15 min |
| P3 Prestaciones | 25–35 min |
| P4 VM + servicios | 20–30 min |
| P5 pfSense | 25–30 min |
| Validar y capturar evidencias | 5–10 min |

No empieces dos prácticas largas a la vez. Si el enunciado pide P2 y P3, van
juntas: P2 deja la matriz montada y P3 mide sobre ella. Si pide P4 y P5, crea
primero las VM y mientras instalan, prepara la otra.

Consejo práctico: a los 60 minutos deja de montar y empieza a validar y a
capturar. Es mejor una práctica terminada y documentada que dos a medias.

---

## 8. Problemas típicos

| Síntoma | Causa | Solución |
|---|---|---|
| `qm: command not found` | Estás en la VM, no en el host | Ejecuta P4/P5 en el host Proxmox. |
| `mdadm: no devices` | Discos mal escritos o no existen | `./icd.sh p2 detect` y revisa la lista. |
| `p3` mide el disco del sistema | `/mnt/raid5` no está montado | Monta la matriz o ajusta `--target`. |
| `apt-get` no descarga | No hay internet en el laboratorio | Usa plantilla con paquetes o `--no-apt`. |
| Dos VM con la misma IP | Clon sin cambiar la red | Cambia la IP y reinicia `networking`. |
| `502 Bad Gateway` | `icdapp` no arranca | `systemctl status icdapp`, `journalctl -u icdapp`. |
| La BD acepta conexiones de `web2` | Usuario `'icd'@'%'` o sin restricción | Crea `'icd'@'192.168.50.13'` y borra el comodín. |
| pfSense sin IP en WAN | MAC incorrecta o bridge equivocado | Revisa `net0`, renueva la WAN. |
| El ZIP no trae `config.env` | Está en `.gitignore` | Cópialo del `.example`. |

---

## 9. Resumen de comandos

```bash
# P1
./icd.sh p1 todo

# P2
./icd.sh p2 detect
./icd.sh p2 create --disks sdb,sdc,sdd,sde
./icd.sh p2 todo sdb,sdc,sdd,sde --assume-clean
./icd.sh p2 fail sdb
./icd.sh p2 add sdb
./icd.sh p2 status
./icd.sh p2 cleanup

# P3
./icd.sh p3 todo
./icd.sh p3 report

# P4 (host)
./icd.sh p4 todo
# P4 (dentro de cada VM)
sudo ./p4/servicios.sh web1
sudo ./p4/servicios.sh web2
sudo ./p4/servicios.sh app

# P5 (host)
./icd.sh p5 mac BC:24:11:0A:1B:2C 7
./icd.sh p5 todo --mac-base BC:24:11:0A:1B:2C --pc 7
```

---

## 10. Lo que sigue siendo manual

- **P1:** la topología, el cableado y el DHCP/DNS de Packet Tracer.
- **P2:** elegir los discos correctos y decidir la distribución activos/repuesto.
- **P3:** interpretar los resultados.
- **P4:** instalar Debian o clonar la plantilla y configurar la red.
- **P5:** instalar pfSense y restaurar el `config.xml`.
- **Todos:** adaptar los valores al enunciado del examen. Los scripts no adivinan
  las IPs, los discos ni las MAC.
