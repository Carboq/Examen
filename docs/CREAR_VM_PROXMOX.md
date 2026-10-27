# Crear una VM en Proxmox VE y conectarla a la red

> Entorno de referencia: **Proxmox VE 8/9**, con una VM **Debian 12** para las
> prácticas P2/P3 y para trabajar con el repositorio. La interfaz puede cambiar
> ligeramente entre versiones, pero los conceptos y los comandos de `qm` son los
> mismos.
>
> Este documento es de apoyo. No sustituye al enunciado ni a las instrucciones
> del profesor: si cambian el VMID, la IP, la VLAN o la MAC, manda el enunciado.

## 0. Lo mínimo para tener internet

Si la VM ya existe y solo falta la red, ve directamente al apartado
[5. Conectar la VM a internet](#5-conectar-la-vm-a-internet). El resumen es:

1. La VM debe tener una tarjeta de red conectada al bridge **`vmbr0`**.
2. La MAC debe ser la asignada para tu equipo; no vale una cualquiera si el
   laboratorio filtra por MAC.
3. Dentro de la VM debe haber una IP, una puerta de enlace y un DNS.
4. `vmbr1` y `vmbr2` suelen ser redes internas: no dan internet por sí solas.

## 1. Antes de empezar

- **No toques VM que no sean tuyas.** Comprueba el nombre y el VMID antes de
  arrancar, apagar o modificar nada.
- **`qm` se ejecuta en el host Proxmox, como root.** No se ejecuta dentro de la
  VM Debian. Si no tienes root en el host, crea la VM desde la interfaz web o
  pide al administrador que ejecute los comandos.
- Ten localizada la **ISO de Debian** en el almacenamiento de Proxmox, o sube
  una desde la GUI.
- Ten a mano los datos del laboratorio:
  - VMID libre (por ejemplo, `250`);
  - nombre de la VM;
  - almacenamiento de discos (`local-lvm`, `local`, etc.);
  - bridge de salida (`vmbr0`);
  - MAC asignada;
  - IP fija o DHCP, según lo que indique el profesor.

## 2. Conceptos: host, VM y bridge

En Proxmox hay dos niveles que no hay que mezclar:

| Nivel | Qué es | Dónde se ejecuta |
|---|---|---|
| **Host Proxmox** | El servidor físico con Proxmox VE. Aquí vive `qm`. | Consola/SSH del host, como root. |
| **VM** | El ordenador virtual con Debian. Aquí viven `ip`, `ping`, `apt`, etc. | Consola de la VM o SSH a la VM. |

Un **bridge** (`vmbrX`) es un switch virtual. Las tarjetas de red de las VM se
conectan a ese switch:

- **`vmbr0`**: normalmente está conectado a la tarjeta física del host y a la
  red del laboratorio. Es el bridge que da salida a internet.
- **`vmbr1`**, **`vmbr2`**: redes internas. Sirven para aislar las prácticas,
  pero **no tienen salida a internet** salvo que haya un router/NAT o un
  pfSense que las enrute.

Proxmox no “activa internet” dentro de la VM por arte de magia: la VM tiene que
estar conectada a un bridge con salida y debe recibir una IP válida.

## 3. Crear la VM desde la interfaz web

Esta es la opción recomendada si no tienes root en el host.

### 3.1. Subir la ISO

1. Entra en la interfaz web de Proxmox.
2. Selecciona el nodo (por ejemplo, `pve`).
3. Ve a **local → ISO Images → Upload**.
4. Sube la ISO de Debian 12.

Si la ISO ya está subida, sáltate este paso.

### 3.2. Asistente de creación

Pulsa **Create VM** y revisa cada pestaña:

#### General

- **Node:** el host donde se ejecutará la VM.
- **VM ID:** un número libre. No reutilices el de otra VM.
- **Name:** por ejemplo, `debian-lab`.
- **Start at boot:** opcional. Déjalo desmarcado si no quieres que arranque
  sola.
- **Resource Pool:** déjalo vacío si no usas pools.

#### OS

- **Use CD/DVD disc image file (ISO)**.
- **Storage:** `local` (o donde hayas subido la ISO).
- **ISO image:** la ISO de Debian 12.
- **Guest OS:** Linux, versión 6.x/2.6 Kernel.

#### System

- **SCSI Controller:** `VirtIO SCSI single` (buena opción para Linux).
- **QEMU Agent:** marcado. Después hay que instalar `qemu-guest-agent` dentro de
  la VM.
- **BIOS:** `Default (SeaBIOS)` salvo que el enunciado pida OVMF.
- **Machine:** la opción por defecto.
- **TPM:** no hace falta para Debian.

#### Disks

- **Bus/Device:** `SCSI`, número `0`.
- **Storage:** el almacenamiento del laboratorio, por ejemplo `local-lvm`.
- **Disk size:** 32 GB es suficiente para Debian y las prácticas. Ajusta si el
  profesor indica otro tamaño.
- **Cache:** `No cache`.
- **Discard:** puedes marcarlo si el almacenamiento lo soporta; no es
  obligatorio.

#### CPU

- **Sockets:** `1`.
- **Cores:** `2` es un valor razonable.
- **Type:** `host` o el que indique el laboratorio.

#### Memory

- **Memory:** 2048 MB o 4096 MB. Para Debian con interfaz gráfica, mejor 4096 MB.

#### Network

- **Bridge:** **`vmbr0`**.
- **Model:** `VirtIO (paravirtualized)`.
- **MAC address:** la asignada. Si el campo está vacío, Proxmox genera una;
  pero si el laboratorio filtra por MAC, escríbela manualmente.
- **Firewall:** déjalo desmarcado salvo que el profesor pida lo contrario.
- **VLAN tag:** vacío salvo que el laboratorio use VLANs.

> La MAC no se debe inventar ni repetir. En este laboratorio se ha usado una
> convención basada en el prefijo asignado y el número de PC. Por ejemplo, para
> el PC 14: `BC:24:11:0A:11:0E`. Confirma siempre con el profesor cuál es la
> tuya.

#### Confirm

Revisa el resumen y pulsa **Finish**.

### 3.3. Instalar Debian

1. Selecciona la VM y pulsa **Start**.
2. Abre **Console** (noVNC).
3. Instala Debian con las opciones habituales:
   - red por **DHCP** si el laboratorio la proporciona;
   - usuario y contraseña propios;
   - disco completo, con LVM si quieres;
   - paquetes: **SSH server** y utilidades estándar.
4. Al terminar, reinicia y **expulsa la ISO** o cambia el orden de arranque para
   que no vuelva a entrar en el instalador.

Para expulsar la ISO desde la GUI: **Hardware → CD/DVD Drive → Edit → Do not use
any media**.

## 4. Crear la VM con `qm` (solo host, como root)

Esto es equivalente al asistente, pero reproducible. Sirve si tienes acceso
root al host o si el administrador te lo permite.

### 4.1. Comprobar datos

```bash
qm list
pvesm status
```

- `qm list` muestra las VM y sus VMID.
- `pvesm status` muestra los almacenamientos disponibles.

Elige un VMID libre y un almacenamiento que exista.

### 4.2. Crear la VM

Ejemplo para una Debian de 32 GB, 2 GB de RAM, 2 vCPU y una NIC en `vmbr0`:

```bash
VMID=250
NAME=debian-lab
MAC=BC:24:11:0A:11:0E
STORAGE=local-lvm
ISO=local:iso/debian-12-netinst.iso

qm create "$VMID" \
  --name "$NAME" \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0,macaddr="$MAC" \
  --scsihw virtio-scsi-pci \
  --scsi0 "$STORAGE":32 \
  --ide2 "$ISO",media=cdrom \
  --boot 'order=ide2;scsi0' \
  --ostype l26 \
  --agent enabled=1
```

Notas:

- `--scsi0 "$STORAGE":32` crea un disco de 32 GiB.
- `--ide2 ...` conecta la ISO como CD-ROM.
- `--boot 'order=ide2;scsi0'` arranca primero desde la ISO para instalar. Las
  comillas son necesarias porque `;` separa comandos en bash.
- `--ostype l26` es el tipo genérico para Linux moderno.
- `--agent enabled=1` habilita el canal del QEMU Guest Agent. Luego hay que
  instalar el agente dentro de la VM.

Si tu ISO o tu almacenamiento tienen otro nombre, cámbialos. Puedes comprobar
los volúmenes con:

```bash
pvesm list local
```

### 4.3. Arrancar e instalar

```bash
qm start "$VMID"
qm status "$VMID"
```

Abre la consola desde la GUI o, si has añadido un puerto serie, con:

```bash
qm terminal "$VMID"
```

Si `qm terminal` no responde, añade el puerto serie y reinicia la VM:

```bash
qm set "$VMID" --serial0 socket
qm reboot "$VMID"
```

Instala Debian como en el apartado 3.3.

### 4.4. Después de instalar

Cuando Debian ya esté instalado, haz que arranque desde el disco:

```bash
qm set "$VMID" --boot 'order=scsi0'
```

Expulsa la ISO desde la GUI o desconecta el CD-ROM. Comprueba la configuración:

```bash
qm config "$VMID"
```

### 4.5. Cambiar la red de una VM existente

Si la VM ya existe pero está en el bridge equivocado:

```bash
qm set "$VMID" --net0 virtio,bridge=vmbr0,macaddr="$MAC"
```

Si necesitas conservar la red interna y añadir salida a internet, añade una
segunda tarjeta. La MAC de salida debe ser **distinta** de la que ya use `net0`:

```bash
MAC_SALIDA=...   # MAC autorizada para vmbr0, distinta de la de net0
qm set "$VMID" --net1 virtio,bridge=vmbr0,macaddr="$MAC_SALIDA"
```

Comprueba que no hay dos MAC iguales:

```bash
qm config "$VMID" | grep '^net'
```

Si el laboratorio solo autoriza una MAC, ponla en la NIC de `vmbr0` y deja la
NIC interna con otra MAC (o con la MAC que ya tuviera). No pongas la misma MAC
en dos interfaces.

## 5. Conectar la VM a internet

### 5.1. Caso normal: una sola NIC en `vmbr0`

Es el montaje más sencillo:

```text
VM Debian (net0) --- vmbr0 --- tarjeta física --- red del laboratorio --- internet
```

En la GUI:

1. Apaga la VM.
2. **Hardware → Network Device**.
3. Comprueba:
   - **Bridge:** `vmbr0`;
   - **Model:** `VirtIO`;
   - **MAC:** la asignada;
   - que el dispositivo no esté desconectado.
4. Arranca la VM.

Dentro de Debian:

```bash
ip -br a
ip route
```

Debe aparecer una interfaz con IP (por ejemplo, `ens18`) y una ruta `default
via ...`.

### 5.2. Si la VM está en `vmbr1` o `vmbr2`

Esas redes son internas. Tienes dos opciones:

**Opción A: añadir una segunda NIC en `vmbr0`**

Recomendada si necesitas mantener la red interna de la práctica.

1. Apaga la VM.
2. **Hardware → Add → Network Device**.
3. Bridge: `vmbr0`.
4. Model: `VirtIO`.
5. MAC: la asignada para salir a internet, **distinta** de la MAC de la NIC
   interna.
6. Arranca la VM.

Dentro de la VM aparecerá otra interfaz, por ejemplo `ens19`. Pide DHCP:

```bash
sudo dhclient -r ens19
sudo dhclient ens19
```

O, si usas NetworkManager:

```bash
sudo nmcli device connect ens19
```

**Opción B: cambiar la NIC actual a `vmbr0`**

Solo si no necesitas la red interna:

1. Apaga la VM.
2. **Hardware → Network Device → Edit**.
3. Cambia **Bridge** a `vmbr0`.
4. Guarda y arranca.

### 5.3. DHCP o IP fija

Lo normal en el laboratorio es **DHCP**. Si el profesor te da una IP fija,
configúrala dentro de Debian.

Con NetworkManager:

```bash
sudo nmcli con show
sudo nmcli con mod "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.10.50/24 \
  ipv4.gateway 192.168.10.1 \
  ipv4.dns "1.1.1.1"
sudo nmcli con up "Wired connection 1"
```

Con `ifupdown` (el método clásico de Debian), edita
`/etc/network/interfaces`:

```bash
sudo cp /etc/network/interfaces /etc/network/interfaces.bak
sudo nano /etc/network/interfaces
```

Ejemplo, sustituyendo la interfaz y los datos por los reales:

```text
auto ens18
iface ens18 inet static
    address 192.168.10.50/24
    gateway 192.168.10.1
    dns-nameservers 1.1.1.1
```

Luego:

```bash
sudo systemctl restart networking
```

No uses a la vez NetworkManager y `ifupdown` para la misma interfaz. Comprueba
cuál está activo antes de cambiar nada.

## 6. Comprobar la conexión

Dentro de la VM:

```bash
ip -br a
ip route
ping -c 3 8.8.8.8
getent hosts github.com
ping -c 3 github.com
curl -I https://github.com
```

Interpretación:

| Resultado | Significado |
|---|---|
| `ping 8.8.8.8` funciona y `github.com` también | Internet y DNS correctos. |
| `ping 8.8.8.8` funciona, pero `github.com` no | Falta DNS o es incorrecto. |
| No hay IP | DHCP, bridge o MAC. |
| Hay IP, pero no hay ruta `default` | Falta puerta de enlace. |
| Hay IP y ruta, pero no responde nada | Firewall, VLAN o salida del laboratorio. |

Para DNS, mira:

```bash
cat /etc/resolv.conf
resolvectl status
```

Si el DNS falla y el profesor no ha dado uno, prueba de forma temporal:

```bash
sudo nano /etc/resolv.conf
```

```text
nameserver 1.1.1.1
```

En Debian 12, `/etc/resolv.conf` puede estar gestionado por
`systemd-resolved` o por NetworkManager. Si se sobrescribe, configura el DNS
desde `nmcli` o desde la configuración de la interfaz, no solo en ese archivo.

## 7. Acceso a la VM

### Consola

En la GUI: selecciona la VM y pulsa **Console**. Es lo más útil mientras se
instala el sistema o si se pierde la red.

### SSH

Si durante la instalación marcaste **SSH server**:

```bash
ssh usuario@IP_DE_LA_VM
```

Para saber la IP:

```bash
ip -br a
```

La IP también puede aparecer en el resumen de la VM si el QEMU Guest Agent está
instalado y habilitado.

Para instalar el agente dentro de Debian:

```bash
sudo apt update
sudo apt install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

## 8. Casos particulares de P4 y P5

### P4

En este repositorio, `config.env` usa `BRIDGE=vmbr1` para las VM de la P4. Esa
es la red de servicio de la práctica. Si necesitas internet para instalar
paquetes:

- añade temporalmente una segunda NIC en `vmbr0`, o
- usa una plantilla que ya tenga Apache, MariaDB, Flask y nginx instalados.

No cambies la IP de servicio de `vmbr1` solo para tener internet: puedes romper
la práctica.

### P5

pfSense usa tres redes:

```text
net0 -> vmbr0 (WAN)
net1 -> vmbr1 (LAN)
net2 -> vmbr2 (DMZ)
```

Las VM de la intranet deben salir por pfSense, no conectarse directamente a
`vmbr0`. Si las conectas directamente, se saltan el firewall y la práctica deja
de tener sentido.

## 9. Problemas típicos

### `qm: command not found`

Estás dentro de la VM Debian, no en el host Proxmox. `qm` solo existe en el
host.

### `permission denied` al usar `qm`

No eres root en el host. Usa la GUI o pide acceso al administrador. No intentes
resolverlo cambiando permisos de archivos del sistema.

### La VM no tiene IP

Comprueba, en este orden:

1. Que la NIC esté conectada a `vmbr0`.
2. Que el dispositivo no esté desconectado en la GUI.
3. Que la MAC sea la asignada y no esté repetida.
4. Que el DHCP del laboratorio esté activo en ese puerto.
5. Que no haya una VLAN mal configurada.

Dentro de la VM:

```bash
sudo dhclient -v
ip -br a
```

### La VM tiene IP, pero no sale a internet

```bash
ip route
ping -c 3 8.8.8.8
```

Si no hay ruta `default`, falta la puerta de enlace. Si hay ruta y no responde,
revisa firewall, VLAN y salida del laboratorio.

### `github.com` no resuelve, pero `8.8.8.8` sí

Es DNS. Revisa `/etc/resolv.conf` y la configuración de la interfaz.

### La VM está en `vmbr1` y no tiene internet

Es lo esperado. `vmbr1` es una red interna. Añade una NIC en `vmbr0` o sal a
través de pfSense.

### Proxmox avisa de MAC duplicada

Dos VM o interfaces están usando la misma MAC. Cambia una de ellas antes de
arrancar; si no, la red puede comportarse de forma impredecible.

## 10. Lista de comprobación

- [ ] La VM es mía y el VMID no pertenece a otra persona.
- [ ] La ISO de Debian está subida al almacenamiento correcto.
- [ ] El disco tiene tamaño suficiente y está en el almacenamiento correcto.
- [ ] La NIC está en `vmbr0` para internet.
- [ ] La MAC es la asignada y no está duplicada.
- [ ] Debian tiene IP y ruta `default`.
- [ ] `ping 8.8.8.8` funciona.
- [ ] `getent hosts github.com` funciona.
- [ ] `curl -I https://github.com` responde.
- [ ] Si es P4/P5, la red interna sigue siendo `vmbr1`/`vmbr2` y no se ha
      mezclado con la salida a internet.

## 11. Referencias

Documentación oficial consultada el **27/10/2026** (Proxmox VE 9.2.13):

- [QEMU/KVM Virtual Machines](https://pve.proxmox.com/pve-docs/chapter-qm.html)
- [qm(1) — QEMU/KVM Virtual Machine Manager](https://pve.proxmox.com/pve-docs/qm.1.html)
- [Network Configuration](https://pve.proxmox.com/wiki/Network_Configuration)

La interfaz de Proxmox VE 8 puede mostrar los mismos campos con pequeños cambios
de texto. Si el laboratorio usa Proxmox VE 8, los comandos `qm` y los bridges
siguen el mismo esquema.
