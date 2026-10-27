# OpenCode en el laboratorio — guía de uso del repositorio

Este documento es la referencia para trabajar con **OpenCode** dentro de este
repositorio. OpenCode lo lee automáticamente si se arranca desde la raíz del
proyecto. Si no lo hace, pídele explícitamente:

> Lee `AGENTS.md`, `README.md` y `docs/GUIA_EJECUCION.md` antes de responder.

## 1. Antes de abrir OpenCode

En Linux, macOS o Git Bash:

```bash
curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path
~/.opencode/bin/opencode
```

En Windows hay que usar **Git Bash**, no PowerShell ni CMD. Si no está
disponible, usa el CLI standalone o WSL.

Abre OpenCode **desde la carpeta del repositorio**, no desde `C:\` ni desde
`Documentos`:

```bash
cd /ruta/al/repositorio/Examen
~/.opencode/bin/opencode
```

Al terminar la sesión, borra OpenCode y sus datos:

```bash
rm -rf ~/.opencode ~/.config/opencode ~/.local/share/opencode ~/.cache/opencode
command -v opencode    # no debe devolver nada
```

Si en algún momento se instaló sin `--no-modify-path`, revisa también
`~/.bashrc`, `~/.zshrc` o `~/.profile` y elimina la línea del `PATH`.

## 2. Qué hay en este repositorio

El repositorio reproduce con scripts las prácticas 1–5. No sustituye al
enunciado: los valores del laboratorio se ajustan en `config.env` y en los
ficheros `.example`.

| Documento | Para qué sirve |
|---|---|
| `README.md` | Visión general, requisitos, estructura, comandos rápidos y tiempos. |
| `docs/GUIA_EJECUCION.md` | Guía paso a paso de P1–P5: dónde se ejecuta cada cosa, orden, validación y errores típicos. |
| `docs/simulacros/P4.md` | Enunciado y plan de 90 minutos para una variante de P4. |
| `p1/LEEME.md` | P1 en Packet Tracer: topología, configuración y comprobaciones manuales. |
| `p5/LEEME.md` | P5: crear la VM de pfSense, instalar, restaurar `config.xml` y ajustar interfaces. |
| `config.env.example` | Valores de laboratorio: bridges, almacenamiento, ISO, VMID, MAC, discos. |
| `p4/vms.conf.example` | Una VM de P4 por línea. |
| `p1/valores.env.example` | Redes, enlaces, servidor y dominio de P1. |

## 3. Orden de lectura recomendado

1. `README.md` — para entender qué automatiza cada práctica.
2. `docs/GUIA_EJECUCION.md` — para saber **dónde** se ejecuta cada comando.
3. El documento de la práctica que se vaya a hacer:
   - P1: `p1/LEEME.md`
   - P2 y P3: sección correspondiente de `docs/GUIA_EJECUCION.md`
   - P4: `docs/simulacros/P4.md` y `docs/GUIA_EJECUCION.md`
   - P5: `p5/LEEME.md` y `docs/GUIA_EJECUCION.md`
4. Los `.example` antes de crear la configuración local.

## 4. Reglas de trabajo para OpenCode

- **No ejecutar comandos destructivos sin confirmación expresa.** P2 borra
  firmas de disco y `cleanup` desmonta y destruye la matriz.
- **P2 y P3 van dentro de una VM Debian**, nunca en el host Proxmox ni en
  Windows.
- **P4 y P5 se crean desde el host Proxmox** con `qm`; `p4/servicios.sh` se
  ejecuta **dentro** de cada VM Debian, no en el host.
- **No inventar valores de laboratorio.** Leer `config.env`; si no existe,
  copiar `config.env.example` y preguntar antes de rellenarlo.
- **No mezclar las memorias con los scripts.** Las memorias de P4/P5 usan
  QEMU/Alpine y otro direccionamiento; los scripts usan Proxmox/Debian. Son dos
  despliegues distintos.
- **No hacer `git commit`, `git push` ni cambiar de rama** sin permiso.
- **No mostrar secretos** de `config.env`, tokens de GitHub ni contraseñas.
- **No subir** `config.env`, `p4/vms.conf`, `p1/valores.env`, `p1/out/` ni
  `p5/config.xml`: están en `.gitignore`.
- Antes de ejecutar, decir **en qué máquina** va el comando y **qué ficheros
  toca**.
- Mantener el español, el estilo de los documentos y los scripts
  parametrizados; no convertir un script en una copia fija de una práctica.

## 5. Flujo típico en el laboratorio

```bash
# 1. Descargar el repositorio (ZIP o git clone)
git clone https://github.com/Carboq/Examen.git
cd Examen

# 2. Crear la configuración local
cp config.env.example config.env
cp p1/valores.env.example p1/valores.env
cp p4/vms.conf.example p4/vms.conf

# 3. Editar los valores del laboratorio
#    bridges, storage, ISO, VMID, MAC, discos...

# 4. Comprobar la entrada común
./icd.sh --help

# 5. Consultar la ayuda de la práctica antes de ejecutarla
./icd.sh p2 help
./icd.sh p4 help
./icd.sh p5 help

# 6. Ejecutar según la práctica y la máquina
./icd.sh p1 todo
./icd.sh p2 todo sdb,sdc,sdd,sde
./icd.sh p3 todo
./icd.sh p4 todo
./icd.sh p5 todo --mac-base MAC --pc 7
```

Después:

- P1: montar la topología en Packet Tracer y pegar los ficheros de `p1/out/`.
- P2: comprobar `cat /proc/mdstat` y el montaje.
- P3: revisar la tabla de resultados de `fio`.
- P4: entrar en cada VM y ejecutar `sudo ./p4/servicios.sh web1|web2|app`.
- P5: instalar pfSense, asignar WAN/LAN/DMZ y restaurar `config.xml`.

## 6. Prompts útiles

- «Lee `AGENTS.md`, `README.md` y `docs/GUIA_EJECUCION.md`. Resume qué debo
  hacer para P4 y en qué máquina se ejecuta cada paso. No ejecutes nada.»
- «Revisa mi `config.env` y dime qué valores faltan o parecen incompatibles.
  No muestres contraseñas ni tokens.»
- «Genera los comandos de P5 con estos valores, pero no los ejecutes. Indica
  cuáles son manuales.»
- «Compara el enunciado que te pego con `docs/simulacros/P4.md` y señala las
  diferencias que hay que aplicar.»
- «Antes de ejecutar, dime si el comando es destructivo, en qué máquina va y
  cómo se revierte.»
- «No toques `git`; solo explica qué cambiarías y en qué archivo.»

## 7. Documentos que no están en GitHub

- `ICD/GUIA_MAC_Y_DESCARGA.md`: guía local de MAC, internet y descarga del
  repositorio. **No se sube al repositorio.** Si OpenCode no la encuentra, que
  lo diga y pregunte; no debe inventarse el contenido.
- `ICD/Memorias/Practica04` y `ICD/Memorias/Practica05`: memorias locales.
  Pueden consultarse como contexto, pero no forman parte de este repositorio y
  no deben subirse sin pedirlo.
- `p5/config.xml`: backup local de pfSense. Sin él, P5 no se puede restaurar;
  la instalación y el ajuste manual siguen siendo necesarios.

## 8. Limpieza al terminar

Además de borrar OpenCode:

- Cerrar sesión o revocar el token de GitHub si se usó uno.
- Borrar `config.env` y los ficheros locales con datos del laboratorio si el
  siguiente grupo va a usar el mismo equipo.
- No dejar el repositorio con cambios sin commit que no se quieran entregar.
- Comprobar que no queda ninguna credencial en el historial de la shell.
