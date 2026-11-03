# Guiones de las prácticas

Índice de los guiones oficiales de la asignatura y de las guías propias del
repositorio.

> Los PDFs son material docente de la asignatura. Se incluyen para uso
> académico; los derechos pertenecen a sus autores. No se publican credenciales
> de acceso al host Proxmox ni datos personales.

## Prácticas

| Práctica | Guion oficial | Guía del repositorio |
|---|---|---|
| P1 — Packet Tracer | [Guion_Practica01_PacketTracer.pdf](guiones/Guion_Practica01_PacketTracer.pdf) | [GUIA_EJECUCION.md](GUIA_EJECUCION.md) y [p1/LEEME.md](../p1/LEEME.md) |
| P2 — RAID 5 | [Guion_Practica02_RAID.pdf](guiones/Guion_Practica02_RAID.pdf) | [GUIA_EJECUCION.md](GUIA_EJECUCION.md) y [p2/](../p2/) |
| P3 — Prestaciones de discos | [Guion_Practica03_PrestacionesDiscos.pdf](guiones/Guion_Practica03_PrestacionesDiscos.pdf) | [GUIA_EJECUCION.md](GUIA_EJECUCION.md) y [p3/](../p3/) |
| P4 — Máquinas virtuales | [Guion_Practica04_MaquinasVirtuales.pdf](guiones/Guion_Practica04_MaquinasVirtuales.pdf) | [GUIA_EJECUCION.md](GUIA_EJECUCION.md) y [simulacros/P4.md](simulacros/P4.md) |
| P5 — pfSense | [Guion_Practica05_pfSense.pdf](guiones/Guion_Practica05_pfSense.pdf) | [GUIA_EJECUCION.md](GUIA_EJECUCION.md) y [p5/LEEME.md](../p5/LEEME.md) |

## Exámenes del primer parcial

| Examen | Enunciado | Guía preparada |
|---|---|---|
| Evaluación de Prestaciones 7 | `examenes/7ptos_prestaciones/20261028_EvaluacionPrestaciones_7ptos.pdf` y `.docx` (local) | [GUIA_MANUAL.md](../examenes/7ptos_prestaciones/GUIA_MANUAL.md) |
| Infraestructura Empresarial 5–10 | ZIP oficial del examen | Sin guía específica; ver [EXAMENES.md](EXAMENES.md) |
| Modelo 00 resuelto | `examenes/modelos/20261020_PrimerParcialLaboratorio_modelo00.docx` | [LEEME.md](../examenes/modelos/LEEME.md) |

> El ZIP oficial del examen **no contiene Packet Tracer**. La P1 del
> repositorio no se usa en estos modelos.

## Documentos de apoyo

- [Guía comparativa de los modelos de examen](EXAMENES.md).
- [Crear una VM en Proxmox VE y conectarla a la red](CREAR_VM_PROXMOX.md).
- [Guía de ejecución de las cinco prácticas](GUIA_EJECUCION.md).
- [Entorno real: VM Debian sobre Proxmox y discos reales](ENTORNO_EXAMEN.md).
- [Contenedores LXC para P4 y P5](CONTENEDORES.md).
- [Guion para grabar la demostración](VIDEO_DEMO.md).
- [Lista de comprobación para el examen](CHECKLIST_EXAMEN.md).
- [Simulacro de P4](simulacros/P4.md).
- [README del repositorio](../README.md).

## Aviso

Antes de ejecutar cualquier script, lee el guion oficial y el enunciado del
profesor. Los valores de este repositorio son puntos de partida: si cambian una
IP, un VMID, una MAC o un disco, se ajusta en `config.env` o en el fichero
correspondiente.
