# Exámenes del primer parcial

El ZIP oficial `26_27_GIIROB-ICD.zip` contiene dos familias de examen:

| Familia | Modelos | Qué se hace |
|---|---|---|
| **Evaluación de Prestaciones** | 5, 7, 8-9 y 10 puntos | Discos reales, RAID 5, montajes y benchmark con `dd`. |
| **Infraestructura Empresarial** | 5, 6, 7, 8 y 10 puntos | Proxmox, 4 MV Debian, bridges, web, BBDD, Flask y pfSense en el 10. |

**No hay ninguna versión de Cisco Packet Tracer en ese ZIP.**

## Qué hay preparado

- [`7ptos_prestaciones/`](7ptos_prestaciones/) — **guía manual completa** del
  modelo de 7 puntos de Evaluación de Prestaciones, con el enunciado local y
  scripts de benchmark.
- [`../docs/EXAMENES.md`](../docs/EXAMENES.md) — comparación de las dos familias
  y criterios para elegir.
- [`../docs/VIDEO_DEMO.md`](../docs/VIDEO_DEMO.md) — qué grabar, incluido el
  examen de 7 puntos.
- [`../docs/CHECKLIST_EXAMEN.md`](../docs/CHECKLIST_EXAMEN.md) — lista de
  comprobación.

## Por qué está preparado el 7 de Prestaciones

Es el modelo más mecánico y fácil de reproducir con comandos: una sola VM
Debian, discos reales pasados desde Proxmox, RAID 5 y un benchmark `dd` que
genera dos CSV. No requiere crear cuatro MV ni instalar Flask/MariaDB.

## Si eliges Infraestructura Empresarial

El repositorio tiene piezas reutilizables (`p4/vms.sh`, `p5/pfsense.sh`,
`contenedores/p5/servicios.sh`), pero **no hay una guía específica** para ese
examen todavía. Los valores por defecto de P4/P5 no coinciden con el enunciado:
hay que cambiar VMID, bridges, IPs y separar BBDD de Flask.

## Material oficial

Los PDF/DOCX oficiales se copian desde el ZIP del examen. No se versionan en
GitHub los de la carpeta de 7 puntos porque el documento incluye credenciales
del laboratorio.
