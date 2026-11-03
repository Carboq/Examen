# Guion para grabar la demostración en vídeo

> Objetivo: demostrar en **8–12 minutos** que las prácticas funcionan y que
> sabes explicar qué se ha hecho. No es un tutorial de instalación: es una
> demostración de resultados.
>
> **Si vas a grabar el examen de 7 puntos de Evaluación de Prestaciones**, salta
> a la [sección 7](#7-examen-de-7-puntos-prestaciones). El vídeo de las
> prácticas P1–P5 no sirve para ese examen.

## 1. Antes de grabar

### 1.1. Comprobaciones técnicas

- [ ] La VM Debian de trabajo está encendida y con red.
- [ ] P2 está creado y montado en `/mnt/raid5`.
- [ ] P3 tiene resultados (`p3/resultados/resultados.csv`).
- [ ] P4 está levantado: `web1`, `web2` y `app` responden.
- [ ] P5 está levantado: pfSense y, si se usan, los LXC de apoyo.
- [ ] El navegador tiene pestañas preparadas para las webs y pfSense.
- [ ] La terminal tiene letra grande (16–18 pt) y fondo limpio.
- [ ] No hay pestañas personales, correos ni tokens visibles.
- [ ] Silencia notificaciones y cierra mensajes privados.

### 1.2. Qué no se debe mostrar

- Contraseñas, tokens de GitHub, claves SSH.
- El contenido completo de `config.env` si tiene datos sensibles.
- `p5/config.xml` con contraseñas o hashes.
- La MAC de otro compañero o datos personales que no hagan falta.
- Ventanas de otros grupos o VMs que no sean tuyas.

### 1.3. Preparar una carpeta de evidencias

Antes de grabar, crea una carpeta para guardar capturas y salidas:

```bash
mkdir -p ~/evidencias/{p2,p3,p4,p5}
```

No hace falta que salga en el vídeo, pero te sirve para la memoria.

## 2. Estructura del vídeo

| Minuto | Bloque | Qué se muestra |
|---:|---|---|
| 0:00–0:20 | Presentación | Nombre, asignatura, fecha y prácticas que vas a enseñar. |
| 0:20–0:50 | Entorno | Proxmox, VM Debian y contenedores. |
| 0:50–2:20 | P1 | Packet Tracer: topología, rutas, DHCP, DNS y ping. |
| 2:20–4:20 | P2 | Discos reales, RAID 5, fallo y reconstrucción. |
| 4:20–5:50 | P3 | Resultados de `fio` y explicación de la tabla. |
| 5:50–8:00 | P4 | Web1, web2, app Flask, base de datos y aislamiento. |
| 8:00–10:30 | P5 | pfSense: WAN/LAN/DMZ, reglas, NAT, DHCP y servicios. |
| 10:30–11:00 | Cierre | Resumen de lo automático y lo manual. |

Si el profesor pide un vídeo más corto, usa la versión de 5 minutos del final.

## 3. Guion detallado

### 3.1. Presentación (0:00–0:20)

Mira a la cámara o al escritorio y di algo como:

> “Soy [nombre], de la asignatura Infraestructura Informática para Centros de
> Datos. Voy a demostrar las prácticas 1 a 5 en el entorno de examen: una VM
> Debian sobre Proxmox, con discos reales para RAID y contenedores LXC para los
> servicios.”

No hace falta enseñar el DNI ni datos personales.

### 3.2. Entorno (0:20–0:50)

Muestra una terminal en el **host Proxmox** o en la VM, según lo que tengas.
Lo importante es que se vea la separación:

```bash
# En el host Proxmox
pct list
qm list

# En la VM Debian
hostname
ip -br a
lsblk -dn -o NAME,SIZE,TYPE,MODEL,SERIAL
```

Di:

> “La VM Debian es donde se ejecutan P2 y P3. El host Proxmox es donde se crean
> las VM y los contenedores. Los discos de P2 y P3 son discos reales pasados a
> la VM, no discos virtuales.”

No te entretengas con todas las líneas de `lsblk`; basta con que se vean modelo
y número de serie.

### 3.3. P1: Packet Tracer (0:50–2:20)

Abre Packet Tracer con la topología terminada.

Muestra, en este orden:

1. **Topología completa**: routers, switches, PCs y servidor.
2. **Direccionamiento**: una tabla o las IPs de las interfaces.
3. **Rutas**: en la CLI de un router:

   ```text
   show ip route
   ```

4. **DHCP**: en un PC:

   ```text
   ipconfig /renew
   ipconfig
   ```

5. **DNS**: en un PC:

   ```text
   nslookup servidor.dominio
   ```

6. **Conectividad**: un `ping` entre dos redes distintas.

Si no hay Packet Tracer en el equipo de grabación, abre los ficheros
`p1/out/R1.txt` … `R4.txt` y explica la configuración, pero deja claro que la
topología se monta en Packet Tracer.

Frase de cierre del bloque:

> “La topología y el cableado son manuales; los bloques de configuración se
> generan con el script de la P1.”

### 3.4. P2: RAID 5 (2:20–4:20)

En la VM Debian:

```bash
./icd.sh p2 detect
```

Señala los discos reales y di cuál es el disco del sistema. Después:

```bash
./icd.sh p2 status
cat /proc/mdstat
mdadm --detail /dev/md0
df -h /mnt/raid5
```

Muestra:

- que `/dev/md0` está activo;
- que hay 3 discos activos y 1 de repuesto (o lo que pida el enunciado);
- que el sistema de ficheros está montado en `/mnt/raid5`;
- el tamaño y el estado `clean`.

Para demostrar el fallo y la reconstrucción:

```bash
# Opción rápida si ya lo tienes preparado:
./icd.sh p2 fail sdb
./icd.sh p2 add sdb
./icd.sh p2 status
```

Si no quieres arriesgar durante la grabación, muestra primero el estado con el
disco repuesto y explica qué haría `fail`/`add`. Es mejor un vídeo claro que una
matriz rota.

Frase:

> “El RAID 5 tolera el fallo de un disco. Al marcar uno como averiado, el
> repuesto se reconstruye; el script espera y vuelve a comprobar el estado.”

### 3.5. P3: prestaciones (4:20–5:50)

```bash
./icd.sh p3 report
```

Muestra la tabla `resultados.csv`. Explica:

- qué es `bw_MiB_s` y qué es `iops`;
- por qué 4K aleatorio da menos MB/s que 1M secuencial;
- por qué la escritura en RAID 5 puede ser más lenta que la lectura;
- que la matriz medida es la de P2, no el disco del sistema.

Si quieres enseñar una ejecución en directo:

```bash
./icd.sh p3 todo --runtime 5
```

Pero no hace falta repetir toda la batería; con la tabla y la explicación basta.

### 3.6. P4: servicios web y Flask (5:50–8:00)

Abre el navegador en tres pestañas:

1. `http://192.168.50.11/` → Apache de `web1`.
2. `http://192.168.50.12/` → Apache de `web2`, con “Servidor 2”.
3. `http://192.168.50.13/` → aplicación Flask con la tabla de productos.

En la terminal del host Proxmox:

```bash
pct list
```

Di:

> “Cada servicio tiene su propia IP. `web1` y `web2` son Apache; `app` ejecuta
> Flask, MariaDB y nginx. La aplicación lee los productos de la base de datos.”

Muestra la salud de la app:

```bash
curl -s http://192.168.50.13/salud
```

Debe salir un JSON con `estado: ok`, `servicio: icdapp` y el número de
productos.

Para demostrar que la base de datos es dinámica, puedes insertar un producto y
refrescar la página:

```bash
pct exec 203 -- mariadb icd -e \
  "INSERT INTO productos (nombre, precio, stock) VALUES ('Prueba video', 1.00, 1);"
```

Refresca `http://192.168.50.13/` y señala la fila nueva. No muestres la
contraseña.

Para demostrar el aislamiento, desde `web2`:

```bash
pct exec 202 -- bash -lc \
  'mariadb -h 192.168.50.13 -u icd -p"$ICD_DB_PASS" -e "SELECT 1"' \
  2>&1 | head
```

Si no tienes la variable, basta con explicar que el usuario de MariaDB está
creado solo para la IP de `app` y que desde `web2` no debe conectar. No enseñes
la contraseña en pantalla.

Muestra también:

```bash
pct exec 203 -- systemctl status icdapp nginx mariadb --no-pager
```

Frase:

> “La creación de los contenedores y la instalación de servicios es automática;
> lo manual es adaptar IPs, puertos y contraseñas al enunciado.”

### 3.7. P5: pfSense (8:00–10:30)

Abre la interfaz web de pfSense.

Muestra:

1. **Dashboard**: versión, estado de WAN/LAN/DMZ.
2. **Interfaces → WAN**: IP por DHCP y MAC reservada.
3. **Interfaces → LAN**: `192.168.100.1/24` (o la del enunciado).
4. **Interfaces → DMZ**: `192.168.50.1/24` (o la del enunciado).
5. **Services → DHCP Server**: rango y DNS.
6. **Firewall → Rules**: reglas de LAN y DMZ.
7. **Firewall → NAT**: salida a internet, si se pide.
8. **Status → DHCP Leases**: un cliente con IP.

En la consola de pfSense:

```bash
pfctl -sn
pfctl -sr
ping -c 3 www.upv.es
```

En el navegador:

- `http://192.168.50.11/` → web de la DMZ.
- `http://192.168.100.11/` → web de la intranet.
- `http://192.168.100.13/salud` → Flask de la intranet.

Explica:

> “pfSense es una VM porque es FreeBSD; no puede ir en LXC. Los servidores web,
> la base de datos y Flask sí pueden ir en contenedores. La WAN sale por DHCP
> con la MAC reservada; LAN y DMZ están separadas por el firewall.”

Si no tienes la web de la DMZ levantada, muestra al menos las interfaces, las
reglas y un `ping` desde LAN a la DMZ.

### 3.8. Cierre (10:30–11:00)

Resume en 30 segundos:

- P1: topología manual y configuración generada.
- P2: RAID 5 sobre discos reales, con fallo y repuesto.
- P3: medidas con `fio` sobre la matriz.
- P4: Apache, Flask, MariaDB y nginx en contenedores/VM.
- P5: pfSense con WAN, LAN, DMZ, DHCP, DNS, NAT y reglas.
- Lo que sigue siendo manual: adaptar el enunciado, instalar pfSense y revisar
  las reglas.

Termina mostrando el repositorio:

```bash
git log --oneline -3
```

o la página de GitHub, sin enseñar tokens.

## 4. Versión corta (5 minutos)

Si el profesor limita el tiempo:

| Minuto | Qué mostrar |
|---:|---|
| 0:00–0:20 | Presentación y entorno. |
| 0:20–1:00 | P2: `mdadm --detail` y `df -h`. |
| 1:00–2:00 | P3: tabla de resultados. |
| 2:00–3:30 | P4: las tres webs y `/salud`. |
| 3:30–4:40 | P5: interfaces, reglas y una web. |
| 4:40–5:00 | Cierre. |

## 5. Frases útiles

- “Este es el estado final; el proceso completo está en el repositorio.”
- “Este comando se ejecuta en el host Proxmox, no dentro de la VM.”
- “Este disco es real; por eso aparece con modelo y número de serie.”
- “La base de datos solo acepta conexiones desde la IP de la aplicación.”
- “pfSense no puede ser un contenedor porque es una VM FreeBSD.”
- “Lo que cambia en el examen se ajusta en `config.env`, no se hardcodea.”

## 6. Después de grabar

- [ ] Se ven las cinco prácticas.
- [ ] Se entiende qué es automático y qué es manual.
- [ ] No aparece ninguna contraseña ni token.
- [ ] El audio se oye y el texto de la terminal es legible.
- [ ] El vídeo tiene un nombre claro: `Apellido_Nombre_ICD_Demo.mp4`.
- [ ] Guarda una copia en el USB y otra en la nube.
- [ ] Comprueba que el vídeo se reproduce en otro equipo.

## 7. Examen de 7 puntos: Prestaciones

Este bloque sustituye al vídeo de P1–P5 si el examen elegido es el de
**Evaluación de Prestaciones de 7 puntos**. Duración objetivo: **5–7 minutos**.
Lo importante es que se vean **sistemas reales**, no solo una terminal: la VM
700 en Proxmox, los discos con modelo/serie, el RAID, los montajes y el
benchmark.

### 7.1. Antes de grabar

- [ ] La VM 700 está creada, arrancada y con red.
- [ ] Los cuatro SSD y el HDD están mapeados y visibles en `lsblk`.
- [ ] `/mnt/HDD`, `/mnt/SDD` y `/mnt/RAID` están montados.
- [ ] `/dev/md0` está activo y `clean`.
- [ ] `lectura.csv` y `escritura.csv` existen en `resultados/`.
- [ ] La terminal tiene letra grande y no muestra credenciales.
- [ ] La ventana de Proxmox no muestra la contraseña del host.

### 7.2. Tomas

| Minuto | Qué se muestra |
|---:|---|
| 0:00–0:30 | Presentación: nombre, asignatura y “examen de 7 puntos, Evaluación de Prestaciones”. |
| 0:30–1:15 | Proxmox: VM 700, nombre, hardware y los discos mapeados. |
| 1:15–2:00 | Dentro de la VM: `lsblk` con modelo/serie y `findmnt` del sistema. |
| 2:00–2:45 | `fdisk -l` de las tres particiones RAID y de la SSD/HDD. |
| 2:45–3:30 | `mdadm --detail /dev/md0`, `/proc/mdstat` y `df -h` de los tres montajes. |
| 3:30–4:30 | Ejecución corta de `bench_dd.sh` o de un `dd` de escritura/lectura. |
| 4:30–5:30 | `lectura.csv`, `escritura.csv` y `resumen.txt`; explica el mejor bloque. |
| 5:30–6:00 | Cierre: qué se ha montado y qué se entrega. |

### 7.3. Comandos que deben salir

En Proxmox:

```bash
qm config 700 | grep -E '^(name|scsi|net0)'
```

En la VM:

```bash
findmnt -n -o SOURCE /
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL,SERIAL,MOUNTPOINT
sudo fdisk -l /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf
sudo mdadm --detail /dev/md0
cat /proc/mdstat
df -h /mnt/HDD /mnt/SDD /mnt/RAID
```

Benchmark:

```bash
cd /ruta/al/repositorio/Examen/examenes/7ptos_prestaciones
sudo ./bench_dd.sh --out resultados
cat resultados/resumen.txt
```

Si quieres enseñar una ejecución muy corta, haz solo un tamaño de bloque:

```bash
sudo ./bench_dd.sh --sizes "4k" --out resultados_demo
```

### 7.4. Qué decir

> “La VM 700 está en Proxmox y ve discos reales, no discos virtuales del
> sistema. Las tres primeras SSD tienen una partición Linux RAID; la cuarta SSD
> y el HDD tienen una partición ext4. El RAID 5 está montado en `/mnt/RAID`, el
> HDD en `/mnt/HDD` y la SSD en `/mnt/SDD`. El benchmark con `dd` genera
> `lectura.csv` y `escritura.csv`, y el resumen indica el tamaño de bloque con
> mayor tasa para cada dispositivo.”

### 7.5. Qué no enseñar

- La contraseña de Proxmox.
- El contenido completo de `config.xml` o de ficheros con credenciales.
- Seriales de discos de otro compañero.
- Una matriz que no sea la del examen.

### 7.6. Cierre

```bash
cat resultados/resumen.txt
```

Termina mostrando la tabla de conclusión del DOCX y di:

> “Queda montado el RAID 5, montados los tres dispositivos y generados los dos
> CSV. El siguiente paso es desmontar, parar el RAID y limpiar las particiones
> según el anexo A.”
