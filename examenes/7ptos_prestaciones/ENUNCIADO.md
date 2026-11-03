# Evaluación de Prestaciones — modelo de 7 puntos

> Resumen de trabajo del enunciado oficial. El PDF y el DOCX originales están
> en esta misma carpeta, pero **no se suben a GitHub** porque el documento
> incluye credenciales del laboratorio. Este resumen no las reproduce.

## Qué pide el examen

- Clonar una VM Debian en Proxmox con **ID 700** y nombre
  `Debian<PrimerApellidoEstudiante>`.
- Configurar la red de la VM y activar el portapapeles.
- Mapear a la VM **cuatro SSD de 240 GB y un HDD externo de 1 TB**.
- Crear una tabla de particiones GPT nueva en los cinco discos.
- Crear tres particiones Linux RAID en las tres primeras SSD.
- Crear una partición Linux filesystem en la cuarta SSD y en el HDD.
- Formatear la cuarta SSD y el HDD en `ext4`.
- Crear un **RAID 5** con las tres particiones RAID, formatearlo en `ext4` y
  comprobarlo con `mdadm --detail`.
- Montar:
  - HDD en `/mnt/HDD`
  - SSD en `/mnt/SDD`
  - RAID en `/mnt/RAID`
- Ejecutar un benchmark con `dd` para HDD, SSD y RAID.
- Generar dos CSV:
  - `lectura.csv`
  - `escritura.csv`
- Rellenar la tabla de conclusión con el tamaño de bloque óptimo de lectura y
  escritura de cada dispositivo.
- Entregar el DOCX completado, las capturas, los dos CSV y el script del
  benchmark dentro de `<usuarioupvnet>.zip`.
- Desmontar, parar el RAID y limpiar las particiones al terminar.

## Tamaños de bloque del enunciado

1k, 2k, 4k, 8k, 16k, 32k, 64k, 128k y 256k.

Cada fichero de prueba debe ser de **1 GiB**. El enunciado escribe
`count=1048560` para 1k; es una aproximación. El script del repositorio usa
1 GiB exacto y calcula el `count` de cada tamaño de bloque.

## Formato de los CSV

Cabecera:

```text
DISPOSITIVO;BS;Tiempo;Tasa
```

Ejemplo:

```text
HDD;4k;1.234;830.25
SSD;4k;0.412;2486.10
RAID;4k;0.801;1279.40
```

## Advertencias

- **No tocar `/dev/sda`**: es el disco del sistema de la VM. Si se formatea,
  la práctica queda anulada.
- Las letras `/dev/sdb`, `/dev/sdc`, etc. pueden cambiar. Comprobar siempre
  modelo, tamaño y número de serie con `lsblk`.
- Los pasos de `fdisk`, `mkfs` y `mdadm` son **destructivos**.
- El benchmark debe ejecutarse dentro de la VM Debian, no en el host Proxmox.
- `qm` se ejecuta en el host Proxmox, no dentro de la VM.

## Material local

En esta carpeta deben estar, sin subirse al repositorio:

- `20261028_EvaluacionPrestaciones_7ptos.pdf`
- `20261028_EvaluacionPrestaciones_7ptos.docx`

La guía paso a paso está en [`GUIA_MANUAL.md`](GUIA_MANUAL.md).
