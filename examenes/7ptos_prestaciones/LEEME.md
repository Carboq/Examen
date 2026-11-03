# Examen de 7 puntos — Evaluación de Prestaciones

Esta carpeta contiene el material del modelo de **7 puntos** de Evaluación de
Prestaciones: HDD, SSD, RAID 5 y benchmark con `dd`.

## Contenido

| Fichero | Qué es |
|---|---|
| `ENUNCIADO.md` | Resumen limpio de lo que pide el examen, sin credenciales. |
| `GUIA_MANUAL.md` | Guía paso a paso, con comandos para copiar y pegar. |
| `bench_dd.sh` | Banco de pruebas con `dd`; genera `lectura.csv` y `escritura.csv`. |
| `verificar.sh` | Comprueba montajes, RAID y CSV antes de entregar. |
| `20261028_EvaluacionPrestaciones_7ptos.pdf` | Enunciado oficial local. |
| `20261028_EvaluacionPrestaciones_7ptos.docx` | Documento editable para rellenar. |
| `resultados/` | Se crea al ejecutar el benchmark. |

> El PDF y el DOCX oficiales no se suben a GitHub: el documento incluye
> credenciales del laboratorio. Se copian desde el ZIP del examen o se descargan
> de Poliformat.

## Inicio rápido

Dentro de la VM Debian, con HDD, SSD y RAID ya montados:

```bash
cd Examen/examenes/7ptos_prestaciones
chmod +x bench_dd.sh verificar.sh
sudo ./verificar.sh
sudo ./bench_dd.sh --out resultados
cat resultados/resumen.txt
```

No ejecutes `bench_dd.sh` en el host Proxmox. Los discos y los montajes están
dentro de la VM.

## Guía

Lee [`GUIA_MANUAL.md`](GUIA_MANUAL.md) antes de tocar los discos. Los pasos de
`fdisk`, `mkfs` y `mdadm` son destructivos.
