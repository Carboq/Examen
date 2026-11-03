# Modelos de examen resueltos

## `20261020_PrimerParcialLaboratorio_modelo00.docx`

Documento de apoyo con **10 preguntas de desarrollo** sobre comandos de Debian
13 (Trixie): discos, `lsblk`, `qm set`, `fdisk`, `mkfs`, `mdadm`, montajes y
limpieza de RAID.

Incluye respuestas escritas. No es el examen práctico de 7 puntos: es material
de estudio para la primera parte y para repasar los comandos que también se
usan en la parte práctica.

> Revisa siempre los comandos antes de usarlos. Algunas respuestas del documento
> son abreviadas o tienen erratas; la guía fiable para el examen de 7 puntos es
> [`../7ptos_prestaciones/GUIA_MANUAL.md`](../7ptos_prestaciones/GUIA_MANUAL.md).

## Relación con el examen de 7 puntos

Sirve para repasar:

- `lsblk` y `/dev/disk/by-id`.
- `qm set` para mapear discos.
- `fdisk` con GPT.
- `mkfs.ext4`.
- `mdadm` con RAID 5 y repuesto.
- `cat /proc/mdstat`.
- Montaje en `/mnt/RAID` y `/mnt/HDD`.
- Limpieza con `umount`, `mdadm --stop` y `wipefs`.

La diferencia principal: el modelo 00 es teórico y el examen de 7 puntos es
práctico con discos reales y benchmark `dd`.
