# Contenedores LXC para P4 y P5

> Los contenedores de este documento son **LXC de Proxmox**, no Docker. Se
> crean en el **host Proxmox** con `pct` y se configuran con los scripts del
> repositorio. **pfSense no puede ser LXC**: sigue siendo una VM.

## 1. Qué se puede contenerizar y qué no

| Práctica | Se puede usar LXC | Qué queda como VM |
|---|---|---|
| P4 | `web1`, `web2` y `app` | Nada, si el profesor acepta LXC. |
| P5 | `dmz-web`, `intra-web`, `db` y `app` | **pfSense** (FreeBSD). |

La P4 oficial está pensada con VM. Los LXC son una alternativa para no montar
tres Debian desde cero. Si el enunciado exige expresamente “máquinas virtuales”,
usa `p4/vms.sh` y deja los LXC como apoyo. Si el profesor permite contenedores,
esta es la vía más rápida en Proxmox.

## 2. Antes de crear nada

Necesitas:

- Proxmox VE 8/9, con acceso root al host (por SSH o consola).
- Un bridge interno para P4, por defecto `vmbr1`.
- Un almacenamiento para los discos de los contenedores, por defecto
  `local-lvm`.
- Una plantilla LXC de **Debian 12** descargada en `local`.
- El repositorio copiado en el host Proxmox o accesible desde él.

### 2.1. Descargar la plantilla Debian 12

En el host Proxmox:

```bash
pveam update
pveam available --section system | grep debian-12
pveam download local debian-12-standard_12.7-1_amd64.tar.zst
pveam list local
```

El nombre exacto puede cambiar. Usa el que aparezca en `pveam available` y
ajusta `LXC_TEMPLATE` en `config.env`:

```bash
LXC_TEMPLATE=local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst
LXC_STORAGE=local-lvm
LXC_PASSWORD=icd2026
LXC_DNS=1.1.1.1
```

`LXC_PASSWORD` es la contraseña de root de los contenedores. Cámbiala si no
quieres la del ejemplo. No la publiques.

### 2.2. Comprobar bridges y almacenamiento

```bash
ip -br link
pvesm status
```

- `vmbr1` y `vmbr2` deben existir si vas a usar P4/P5.
- `local-lvm` debe estar disponible; si no, ajusta `LXC_STORAGE`.

## 3. P4 con LXC

### 3.1. Diseño por defecto

| LXC | VMID | IP | Bridge | Servicios |
|---|---:|---|---|---|
| `web1` | 201 | `192.168.50.11/24` | `vmbr1` | Apache |
| `web2` | 202 | `192.168.50.12/24` | `vmbr1` | Apache |
| `app` | 203 | `192.168.50.13/24` | `vmbr1` | MariaDB + Flask + nginx |

Puerta de enlace: `192.168.50.1`. DNS: `1.1.1.1` por defecto.

Cada contenedor tiene 2 GB de RAM, 2 vCPU y 32 GB de disco. Se puede cambiar
con variables de entorno o con opciones del script.

### 3.2. Crear y configurar

Desde la raíz del repositorio, en el host Proxmox:

```bash
cp config.env.example config.env
# edita config.env: LXC_TEMPLATE, LXC_STORAGE, LXC_PASSWORD, BRIDGE...
./icd.sh p4 lxc create
```

`create` hace todo:

1. Comprueba que la plantilla existe.
2. Crea los tres contenedores con `pct create`.
3. Los arranca.
4. Copia `p4/servicios.sh` dentro de cada uno.
5. Ejecuta el rol correspondiente: `web1`, `web2` o `app`.

Si quieres crear los contenedores sin instalar servicios:

```bash
./icd.sh p4 lxc create --no-services
./icd.sh p4 lxc services
```

