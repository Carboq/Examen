# Entorno real del examen: VM Debian sobre Proxmox y discos reales

> Este documento resume **dónde se ejecuta cada cosa** y cómo preparar los
> discos de P2/P3. No sustituye al enunciado: si el profesor cambia una IP, un
> bridge, un VMID o el número de discos, manda el enunciado.

## 1. Esquema del laboratorio

```text
PC con Windows
  └── Packet Tracer (P1)

Host Proxmox VE
  ├── VM Debian 12 de trabajo
  │     ├── P2: RAID 5 sobre discos reales
  │     ├── P3: fio sobre la matriz de P2
  │     └── edición del repositorio y OpenCode
  ├── Contenedores LXC de P4 (web1, web2, app)
  ├── VM pfSense de P5
  └── Contenedores LXC de apoyo para P5 (opcional)
```

La práctica **no se hace de forma nativa en Windows**. Los scripts de P2, P3,
P4 y P5 son de Linux. Windows solo se usa para Packet Tracer, editar ficheros y
preparar el USB.

| Sitio | Qué se ejecuta allí |
|---|---|
| Windows + Packet Tracer | P1: topología, cableado, DHCP/DNS y pegar configuraciones. |
| Host Proxmox (root) | `qm`, `pct`, `pveam`, creación de VM y contenedores. |
| VM Debian 12 de trabajo | P2, P3, edición del repo, OpenCode, SSH a otras máquinas. |
| Contenedores LXC de P4 | Apache, MariaDB, Flask y nginx. |
| VM pfSense | WAN/LAN/DMZ, DHCP, DNS, NAT y reglas. |

No ejecutes `./icd.sh p2` en el host Proxmox: la matriz se crea dentro de la VM
Debian. Tampoco ejecutes `p4/servicios.sh` en el host: va dentro de cada VM o
contenedor.

## 2. Discos reales para P2 y P3

En el examen, los discos de P2/P3 son **discos reales** conectados a la VM
Debian desde Proxmox. No son discos virtuales `qcow2`/`raw` del almacenamiento
`local-lvm`.

### 2.1. Identificar los discos en el host

En el host Proxmox, como root:

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,SERIAL,FSTYPE,MOUNTPOINT
ls -l /dev/disk/by-id/
```

Apunta el modelo, el número de serie y el `by-id` de cada disco. No uses letras
como `sdb` para identificar el disco físico: pueden cambiar al reiniciar.

### 2.2. Conectar un disco real a la VM

Con la VM apagada:

```bash
# Ejemplo: VM 300, disco real identificado por su by-id
qm set 300 --scsihw virtio-scsi-pci \
  --scsi1 /dev/disk/by-id/ata-WDC_WD5000AZLX-00K4KA0_WD-WCC6Y0ABCDEF

# Segundo disco
qm set 300 --scsi2 /dev/disk/by-id/ata-WDC_WD5000AZLX-00K4KA0_WD-WCC6Y0GHIJKL

