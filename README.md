# ICD — Repositorio de examen

Apoyo para el parcial de laboratorio de **Infraestructura Informática para
Centros de Datos** (UPV). Reproduce con scripts los montajes de las prácticas
1 a 5 y deja a la vista lo que sigue siendo manual.

> El parcial se hace «con algún cambio». Los valores de este repositorio son
> puntos de partida: lee el enunciado, ajusta `config.env` y revisa la lista de
> discos antes de ejecutar nada.

## Mapa rápido

| Quiero... | Fichero |
|---|---|
| Instalar y usar OpenCode | [`AGENTS.md`](AGENTS.md), sección 1; en el USB, `OPENCODE/LEEME.md` |
| Ver qué examen elegir | [`docs/EXAMENES.md`](docs/EXAMENES.md) |
| Hacer el examen de 7 puntos paso a paso | [`examenes/7ptos_prestaciones/GUIA_MANUAL.md`](examenes/7ptos_prestaciones/GUIA_MANUAL.md) |
| Ver el enunciado resumido del 7 | [`examenes/7ptos_prestaciones/ENUNCIADO.md`](examenes/7ptos_prestaciones/ENUNCIADO.md) |
| Ejecutar el benchmark del 7 | [`examenes/7ptos_prestaciones/bench_dd.sh`](examenes/7ptos_prestaciones/bench_dd.sh) |
| Repasar el modelo 00 resuelto | [`examenes/modelos/20261020_PrimerParcialLaboratorio_modelo00.docx`](examenes/modelos/20261020_PrimerParcialLaboratorio_modelo00.docx) |
| Grabar la demostración | [`docs/VIDEO_DEMO.md`](docs/VIDEO_DEMO.md) |
| Revisar antes de entregar | [`docs/CHECKLIST_EXAMEN.md`](docs/CHECKLIST_EXAMEN.md) |
| Ver el entorno real | [`docs/ENTORNO_EXAMEN.md`](docs/ENTORNO_EXAMEN.md) |

## Requisitos

- **Proxmox VE 8** en el host, para P4 y P5.
- **Debian 12** dentro de la MV, para P2 y P3.
- **pfSense 2.7** para P5.
- `bash`, `lsblk`, `mdadm`, `wipefs` (P2); `fio` (P3); `dd` (examen de 7
  puntos); `qm` (P4/P5).
- Para los contenedores: `pct`, `pveam` y una plantilla Debian 12.
- Los discos de P2/P3 son **discos reales** conectados a la VM; ver
  [`docs/ENTORNO_EXAMEN.md`](docs/ENTORNO_EXAMEN.md).

## Estructura

```
icd-examen/
├── icd.sh                  entrada única: ./icd.sh p2 ...
├── AGENTS.md               guía de OpenCode en el laboratorio
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
├── examenes/               material de los exámenes del primer parcial
│   ├── README.md           índice y comparación de modelos
│   ├── 7ptos_prestaciones/ guía manual, enunciado y benchmark del 7
│   └── modelos/            modelos resueltos, incluido el modelo 00
├── contenedores/           LXC de Proxmox para P4 y P5
│   ├── lib.sh              funciones comunes
│   ├── p4/lxc.sh           web1, web2 y app en LXC
│   └── p5/                 servidores de apoyo de pfSense en LXC
├── tools/                  utilidades para preparar la entrega
│   └── crear_entrega_usb.ps1
├── docs/GUIONES.md         índice de los guiones oficiales
├── docs/EXAMENES.md        guía comparativa de los modelos de examen
├── docs/guiones/           PDFs oficiales de las prácticas 1–5
├── docs/GUIA_EJECUCION.md   guía paso a paso de las cinco prácticas
├── docs/CREAR_VM_PROXMOX.md crear una VM y conectarla a la red
├── docs/ENTORNO_EXAMEN.md  VM Debian, Proxmox y discos reales
├── docs/CONTENEDORES.md    LXC de P4 y P5, con pfSense como VM
├── docs/VIDEO_DEMO.md      guion para grabar la demostración
├── docs/CHECKLIST_EXAMEN.md lista de comprobación
└── docs/simulacros/P4.md   enunciado y guía del simulacro de la P4
```

## Puesta en marcha

```bash
git clone https://github.com/Carboq/Examen.git
cd Examen
cp config.env.example config.env
$EDITOR config.env          # bridges, storage, VMID, MAC, discos...
```