> **Si `vmbr1` no tiene salida a internet**, `p4/servicios.sh` no podrá
> instalar Apache, MariaDB, Flask y nginx con `apt-get`. Añade una NIC
> temporal en `vmbr0` solo mientras se ejecutan los servicios:
>
> ```bash
> for id in 201 202 203; do
>   pct set "$id" --net1 name=eth1,bridge=vmbr0,ip=dhcp
> done
> ./icd.sh p4 lxc services
> for id in 201 202 203; do
>   pct set "$id" --delete net1
> done
> ```
>
> La IP de servicio sigue siendo la de `vmbr1` (`192.168.50.x`). La NIC
> temporal solo se usa para descargar paquetes y se retira antes de la
> demostración. Si el profesor no permite modificar la red, usa una plantilla
> LXC con los paquetes ya instalados o un mirror local.

### 3.3. Comprobar

```bash
pct list
./icd.sh p4 lxc status
```

Dentro de cada contenedor:

```bash
pct exec 201 -- systemctl status apache2 --no-pager
pct exec 202 -- systemctl status apache2 --no-pager
pct exec 203 -- systemctl status icdapp nginx mariadb --no-pager
```

Desde la VM Debian de trabajo o desde otro equipo de la red:

```bash
curl -s http://192.168.50.11/ | head
curl -s http://192.168.50.12/ | head
curl -s http://192.168.50.13/salud
```

El último comando debe devolver un JSON con `estado`, `servicio` y `productos`.

### 3.4. Opciones útiles

```bash
# Cambiar el rango de IDs o las IPs con variables de entorno
P4_WEB1_ID=301 P4_WEB2_ID=302 P4_APP_ID=303 \
P4_WEB1_IP=192.168.50.21 P4_WEB2_IP=192.168.50.22 P4_APP_IP=192.168.50.23 \
./icd.sh p4 lxc create

# Cambiar plantilla, storage o bridge
./icd.sh p4 lxc create \
  --template local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --storage local-lvm --bridge vmbr1 --gw 192.168.50.1
```

### 3.5. Destruir

```bash
./icd.sh p4 lxc destroy          # pide confirmación por cada contenedor
./icd.sh p4 lxc destroy --yes    # sin preguntar
```

## 4. P5 con LXC y pfSense

### 4.1. Diseño por defecto

pfSense se crea con `./icd.sh p5 todo` y sigue siendo una VM. Los servidores de
la práctica pueden ser LXC:

| LXC | VMID | IP | Bridge | Servicios |
|---|---:|---|---|---|
| `dmz-web` | 211 | `192.168.50.11/24` | `vmbr2` (DMZ) | Apache |
| `intra-web` | 212 | `192.168.100.11/24` | `vmbr1` (LAN) | Apache |
| `db` | 213 | `192.168.100.12/24` | `vmbr1` (LAN) | MariaDB |
| `app` | 214 | `192.168.100.13/24` | `vmbr1` (LAN) | Flask + nginx |

Puertas de enlace: `192.168.50.1` en la DMZ y `192.168.100.1` en la LAN. Deben
coincidir con las IPs de pfSense. Si el enunciado cambia las redes, ajusta
`P5_DMZ_GW`, `P5_LAN_GW`, las IPs y los bridges en `config.env`.

### 4.2. Orden recomendado

1. Crear la VM de pfSense:

   ```bash
   ./icd.sh p5 mac <MAC_BASE> <PC>
   # editar config.env: P5_MAC, P5_ISO, P5_WAN_BRIDGE, P5_LAN_BRIDGE...
   ./icd.sh p5 todo --mac-base <MAC_BASE> --pc <PC>
   ```

2. Instalar pfSense, asignar `WAN=vtnet0`, `LAN=vtnet1`, `DMZ=vtnet2` y
   restaurar `config.xml`.
3. Configurar LAN y DMZ en pfSense con las IPs que correspondan.
4. Crear los LXC de apoyo:

   ```bash
   ./icd.sh p5 lxc create
   ```

5. Comprobar DHCP, DNS, NAT y reglas desde un cliente de la LAN.

### 4.3. Comprobar

```bash
pct list
./icd.sh p5 lxc status

curl -s http://192.168.50.11/ | head     # web de la DMZ
curl -s http://192.168.100.11/ | head    # web de la intranet
curl -s http://192.168.100.13/salud      # Flask
```

La base de datos solo debe aceptar conexiones desde la IP de `app`
(`192.168.100.13`). El script crea el usuario `'icd'@'192.168.100.13'`, no
`'icd'@'%'`.