qm config 300 | grep -E '^(scsi|scsihw)'
```

Notas:

- Usa el `by-id` completo, no `/dev/sdb`, para que el disco sea siempre el
  mismo.
- El disco queda reservado para la VM. No lo montes en el host ni lo uses en
  otra VM al mismo tiempo.
- **Nunca conectes el disco raíz del host Proxmox.** Comprueba dos veces el
  modelo y el tamaño.
- Si el profesor entrega los discos ya conectados, sáltate este paso y pasa al
  apartado 2.3.
- Si el host no te deja usar `qm`, pide que lo haga el administrador o usa la
  GUI. La GUI no siempre muestra discos físicos; el comando `qm set` es la
  forma habitual.

### 2.3. Comprobar los discos dentro de la VM Debian

Dentro de la VM:

```bash
lsblk -dn -o NAME,SIZE,TYPE,MODEL,SERIAL
ls -l /dev/disk/by-id/
findmnt -n -o SOURCE /
```

Los discos pasados por SCSI suelen aparecer como `/dev/sdb`, `/dev/sdc`, etc.
Si se pasan como VirtIO, pueden aparecer como `/dev/vdb`, `/dev/vdc`. Los
scripts aceptan los dos formatos: `sdb` y `/dev/sdb`, `vdb` y `/dev/vdb`.

El disco donde está instalado Debian es el **disco del sistema** y no se toca.
Puedes verlo con:

```bash
lsblk -s -nlo NAME,TYPE "$(findmnt -n -o SOURCE /)"
```

### 2.4. Detectar y crear la matriz

```bash
./icd.sh p2 detect
./icd.sh p2 create --disks sdb,sdc,sdd,sde
./icd.sh p2 status
```

`p2/raid.sh` comprueba antes de crear la matriz que:

- cada dispositivo es un disco completo, no una partición;
- no es el disco del sistema;
- no está montado;
- no forma parte de otra matriz;
- no tiene firmas de sistema de ficheros.

Si el disco tiene firmas y estás seguro de que puedes borrarlo, el script pide
confirmación y puede usar `--force`. **`--force` es destructivo.**

### 2.5. Sincronización y tiempo

En discos reales, la sincronización inicial de RAID 5 puede tardar. El script
espera, pero tiene un límite de 300 segundos y avisa si sigue en curso.

- Para el examen, si el profesor permite el atajo y los discos están limpios,
  `--assume-clean` evita la sincronización inicial.
- Si quieres una matriz correcta y hay tiempo, no uses `--assume-clean`.
- No apagues la VM mientras `cat /proc/mdstat` muestre `recovery` o `resync`.

### 2.6. P3 sobre la matriz real

```bash
./icd.sh p3 todo
./icd.sh p3 report
```

`p3/todo.sh` exige que `/mnt/raid5` sea un punto de montaje. Si no lo es, se
detiene para no medir por error el disco del sistema. Los resultados quedan en
`p3/resultados/`.

En un disco real, los resultados dependen del modelo, de la caché y del tipo de
disco (HDD o SSD). No compares con los de un disco virtual: lo importante es
que la matriz de P2 sea la que se está midiendo.

## 3. P4 y P5: VM, LXC y pfSense

- **P4:** se puede hacer con VM Debian (`p4/vms.sh`) o con contenedores LXC
  (`contenedores/p4/lxc.sh`). Los contenedores son más rápidos de preparar y
  siguen teniendo IP propia en el bridge.
- **P5:** pfSense **no puede ser un contenedor LXC**: es una VM con FreeBSD.
  Los servidores web, la base de datos y Flask sí pueden ir en LXC.
- Los contenedores LXC se crean en el **host Proxmox** con `pct`, no dentro de
  la VM Debian.
- La guía concreta está en [`CONTENEDORES.md`](CONTENEDORES.md).

## 4. Orden recomendado en el examen

1. Leer el enunciado y anotar los cambios (IPs, discos, bridges, VMID).
2. Comprobar la red de la VM Debian.
3. P2: `detect`, crear RAID, comprobar `mdadm --detail`.
4. P3: medir sobre la matriz montada.
5. P4: crear contenedores o VM y configurar servicios.
6. P5: crear/restaurar pfSense y comprobar WAN, LAN, DMZ, DHCP, DNS y NAT.
7. Grabar las evidencias y el vídeo.

## 5. Comprobaciones rápidas

```bash
# Dentro de la VM Debian
hostname
ip -br a
lsblk -dn -o NAME,SIZE,TYPE,MODEL,SERIAL
cat /proc/mdstat
mdadm --detail /dev/md0
df -h /mnt/raid5

# En el host Proxmox
pct list
qm list
```

## 6. Errores típicos

| Síntoma | Causa | Solución |
|---|---|---|
| `mdadm: no devices` | Letra de disco incorrecta | `./icd.sh p2 detect` y usar el nombre real. |
| El script se niega a usar un disco | Es el disco del sistema, una partición o tiene firmas | Elegir otro disco; no forzar sin estar seguro. |
| La matriz tarda mucho | Discos reales grandes o HDD | Esperar o usar `--assume-clean` si el profesor lo permite. |
| P3 mide el disco del sistema | `/mnt/raid5` no está montado | Montar la matriz o usar `--target` correcto. |
| `qm`/`pct` no existe | Estás dentro de la VM Debian | Ejecutar en el host Proxmox. |
| El contenedor no arranca | Plantilla, storage o bridge incorrectos | Revisar `pveam list`, `pvesm status` e `ip -br link`. |
| pfSense no obtiene WAN | MAC o bridge incorrectos | Revisar `net0` y renovar la WAN. |

## 7. Lista de comprobación

- [ ] La VM Debian arranca y tiene red.
- [ ] Los discos reales aparecen en `lsblk` con modelo y serie.
- [ ] El disco del sistema está identificado y no se usa en P2.
- [ ] `./icd.sh p2 detect` muestra los discos correctos.
- [ ] La matriz está montada en `/mnt/raid5`.
- [ ] P3 mide `/mnt/raid5`, no el disco raíz.
- [ ] P4/P5 se ejecutan en el host Proxmox, no en la VM Debian.
- [ ] pfSense sigue siendo una VM, no un contenedor.
- [ ] No se muestran contraseñas, tokens ni `config.xml` en el vídeo.
