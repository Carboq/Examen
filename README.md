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
│   ├── valores.env.example valores del esquema
│   └── configs/            bloques para pegar en la CLI de cada router
├── p2/raid.sh              RAID 5 con mdadm (crear, fallar, reponer)
├── p3/bench.sh             fio y tabla de resultados
├── p4/vms.sh               creación de VM en Proxmox con qm
├── p4/vms.conf.example     una VM por línea
├── p5/pfsense.sh           VM de pfSense con 3 NIC y MAC reservada
└── p5/LEEME.md             instalación, restauración y ajuste
```

## Puesta en marcha

```bash
git clone <URL> icd-examen
cd icd-examen
cp config.env.example config.env
$EDITOR config.env          # bridges, storage, VMID, MAC, discos...
```

Cada script acepta argumentos; `config.env` solo aporta los valores por
defecto. Comprueba la ayuda de cada uno:

```bash
./icd.sh p2 help
./icd.sh p5 help
```

## Qué automatiza cada práctica

| Práctica | Automático | Manual |
|---|---|---|
| P1 | bloques de configuración listos para pegar | topología, cableado, DHCP/DNS en la GUI |
| P2 | detección de discos, `mdadm`, `mkfs`, montaje, fallo y reconstrucción | mapear los discos si se hace por GUI |
| P3 | `fio` y tabla de resultados | montajes previos y lectura de resultados |
| P4 | creación de las VM con `qm` | instalación del sistema operativo |
| P5 | creación de la VM con 3 NIC y MAC reservada | instalación de pfSense, restauración y ajuste de IPs |

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