### 4.4. Reglas de pfSense que hay que revisar

Los LXC no configuran el firewall. En pfSense comprueba:

- **WAN:** DHCP y MAC reservada.
- **LAN:** `192.168.100.1/24`, DHCP y DNS para los clientes.
- **DMZ:** `192.168.50.1/24`.
- **Reglas:** acceso desde LAN a la web de la DMZ y a la app; salida a internet
  si hace falta instalar paquetes.
- **NAT:** salida de LAN/DMZ por la WAN, si el enunciado lo pide.

## 5. Llevar los contenedores “ya hechos” en el USB

Los scripts del repositorio crean los contenedores en pocos minutos, pero si
quieres llevarlos preparados desde casa puedes guardar una copia de seguridad
de Proxmox.

### 5.1. Exportar

En el host Proxmox, con los contenedores parados o en modo snapshot:

```bash
vzdump 201 202 203 --mode stop --storage local --compress zstd
vzdump 211 212 213 214 --mode stop --storage local --compress zstd
```

Los ficheros quedan en `/var/lib/vz/dump/`. Copia los `.tar.zst` al USB.

### 5.2. Restaurar en el examen

```bash
pct restore 201 /ruta/vzdump-lxc-201-....tar.zst --storage local-lvm
pct start 201
```

Repite con cada VMID. Revisa después:

- que las IPs y bridges siguen siendo los del enunciado;
- que la plantilla y el storage existen en el host del examen;
- que no has restaurado encima de un contenedor de otro compañero.

### 5.3. pfSense

pfSense no se puede convertir en LXC. Para llevarlo preparado:

```bash
vzdump 250 --mode stop --storage local --compress zstd
```

Guarda también el `config.xml` exportado desde pfSense. El repositorio **no**
incluye `p5/config.xml`; si lo copias al USB, hazlo en una carpeta local y no lo
subas a GitHub.

## 6. Diferencias con las VM

| Aspecto | VM (`qm`) | LXC (`pct`) |
|---|---|---|
| Kernel | Propio, dentro de la VM | Comparte el kernel del host |
| Arranque | BIOS/UEFI y disco | Plantilla y sistema de ficheros |
| Servicios systemd | Sí | Sí, con `nesting=1` |
| Red | NIC virtual | `net0` con IP estática |
| pfSense | Sí | **No** |
| Velocidad de creación | Instalar Debian o clonar | Minutos con plantilla |
| Aislamiento | Mayor | Menor, suficiente para la práctica |

## 7. Problemas típicos

| Síntoma | Causa | Solución |
|---|---|---|
| `pct: command not found` | Estás en la VM Debian | Ejecuta en el host Proxmox. |
| `No encuentro la plantilla` | No está descargada en `local` | `pveam download local ...` |
| `storage 'local-lvm' does not exist` | Storage incorrecto | `pvesm status` y ajusta `LXC_STORAGE`. |
| El contenedor arranca pero no tiene red | Bridge o IP mal | `pct config <id>`, `ip -br a` dentro. |
| `systemctl` falla | Falta `nesting=1` | El script lo pone; revisa `pct config`. |
| MariaDB no arranca | Contenedor sin `keyctl=1` | Revisa las features del contenedor. |
| El puerto 80 no responde | Apache/nginx no arrancó | `pct exec <id> -- systemctl status ...`. |
| pfSense no enruta | LAN/DMZ mal o reglas sin aplicar | Revisa interfaces, reglas y NAT. |

## 8. Lista de comprobación

- [ ] La plantilla Debian 12 está en `pveam list local`.
- [ ] `LXC_STORAGE` y los bridges existen.
- [ ] Los VMID no chocan con otras VM/contenedores.
- [ ] P4: `web1`, `web2` y `app` responden.
- [ ] P5: pfSense es una VM, no un LXC.
- [ ] P5: LAN/DMZ y IPs coinciden con pfSense.
- [ ] La base de datos no acepta conexiones desde cualquier IP.
- [ ] No se han subido contraseñas ni `config.xml` al repositorio.
