# Guía manual — Examen de 7 puntos: Evaluación de Prestaciones

> **Modelo:** `20261028_EvaluacionPrestaciones_7ptos`
>
> **Dónde se hace:** dentro de una VM Debian clonada en Proxmox, con discos
> reales pasados a la VM. `qm` se ejecuta en el **host Proxmox**; `fdisk`,
> `mdadm`, `mkfs`, `mount` y el benchmark se ejecutan **dentro de la VM**.
>
> **Objetivo:** dejar montados HDD, SSD y RAID 5, ejecutar un benchmark con
> `dd` y generar `lectura.csv` y `escritura.csv`.

## 0. Resumen de lo que hay que entregar

- DOCX del examen completado.
- Capturas de todos los pasos.
- `lectura.csv`.
- `escritura.csv`.
- Script del benchmark.
- Todo dentro de `<usuarioupvnet>.zip`.

La guía completa está pensada para copiar y pegar. Los comandos destructivos
están marcados con **⚠️ PELIGRO**.

### Uso con OpenCode

OpenCode se instala y se ejecuta en la **VM Debian** (ver `AGENTS.md`). Desde
la raíz del repositorio, puedes pedirle:

> «Lee `examenes/7ptos_prestaciones/GUIA_MANUAL.md` y ayúdame a ejecutar el
> examen de 7 puntos. No ejecutes `fdisk`, `mkfs`, `mdadm` ni `wipefs` sin
> confirmar antes las letras de disco. Empieza comprobando montajes y discos.»

El script `bench_dd.sh` sí se puede ejecutar directamente porque solo mide
sobre `/mnt/HDD`, `/mnt/SDD` y `/mnt/RAID`; no reparticiona.

---

## 1. Antes de tocar ningún disco

### 1.1. Identifica el disco del sistema

Dentro de la VM Debian:

```bash
findmnt -n -o SOURCE /
lsblk -s -nlo NAME,TYPE "$(findmnt -n -o SOURCE /)"
```

Apunta cuál es el disco del sistema. Normalmente será `/dev/sda`.

**Nunca ejecutes `fdisk`, `mkfs`, `wipefs` ni `mdadm` sobre ese disco.**

### 1.2. Comprueba los discos reales

Dentro de la VM:

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,SERIAL,MOUNTPOINT
ls -l /dev/disk/by-id/
```

Debes ver:

- 4 SSD de unos 240 GB.
- 1 HDD de 1 TB.
- El disco del sistema de la VM.

Las letras pueden cambiar. No uses `/dev/sdb` “a ciegas”: comprueba tamaño,
modelo y número de serie.

### 1.3. Crea la carpeta de evidencias

```bash
mkdir -p ~/Examen-$USER/capturas
mkdir -p ~/Examen-$USER/resultados
```

Guarda ahí todas las capturas que vayas haciendo.

---

## 2. Crear o clonar la VM con ID 700

### 2.1. En Proxmox

Crea una VM clonando la plantilla Debian que indique el profesor:

- **ID:** `700`
- **Nombre:** `Debian<PrimerApellidoEstudiante>`
- **Disco:** el de la plantilla o uno nuevo.
- **Red:** `net0` en el bridge que use el laboratorio.

Si lo haces por consola del host Proxmox:

```bash
# Cambia <ID_PLANTILLA> por el ID real de la plantilla Debian
sudo qm clone <ID_PLANTILLA> 700 --name DebianApellido
sudo qm start 700
```

### 2.2. Configurar la MAC

La MAC debe ser una de las del anexo A del examen. Por ejemplo, para
`ECOMP13` el anexo indica:

```text
00:50:56:1D:11:0D
```

Confirma tu fila en el anexo. En Proxmox:

```bash
sudo qm set 700 --net0 virtio,bridge=vmbr0,macaddr=00:50:56:1D:11:0D
```

> Cambia `vmbr0` por el bridge real y la MAC por la de tu puesto.

### 2.3. Arrancar y activar el portapapeles

Dentro de la VM:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y spice-vdagent
sudo systemctl enable --now spice-vdagent
sudo reboot
```

