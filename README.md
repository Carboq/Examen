# ICD — Repositorio de examen

Apoyo para el parcial de laboratorio de **Infraestructura Informática para
Centros de Datos** (UPV). Reproduce con scripts los montajes de las prácticas
1 a 5 y deja a la vista lo que sigue siendo manual.

> El parcial se hace «con algún cambio». Los valores de este repositorio son
> puntos de partida: lee el enunciado, ajusta `config.env` y revisa la lista de
> discos antes de ejecutar nada.

## Requisitos

- **Proxmox VE 8** en el host, para P4 y P5.
- **Debian 12** dentro de la MV, para P2 y P3.
- **pfSense 2.7** para P5.
- `bash`, `lsblk`, `mdadm`, `wipefs` (P2); `fio` (P3); `qm` (P4/P5).

## Estructura

```
icd-examen/
├── icd.sh                  entrada única: ./icd.sh p2 ...
├── config.env.example      variables del entorno (copiar a config.env)
├── lib/common.sh           funciones compartidas
├── p1/                     Packet Tracer: no hay automatización externa
│   ├── LEEME.md            procedimiento y tiempos
│   ├── generar.sh          sustituye los {{ }} de los bloques
│   ├── todo.sh             genera y muestra los pasos manuales
│   ├── valores.env.example valores del esquema
│   └── configs/            bloques para pegar en la CLI de cada router
├── p2/raid.sh              RAID 5 con mdadm (crear, fallar, reponer)
├── p2/todo.sh              práctica completa: crear, fallar y reponer
├── p3/bench.sh             fio y tabla de resultados
├── p3/todo.sh              instala fio y ejecuta las medidas
├── p4/vms.sh               creación de VM en Proxmox con qm
├── p4/servicios.sh         Apache, MariaDB, Flask y nginx dentro de la VM
├── p4/todo.sh              crea y arranca las VM de la P4
├── p4/vms.conf.example     una VM por línea
├── p5/pfsense.sh           VM de pfSense con 3 NIC y MAC reservada
├── p5/todo.sh              calcula la MAC, crea y arranca la VM
├── p5/LEEME.md             instalación, restauración y ajuste
├── docs/GUIA_EJECUCION.md  guía paso a paso de las cinco prácticas
└── docs/simulacros/P4.md   enunciado y guía del simulacro de la P4
```

## Puesta en marcha

```bash
git clone https://github.com/Carboq/Examen.git
cd Examen
cp config.env.example config.env
$EDITOR config.env          # bridges, storage, VMID, MAC, discos...
```

El repo es privado: si usas `git clone`, GitHub pedirá usuario `Carboq` y un
token como contraseña. También puedes descargar el ZIP desde la web
(**Code → Download ZIP**). No hace falta USB: descárgalo en el equipo que tenga
red.

Los ficheros con datos del laboratorio no se suben al repositorio:
`config.env`, `p4/vms.conf`, `p1/valores.env`, `p1/out/` y `p5/config.xml`.
En una copia nueva hay que crearlos a partir de los `.example`.

Cada script acepta argumentos; `config.env` solo aporta los valores por
defecto. Comprueba la ayuda de cada uno:

```bash
./icd.sh p2 help
./icd.sh p5 help
```

## Ejecución rápida

| Práctica | Comando | Dónde |
|---|---|---|
| P1 | `./icd.sh p1 todo` | PC con Git Bash o VM Linux (Packet Tracer aparte) |
| P2 | `./icd.sh p2 todo sdb,sdc,sdd,sde` | VM Debian con los discos |
| P3 | `./icd.sh p3 todo` | VM Debian con la matriz montada |
| P4 | `./icd.sh p4 todo` | host Proxmox |
| P4 servicios | `sudo ./p4/servicios.sh web1` | dentro de cada VM Debian |
| P5 | `./icd.sh p5 todo --mac-base MAC --pc 7` | host Proxmox |

La guía completa, con el orden, las comprobaciones y los errores típicos, está
en [`docs/GUIA_EJECUCION.md`](docs/GUIA_EJECUCION.md).

## Qué automatiza cada práctica

| Práctica | Automático | Manual |
|---|---|---|
| P1 | bloques de configuración listos para pegar | topología, cableado, DHCP/DNS en la GUI |
| P2 | detección de discos, `mdadm`, `mkfs`, montaje, fallo y reconstrucción | mapear los discos si se hace por GUI |
| P3 | `fio` y tabla de resultados | montajes previos y lectura de resultados |
| P4 | creación de las VM con `qm` y configuración de Apache, MariaDB, Flask y nginx dentro de cada VM | instalar Debian o clonar la plantilla |
| P5 | creación de la VM con 3 NIC y MAC reservada | instalación de pfSense, restauración y ajuste de IPs |

### P4: crear la VM y configurar los servicios

En el host Proxmox, crea y arranca las VM:

```bash
./icd.sh p4 todo
```

El script de servicios se ejecuta **dentro** de cada VM Debian, no en el host:

```bash
# En web1
sudo ./p4/servicios.sh web1
# En web2
sudo ./p4/servicios.sh web2
# En app
sudo ./p4/servicios.sh app
```

Si la plantilla no tiene los paquetes y no hay internet, el script falla con un
mensaje claro; en ese caso hay que usar una plantilla con Apache, MariaDB,
Flask, gunicorn y nginx ya instalados, o añadir un repositorio local. La opción
`--no-apt` evita que intente instalar nada.

## Tiempos objetivo

| Práctica | Ensayada | En examen (con cambios) |
|---|---|---|
| P2 RAID 5 | 8–10 min | 12–15 min |
| P4 VM en Proxmox | 12–15 min | 15–20 min |
| P5 pfSense | 20–25 min | 25–30 min |
| P1 Packet Tracer | 30–35 min | 35–45 min |
| P3 prestaciones | 25–30 min | 30–40 min |

## Orden recomendado

1. Clonar y ajustar `config.env` (2 min).
2. Leer el enunciado y anotar los cambios (2 min).
3. Ejecutar la práctica con los valores nuevos.
4. Comprobar lo que pide el enunciado, no lo que hacía tu memoria.

## Seguridad

Los scripts de P2 son **destructivos**: borran firmas de disco. Antes de crear
la matriz se comprueba que cada disco no está montado, no pertenece al sistema
y no tiene sistema de ficheros, y se muestra una tabla con modelo y número de
serie. Aun así, revisa la lista antes de confirmar.

`cleanup` desmonta, para la matriz y borra las firmas de los discos que se
usaron al crearla.

## Probarlo antes del examen

1. En el laboratorio, con discos que puedas borrar, ejecuta
   `./icd.sh p2 detect` y compara con lo que esperas.
2. Crea la matriz, fíjala, monta, y comprueba `cat /proc/mdstat`.
3. Repite el montaje cambiando el número de discos (por ejemplo, 4 activos sin
   repuesto) para ver qué variables hay que tocar.
4. Para P5, exporta el `config.xml` de tu pfSense y guárdalo en `p5/` antes de
   la prueba; es el artefacto que más tiempo ahorra.