El repo es público: puedes clonarlo o descargar el ZIP desde la web
(**Code → Download ZIP**). También puedes llevarlo preparado en un USB; la
carpeta de entrega se genera con `tools/crear_entrega_usb.ps1` y contiene el
repositorio, los PDFs, la guía de OpenCode, el guion del vídeo y los scripts de
contenedores.

Si necesitas crear la VM desde cero, cambiar su bridge o arreglar la salida a
internet, consulta [`docs/CREAR_VM_PROXMOX.md`](docs/CREAR_VM_PROXMOX.md):
incluye el asistente de la GUI, los comandos `qm`, la MAC, el DHCP y las
comprobaciones dentro de Debian.

Los ficheros con datos del laboratorio no se suben al repositorio:
`config.env`, `p4/vms.conf`, `p1/valores.env`, `p1/out/` y `p5/config.xml`.
En una copia nueva hay que crearlos a partir de los `.example`.

Cada script acepta argumentos; `config.env` solo aporta los valores por
defecto. Comprueba la ayuda de cada uno:

```bash
./icd.sh p2 help
./icd.sh p5 help
```

## Guiones de las prácticas

Los guiones oficiales en PDF de P1–P5 están en
[`docs/GUIONES.md`](docs/GUIONES.md), con enlaces al PDF y a la guía del
repositorio de cada práctica. Son material docente: se incluyen para uso
académico y no se publican credenciales del host Proxmox.

## Exámenes del primer parcial

El ZIP oficial del examen **no contiene Packet Tracer**. Tiene dos familias:
Evaluación de Prestaciones e Infraestructura Empresarial. La comparación está
en [`docs/EXAMENES.md`](docs/EXAMENES.md).

El modelo preparado es **Evaluación de Prestaciones de 7 puntos**:

- [`examenes/7ptos_prestaciones/LEEME.md`](examenes/7ptos_prestaciones/LEEME.md)
- [`examenes/7ptos_prestaciones/GUIA_MANUAL.md`](examenes/7ptos_prestaciones/GUIA_MANUAL.md)
- [`examenes/7ptos_prestaciones/ENUNCIADO.md`](examenes/7ptos_prestaciones/ENUNCIADO.md)

Dentro de la VM Debian, con HDD, SSD y RAID montados:

```bash
cd Examen/examenes/7ptos_prestaciones
chmod +x bench_dd.sh verificar.sh
sudo ./verificar.sh
sudo ./bench_dd.sh --out resultados
cat resultados/resumen.txt
```

El PDF y el DOCX oficiales se guardan en esa carpeta en local, pero no se
suben a GitHub: el documento incluye credenciales del laboratorio.

## OpenCode

La guía para instalar y usar OpenCode en el laboratorio está en
[`AGENTS.md`](AGENTS.md). OpenCode la lee automáticamente al arrancar desde la
raíz del repositorio. Incluye la instalación sin root, la limpieza y las reglas
para no mezclar el host Proxmox con las VM Debian.

```bash
curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path
cd /ruta/al/repositorio/Examen
~/.opencode/bin/opencode
```

Si no lee el archivo solo, pídele: «Lee `AGENTS.md`, `README.md` y
`docs/GUIA_EJECUCION.md` antes de responder».