Comprueba que hay internet:

```bash
ping -c 3 8.8.8.8
getent hosts github.com
```

---

## 3. Mapear los discos reales a la VM 700

### 3.1. Ver los discos en el host Proxmox

En el **host Proxmox**:

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,SERIAL
ls -l /dev/disk/by-id/ | grep -E 'ata-|wwn-|scsi-'
```

Identifica las 4 SSD y el HDD. Apunta el `by-id` de cada uno.

### 3.2. Pasar los discos a la VM

En el **host Proxmox**, con la VM apagada:

```bash
sudo qm set 700 --scsi1 /dev/disk/by-id/<SSD1>,serial=<SERIAL1>
sudo qm set 700 --scsi2 /dev/disk/by-id/<SSD2>,serial=<SERIAL2>
sudo qm set 700 --scsi3 /dev/disk/by-id/<SSD3>,serial=<SERIAL3>
sudo qm set 700 --scsi4 /dev/disk/by-id/<SSD4>,serial=<SERIAL4>
sudo qm set 700 --scsi5 /dev/disk/by-id/<HDD>,serial=<SERIAL_HDD>
```

Si el profesor pide el formato corto del enunciado, también vale:

```bash
sudo qm set 700 --scsi1 /dev/sdb,serial=<SERIAL1>
sudo qm set 700 --scsi2 /dev/sdc,serial=<SERIAL2>
sudo qm set 700 --scsi3 /dev/sdd,serial=<SERIAL3>
sudo qm set 700 --scsi4 /dev/sde,serial=<SERIAL4>
sudo qm set 700 --scsi5 /dev/sdf,serial=<SERIAL_HDD>
```

Comprueba:

```bash
qm config 700 | grep -E '^(scsi|scsihw|net0)'
```

Arranca la VM:

```bash
sudo qm start 700
```

### 3.3. Confirmar dentro de la VM

Dentro de la VM:

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,SERIAL,MOUNTPOINT
ls -l /dev/disk/by-id/
```

Rellena la tabla del examen con el serial de cada SSD.

---

## 4. Preparar los discos

> **⚠️ PELIGRO:** los siguientes comandos borran las tablas de particiones.
> Comprueba dos veces que las letras corresponden a las SSD/HDD y **nunca** al
> disco del sistema.

### 4.1. Definir las variables

Dentro de la VM, ajusta las letras según tu `lsblk`:

```bash
SYS=/dev/sda       # disco del sistema: NO TOCAR
SSD1=/dev/sdb
SSD2=/dev/sdc
SSD3=/dev/sdd
SSD4=/dev/sde
HDD=/dev/sdf
```

Comprueba que no son el sistema:

```bash
findmnt -n -o SOURCE /
lsblk -dn -o NAME,SIZE,MODEL,SERIAL "$SYS" "$SSD1" "$SSD2" "$SSD3" "$SSD4" "$HDD"
```

### 4.2. Borrar las tablas de particiones

```bash
for d in "$SSD1" "$SSD2" "$SSD3" "$SSD4" "$HDD"; do
  echo "== Limpiando $d =="
  echo -e "g\nw" | sudo fdisk "$d"
done
```

### 4.3. Crear las tres particiones RAID

En las tres primeras SSD:

```bash
for d in "$SSD1" "$SSD2" "$SSD3"; do
  echo "== Partición RAID en $d =="
  printf 'g\nn\n1\n\n+100G\nt\n1\nfd\nw\n' | sudo fdisk "$d"
done
```

`fd` es el alias de **Linux RAID** en GPT.

> Si el profesor insiste en una partición de 200 MB, ten en cuenta que no cabe
> un fichero de prueba de 1 GiB. Para el benchmark hace falta una partición
> grande; usa 100 GB o pregunta antes de continuar.

