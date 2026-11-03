# Guía de exámenes del primer parcial

> **No hay Packet Tracer en el ZIP oficial del examen.** El ZIP contiene dos
> familias: Evaluación de Prestaciones e Infraestructura Empresarial.

## 1. Qué contiene el ZIP oficial

| Familia | Versiones | Dónde se ejecuta |
|---|---|---|
| **Evaluación de Prestaciones** | 5, 7, 8-9 y 10 puntos | VM Debian clonada en Proxmox, con discos reales. |
| **Infraestructura Empresarial** | 5, 6, 7, 8 y 10 puntos | Host Proxmox: 4 MV Debian; pfSense solo en el 10. |

Documentos incluidos en el ZIP:

- `InstruccionesPrimerParcial.pdf`
- `TurnosPrimerParcialPracticasGIIROBICDResumen.pdf`
- `EvaluacionPrestaciones/20261028_..._{5,7,8_9,10}_ptos.{pdf,docx}`
- `InfraestructuraEmpresarial/20261101_Infraestructura_{5,6,7,8,10}ptos.{pdf,docx}`

## 2. Qué está preparado en el repositorio

**Modelo preparado:** Evaluación de Prestaciones, **7 puntos**.

Es el más mecánico: una VM, discos reales, RAID 5 y un benchmark `dd`. La guía
completa está en:

- [`examenes/7ptos_prestaciones/GUIA_MANUAL.md`](../examenes/7ptos_prestaciones/GUIA_MANUAL.md)
- [`examenes/7ptos_prestaciones/ENUNCIADO.md`](../examenes/7ptos_prestaciones/ENUNCIADO.md)
- [`examenes/7ptos_prestaciones/LEEME.md`](../examenes/7ptos_prestaciones/LEEME.md)

Scripts:

- `bench_dd.sh`: benchmark con `dd`, genera `lectura.csv` y `escritura.csv`.
- `verificar.sh`: comprueba montajes, RAID y CSV.

## 3. Comparación con las prácticas P1–P5

| Examen | Piezas reutilizables | Diferencias importantes |
|---|---|---|
| Prestaciones 7 | `p2/raid.sh` (solo como referencia), `p3/` | El examen exige **particiones**, no discos completos; `raid.sh` rechaza particiones. El benchmark es con **`dd`**, no con `fio`. |
| Infraestructura 5–8 | `p4/vms.sh`, `p4/servicios.sh` | El examen pide 4 MV con IDs 300/400/500/600; la carpeta usa 3 MV y un `app` que mezcla BBDD y Flask. |
| Infraestructura 10 | `p5/pfsense.sh` | Hay que cambiar bridges a `vmbrintra`/`vmbrdmz` y las IPs. |

## 4. Ruta recomendada para el 7 de Prestaciones

1. Clonar la VM Debian con ID 700 y nombre `Debian<Apellido>`.
2. Configurar MAC del anexo y activar `spice-vdagent`.
3. Mapear 4 SSD y el HDD desde el host Proxmox.
4. Crear GPT y particiones:
   - 3 SSD: partición Linux RAID.
   - 4.ª SSD y HDD: partición Linux filesystem.
5. Formatear SSD y HDD en `ext4`.
6. Crear RAID 5 `/dev/md0` con las tres particiones RAID.
7. Montar `/mnt/HDD`, `/mnt/SDD` y `/mnt/RAID`.
8. Ejecutar `bench_dd.sh`.
9. Rellenar el DOCX, juntar capturas y CSV, y crear el ZIP.
10. Desmontar, parar el RAID y limpiar.

La guía detallada, con comandos para copiar y pegar, está en
[`examenes/7ptos_prestaciones/GUIA_MANUAL.md`](../examenes/7ptos_prestaciones/GUIA_MANUAL.md).

## 5. Si eliges Infraestructura Empresarial

No hay guía específica todavía. Lo que hay que cambiar respecto a la carpeta
actual:

- Crear 4 MV con IDs 300, 400, 500 y 600.
- Bridges `vmbrintra` (192.168.50.0/24) y `vmbrdmz` (192.168.25.0/24).
- Web DMZ en 300, web intranet en 400, BBDD en 500, Flask en 600.
- Separar BBDD y Flask; `p4/servicios.sh app` las mezcla.
- pfSense solo para el modelo de 10 puntos; 3 NIC, WAN con internet, DMZ e
  intranet.
- La entrega es un DOCX/OpenOffice con capturas, no solo scripts.

## 6. Packet Tracer

No aparece en ninguna versión del ZIP. La P1 del repositorio sigue siendo útil
para la asignatura, pero no para este examen.