Para desinstalarlo y borrar sus datos, sigue el apartado **8. Desinstalar
OpenCode** de [`AGENTS.md`](AGENTS.md#8-desinstalar-opencode).

## Entrega en USB

La carpeta de entrega se genera desde el repositorio y se puede copiar a un USB.
En Windows, desde la raíz del repo:

```powershell
powershell -ExecutionPolicy Bypass -File tools/crear_entrega_usb.ps1
```

Crea `Entrega_Examen_USB/` y `Entrega_Examen_USB.zip` en la carpeta padre del
repositorio. Incluye:

- el repositorio completo (sin `.git`, sin `config.env` y sin datos locales);
- los PDFs oficiales de `docs/guiones/`;
- la guía de OpenCode;
- el guion del vídeo;
- la documentación de discos reales y contenedores;
- la carpeta `EXAMENES` con la guía manual, el enunciado y los scripts del
  examen de 7 puntos;
- una lista de comprobación para el examen.

El USB no sustituye a GitHub: si cambias algo, vuelve a generar la carpeta.

## Ejecución rápida

| Práctica | Comando | Dónde |
|---|---|---|
| P1 | `./icd.sh p1 todo` | PC con Git Bash o VM Linux (Packet Tracer aparte) |
| P2 | `./icd.sh p2 todo sdb,sdc,sdd,sde` | VM Debian con los discos |
| P3 | `./icd.sh p3 todo` | VM Debian con la matriz montada |
| P4 | `./icd.sh p4 todo` | host Proxmox |
| P4 servicios | `sudo ./p4/servicios.sh web1` | dentro de cada VM Debian |
| P4 LXC | `./icd.sh p4 lxc create` | host Proxmox |
| P5 | `./icd.sh p5 todo --mac-base MAC --pc 7` | host Proxmox |
| P5 LXC | `./icd.sh p5 lxc create` | host Proxmox (pfSense sigue siendo VM) |

La guía completa, con el orden, las comprobaciones y los errores típicos, está
en [`docs/GUIA_EJECUCION.md`](docs/GUIA_EJECUCION.md). Para el entorno real y
los discos, consulta [`docs/ENTORNO_EXAMEN.md`](docs/ENTORNO_EXAMEN.md); para
los contenedores, [`docs/CONTENEDORES.md`](docs/CONTENEDORES.md); para grabar
la demostración, [`docs/VIDEO_DEMO.md`](docs/VIDEO_DEMO.md); para el examen de
7 puntos, [`examenes/7ptos_prestaciones/GUIA_MANUAL.md`](examenes/7ptos_prestaciones/GUIA_MANUAL.md)
y [`docs/EXAMENES.md`](docs/EXAMENES.md).

## Qué automatiza cada práctica

| Práctica | Automático | Manual |
|---|---|---|
| P1 | bloques de configuración listos para pegar | topología, cableado, DHCP/DNS en la GUI |
| P2 | detección de discos, `mdadm`, `mkfs`, montaje, fallo y reconstrucción | mapear los discos si se hace por GUI |
| P3 | `fio` y tabla de resultados | montajes previos y lectura de resultados |
| P4 | creación de VM con `qm` o LXC con `pct` y configuración de Apache, MariaDB, Flask y nginx | instalar Debian o elegir la plantilla LXC |
| P5 | creación de la VM pfSense con 3 NIC y MAC reservada; LXC de apoyo para los servidores | instalación de pfSense, restauración y ajuste de IPs y reglas |

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

### P4 con contenedores LXC

Si el profesor permite contenedores, en el host Proxmox:

```bash
./icd.sh p4 lxc create
```

Crea `web1`, `web2` y `app` como LXC Debian 12, cada uno con su IP en `vmbr1`,
y ejecuta `p4/servicios.sh` dentro de cada uno. No hace falta instalar Debian ni
clonar plantillas. La guía y las variables están en
[`docs/CONTENEDORES.md`](docs/CONTENEDORES.md).

## Tiempos objetivo

| Práctica | Ensayada | En examen (con cambios) |
|---|---|---|
| P2 RAID 5 | 8–10 min | 12–15 min |
| P4 VM en Proxmox | 12–15 min | 15–20 min |
| P5 pfSense | 20–25 min | 25–30 min |
| P1 Packet Tracer | 30–35 min | 35–45 min |
| P3 prestaciones | 25–30 min | 30–40 min |
| Examen 7 Prestaciones | 45–60 min | 60–75 min |

## Orden recomendado

1. Clonar y ajustar `config.env` (2 min).
2. Leer el enunciado y anotar los cambios (2 min).
3. Ejecutar la práctica con los valores nuevos.
4. Comprobar lo que pide el enunciado, no lo que hacía tu memoria.

## Seguridad

Los scripts de P2 son **destructivos**: borran firmas de disco. Antes de crear
la matriz se comprueba que cada disco es un disco completo, no es el disco del
sistema, no está montado, no pertenece a otra matriz y no tiene sistema de
ficheros, y se muestra una tabla con modelo y número de serie. Aun así, revisa
la lista antes de confirmar.

En el examen los discos son reales y se conectan a la VM desde Proxmox. Lee
[`docs/ENTORNO_EXAMEN.md`](docs/ENTORNO_EXAMEN.md) antes de tocar `qm set` o
`./icd.sh p2 create`.

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
5. Si vas a usar LXC, descarga la plantilla Debian 12 y prueba
   `./icd.sh p4 lxc create` con IDs que no choquen con otras VM.