### 4.4. Crear las particiones ext4

En la cuarta SSD y en el HDD:

```bash
for d in "$SSD4" "$HDD"; do
  echo "== Partición Linux en $d =="
  printf 'g\nn\n1\n\n\nt\n1\n20\nw\n' | sudo fdisk "$d"
done
```

`20` es el alias de **Linux filesystem** en GPT.

### 4.5. Verificar las particiones

```bash
sudo fdisk -l "$SSD1" "$SSD2" "$SSD3" "$SSD4" "$HDD"
lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTTYPENAME
```

Debes ver:

- `sdb1`, `sdc1`, `sdd1` de tipo `Linux RAID`.
- `sde1` y `sdf1` de tipo `Linux filesystem`.

### 4.6. Formatear SSD y HDD

```bash
sudo mkfs.ext4 -F "${SSD4}1"
sudo mkfs.ext4 -F "${HDD}1"
```

### 4.7. Crear el RAID 5

```bash
sudo mdadm --create --verbose /dev/md0 \
  --level=5 \
  --raid-devices=3 \
  "${SSD1}1" "${SSD2}1" "${SSD3}1"

sudo mkfs.ext4 -F /dev/md0
sudo mdadm --detail /dev/md0
cat /proc/mdstat
```

Espera a que termine la sincronización. Si `cat /proc/mdstat` muestra
`resync` o `recovery`, no reinicies.

### 4.8. Montar los tres dispositivos

```bash
sudo mkdir -p /mnt/HDD /mnt/SDD /mnt/RAID
sudo mount "${HDD}1" /mnt/HDD
sudo mount "${SSD4}1" /mnt/SDD
sudo mount /dev/md0 /mnt/RAID
```

Comprueba:

```bash
df -h /mnt/HDD /mnt/SDD /mnt/RAID
findmnt /mnt/HDD /mnt/SDD /mnt/RAID
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
```

Haz una captura de `ls -la /mnt/HDD`, `/mnt/SDD` y `/mnt/RAID`.

> El enunciado a veces escribe `/mnt/SSD` en las figuras, pero los comandos
> piden `/mnt/SDD`. Usa el mismo nombre que exija el profesor; si cambia,
> ajusta también `bench_dd.sh --targets`.

---

## 5. Ejecutar el benchmark

### 5.1. Usar el script del repositorio

Dentro de la VM, desde esta carpeta:

```bash
cd /ruta/al/repositorio/Examen/examenes/7ptos_prestaciones
chmod +x bench_dd.sh verificar.sh
sudo ./verificar.sh
sudo ./bench_dd.sh --out resultados
```

El script:

- comprueba que los tres puntos de montaje existen;
- crea un fichero temporal de 1 GiB por cada tamaño de bloque;
- mide escritura y lectura con `dd`;
- genera `resultados/escritura.csv`, `resultados/lectura.csv` y
  `resultados/resumen.txt`;
- borra los ficheros temporales salvo que uses `--keep`.

Al terminar:

```bash
cat resultados/escritura.csv
cat resultados/lectura.csv
cat resultados/resumen.txt
```

### 5.2. Si el profesor no permite scripts

La orden básica de escritura es:

```bash
sudo dd if=/dev/zero of=/mnt/HDD/BlockSize001k_FileSize1Gib.txt \
  bs=1k count=1048576 status=progress oflag=direct conv=fsync
```

La orden básica de lectura es:

```bash
sudo dd if=/mnt/HDD/BlockSize001k_FileSize1Gib.txt \
  of=/dev/null bs=1k count=1048576 status=progress iflag=direct
```

Repite para `1k 2k 4k 8k 16k 32k 64k 128k 256k` en `/mnt/HDD`, `/mnt/SDD` y
`/mnt/RAID`.

Puedes usar este bucle para un dispositivo:

