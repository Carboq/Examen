# P5 — pfSense en Proxmox

## Antes del examen

1. En tu pfSense del laboratorio: **Diagnostics → Backup & Restore → Backup**.
2. Guarda el `config.xml` en `p5/` (no se sube al repositorio: está en
   `.gitignore`).
3. Comprueba que el backup incluye lo que pide la práctica: interfaces,
   DHCP, DNS, reglas y NAT.

## En el examen

### 1. Crear la VM

```bash
./icd.sh p5 mac <MAC de la primera VM> <número de PC>   # apunta el resultado
# edita config.env: P5_MAC=..., P5_ISO=..., bridges...
./icd.sh p5 create
```

La VM se crea con tres NIC:

| NIC | Interfaz pfSense | Uso |
|---|---|---|
| net0 | vtnet0 | WAN (DHCP del laboratorio, MAC reservada) |
| net1 | vtnet1 | LAN / intranet |
| net2 | vtnet2 | DMZ |

La MAC reservada va **antes del primer arranque**. Si la cambias después,
tendrás que renovar la WAN.

### 2. Instalar

1. `qm start 250` y abrir la consola.
2. Aceptar, instalar, reiniciar y **quitar la ISO** (GUI: Hardware → CD/DVD →
   Remove; o `qm set 250 --delete ide2`). Deja el disco como primero:
   `qm set 250 --boot order=scsi0`.
3. Asignar interfaces: WAN = `vtnet0`, LAN = `vtnet1`, DMZ = `vtnet2`.
4. Poner la IP de LAN que pida el enunciado (la del backup puede cambiar).

### 3. Restaurar

**Diagnostics → Backup & Restore → Restore** y subir el `config.xml`.

- Si el enunciado cambia las redes, restaura primero y ajusta después
  (**Interfaces → LAN/DMZ**, **Services → DHCP Server**, reglas y NAT).
- Tras restaurar, la WAN puede quedarse sin IP: **Interfaces → WAN →
  Release/Renew** o reiniciar la VM.
- Comprueba `Interfaces → WAN` que la MAC es la reservada.

### 4. Verificar

```bash
# desde la consola de pfSense
ping -c 3 www.upv.es
pfctl -sn        # reglas NAT
pfctl -sr        # reglas de filtrado
```

Y desde un cliente de la LAN: DNS, DHCP y acceso a los servicios publicados.

## Errores típicos

- **La WAN no obtiene IP**: MAC incorrecta, bridge equivocado o el DHCP del
  laboratorio no reconoce la MAC. Revisa `net0` y renueva.
- **Las reglas no se aplican**: restaura el backup antes de tocar reglas, y
  aplica cambios (`Apply`).
- **La LAN queda en otra red**: al restaurar, pfSense recupera la IP del
  backup; ajústala si el enunciado cambió el direccionamiento.
- **El orden de las NIC no coincide**: en Proxmox, `net0/net1/net2` es el orden
  de las tarjetas; compruébalo en la consola con la asignación de interfaces.