```bash
cd /mnt/HDD
for bs in 1k 2k 4k 8k 16k 32k 64k 128k 256k; do
  n=$((1073741824 / (${bs%k} * 1024)))
  echo "== HDD escritura $bs =="
  sudo dd if=/dev/zero of="bench_${bs}.bin" bs="$bs" count="$n" \
    status=progress oflag=direct conv=fsync
  echo "== HDD lectura $bs =="
  sudo dd if="bench_${bs}.bin" of=/dev/null bs="$bs" count="$n" \
    status=progress iflag=direct
  sudo rm -f "bench_${bs}.bin"
done
```

Cambia `/mnt/HDD` por `/mnt/SDD` y `/mnt/RAID` para los otros dos.

### 5.3. Rellenar la conclusión

Con `resultados/resumen.txt` o mirando los CSV, completa:

| Dispositivo | Mejor bloque de lectura | Mejor bloque de escritura |
|---|---|---|
| HDD | | |
| SSD | | |
| RAID 5 | | |

El “mejor” es el que da **mayor tasa** para cada dispositivo y operación.

---

## 6. Capturas que hay que hacer

Guarda todas en `~/Examen-$USER/capturas`:

- [ ] VM 700 creada y con el nombre correcto.
- [ ] Configuración de red/MAC de la VM.
- [ ] `lsblk` con los discos y seriales.
- [ ] Tabla de seriales rellena.
- [ ] Órdenes `qm set` de los cinco discos.
- [ ] `fdisk -l` de las tres particiones RAID.
- [ ] `fdisk -l` de la SSD y del HDD.
- [ ] `lsblk` con todas las particiones.
- [ ] `mkfs.ext4` de SSD y HDD.
- [ ] `mdadm --create` y `mdadm --detail /dev/md0`.
- [ ] `mount` y `df -h` de `/mnt/HDD`, `/mnt/SDD`, `/mnt/RAID`.
- [ ] `ls -la` de los tres puntos de montaje.
- [ ] Ejecución del benchmark.
- [ ] `lectura.csv` y `escritura.csv`.
- [ ] Tabla de conclusión rellena.

---

## 7. Respuestas que pide el documento

> Copia estas plantillas en el DOCX y cambia las letras/seriales por los
> reales.

### 7.1. Órdenes para mapear las SSD

```text
sudo qm set 700 --scsi1 /dev/disk/by-id/<SSD1>,serial=<SERIAL1>
sudo qm set 700 --scsi2 /dev/disk/by-id/<SSD2>,serial=<SERIAL2>
sudo qm set 700 --scsi3 /dev/disk/by-id/<SSD3>,serial=<SERIAL3>
sudo qm set 700 --scsi4 /dev/disk/by-id/<SSD4>,serial=<SERIAL4>
```

### 7.2. Comando para crear el RAID

```bash
sudo mdadm --create --verbose /dev/md0 --level=5 --raid-devices=3 \
  /dev/sdb1 /dev/sdc1 /dev/sdd1
```

### 7.3. Órdenes de formateo

```bash
sudo mkfs.ext4 /dev/sde1
sudo mkfs.ext4 /dev/sdf1
```

### 7.4. Órdenes de montaje

```bash
sudo mount /dev/sdf1 /mnt/HDD
sudo mount /dev/sde1 /mnt/SDD
sudo mount /dev/md0 /mnt/RAID
```

### 7.5. Primera orden `dd` de escritura

```bash
sudo dd if=/dev/zero of=/mnt/HDD/BlockSize001k_FileSize1Gib.txt \
  bs=1k count=1048576 status=progress oflag=direct conv=fsync
```

---

## 8. Crear el entregable

```bash
USUARIO=tu_usuario_upvnet
mkdir -p ~/Examen-$USUARIO/capturas
mkdir -p ~/Examen-$USUARIO/resultados

# Copia el DOCX completado y las capturas
cp /ruta/al/DOCX/20261028_EvaluacionPrestaciones_7ptos.docx ~/Examen-$USUARIO/
cp ~/Examen-$USER/capturas/* ~/Examen-$USUARIO/capturas/

# Copia los CSV y el script
cp resultados/lectura.csv resultados/escritura.csv ~/Examen-$USUARIO/resultados/
cp bench_dd.sh ~/Examen-$USUARIO/

cd ~/Examen-$USUARIO
zip -r "$USUARIO.zip" .
```

Subir a Poliformat y copiar al servidor:

```bash
scp "$USUARIO.zip" "$USUARIO"@giirob-lemus.disca.upv.es:~/
```

---

## 9. Limpieza final

> **⚠️ PELIGRO:** solo después de haber entregado y con las letras correctas.

```bash
sudo umount /mnt/RAID
sudo umount /mnt/SDD
sudo umount /mnt/HDD
sudo mdadm --stop /dev/md0
sudo wipefs -a "${SSD1}1" "${SSD2}1" "${SSD3}1" "${SSD4}1" "${HDD}1"
sudo reboot
```

Si el examen pide dejar las particiones, no ejecutes `wipefs`; limita la
limpieza a desmontar y parar el RAID.

---

## 10. Errores típicos

| Síntoma | Causa | Solución |
|---|---|---|
| `mdadm: no devices` | Letra de disco incorrecta | Repetir `lsblk` y ajustar variables |
| `Device or resource busy` al formatear | Disco montado | `findmnt` y desmontar |
| `mdadm: /dev/sdb1 is not a block device` | Partición mal creada | Repetir `fdisk -l` |
| `dd: invalid number` | `count` mal calculado | Usar el script `bench_dd.sh` |
| `dd: failed to open ... Invalid argument` | `oflag=direct` no soportado en ese FS | El script reintenta sin `direct` |
| El RAID tarda mucho | Discos reales | Esperar; no reiniciar |
| No aparece `/mnt/RAID` | No se montó | `sudo mount /dev/md0 /mnt/RAID` |

---

## 11. Chuleta de comandos

```bash
# Identificar
findmnt -n -o SOURCE /
lsblk -o NAME,SIZE,TYPE,MODEL,SERIAL,MOUNTPOINT

# Variables (AJUSTAR)
SYS=/dev/sda
SSD1=/dev/sdb; SSD2=/dev/sdc; SSD3=/dev/sdd; SSD4=/dev/sde; HDD=/dev/sdf

# Limpiar GPT
for d in "$SSD1" "$SSD2" "$SSD3" "$SSD4" "$HDD"; do
  echo -e "g\nw" | sudo fdisk "$d"
done

# Particiones RAID
for d in "$SSD1" "$SSD2" "$SSD3"; do
  printf 'g\nn\n1\n\n+100G\nt\n1\nfd\nw\n' | sudo fdisk "$d"
done

# Particiones ext4
for d in "$SSD4" "$HDD"; do
  printf 'g\nn\n1\n\n\nt\n1\n20\nw\n' | sudo fdisk "$d"
done

# Formatear
sudo mkfs.ext4 -F "${SSD4}1"
sudo mkfs.ext4 -F "${HDD}1"

# RAID 5
sudo mdadm --create --verbose /dev/md0 --level=5 --raid-devices=3 \
  "${SSD1}1" "${SSD2}1" "${SSD3}1"
sudo mkfs.ext4 -F /dev/md0
sudo mdadm --detail /dev/md0

# Montar
sudo mkdir -p /mnt/HDD /mnt/SDD /mnt/RAID
sudo mount "${HDD}1" /mnt/HDD
sudo mount "${SSD4}1" /mnt/SDD
sudo mount /dev/md0 /mnt/RAID

# Benchmark
cd /ruta/al/repositorio/Examen/examenes/7ptos_prestaciones
sudo ./bench_dd.sh --out resultados
```
