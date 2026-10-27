# OpenCode en el laboratorio — guía de uso del repositorio

> Entorno: **VM Debian 12 + host Proxmox VE 8**, con Packet Tracer en Windows
> para la P1. No es un entorno Windows genérico.

Este documento es la referencia para trabajar con **OpenCode** dentro de este
repositorio. OpenCode lo lee automáticamente si se arranca desde la raíz del
proyecto. Si no lo hace, pídele explícitamente:

> Lee `AGENTS.md`, `README.md` y `docs/GUIA_EJECUCION.md` antes de responder.

## 0. Entorno real: Debian 12 + Proxmox VE 8

Hay que distinguir cuatro sitios:

| Sitio | Qué se ejecuta allí | ¿OpenCode? |
|---|---|---|
| VM Debian 12 de trabajo | Editar el repo, P2/P3, generar comandos y entrar por SSH en las demás máquinas. | **Sí, aquí se instala.** |
| Host Proxmox VE 8 | `qm` para crear y arrancar las VM de P4/P5. | **No recomendado.** |
| VM `web1`, `web2` y `app` | `p4/servicios.sh` dentro de cada Debian. | Opcional, por SSH. |
| Windows + Packet Tracer | P1 y edición/descarga del repo. | Solo Git Bash para generar P1. |

Proxmox VE 8 está basado en Debian, pero **no es un puesto de trabajo**: no
conviene instalar OpenCode, Python, Node ni herramientas de desarrollo en el
hipervisor. Si se instala ahí, hay que borrarlo al terminar y no dejar el
`PATH` modificado.

La VM Debian de trabajo no puede ejecutar `qm` por sí sola. Para P4/P5 hay que
entrar en el host Proxmox por SSH o copiar los comandos y ejecutarlos allí.

## 1. Antes de abrir OpenCode

En la VM Debian 12 (recomendado):

```bash
sudo apt update && sudo apt install -y curl tar
curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path
~/.opencode/bin/opencode
```

El instalador descarga desde `opencode.ai`; si la red del laboratorio filtra
por MAC, configura antes la MAC del equipo o de la VM (ver la guía local de
MAC/descarga). En el host Proxmox no se recomienda instalarlo.

Si trabajas desde Windows, usa **Git Bash** para generar P1 y editar el repo;
no uses PowerShell/CMD para los scripts de P2–P5. En Windows no hay `qm` ni
`mdadm`.

Abre OpenCode **desde la carpeta del repositorio**, no desde `/` ni desde tu
`$HOME` sin haber entrado en el proyecto:

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
- **OpenCode se instala en la VM Debian de trabajo, no en el host Proxmox.**
  El hipervisor solo debe ejecutar `qm`; si se instala allí, hay que limpiarlo.
- **P2 y P3 van dentro de una VM Debian**, nunca en el host Proxmox ni en
  Windows.
- **P4 y P5 se crean desde el host Proxmox** con `qm`; `p4/servicios.sh` se
  ejecuta **dentro** de cada VM Debian, no en el host.
- **No ejecutar `qm` en la VM Debian de trabajo.** No existe ahí: hay que entrar
  al host Proxmox por SSH o copiar el comando y ejecutarlo en el host.
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
# 1. En la VM Debian 12 de trabajo: descargar y preparar el repo
git clone https://github.com/Carboq/Examen.git
cd Examen
cp config.env.example config.env
cp p1/valores.env.example p1/valores.env
cp p4/vms.conf.example p4/vms.conf
# editar config.env: bridges, storage, ISO, VMID, MAC, discos...

# 2. Comprobar la entrada común y las ayudas
./icd.sh --help
./icd.sh p2 help
./icd.sh p4 help
./icd.sh p5 help

# 3. Prácticas que van en la VM Debian
./icd.sh p1 todo
./icd.sh p2 todo sdb,sdc,sdd,sde
./icd.sh p3 todo

# 4. P4/P5: estos comandos van en el HOST PROXMOX, no en la VM Debian
./icd.sh p4 todo
./icd.sh p5 todo --mac-base MAC --pc 7
```

Si OpenCode está en la VM Debian, para P4/P5 debe **generar los comandos y
ejecutarlos en el host Proxmox** (por SSH o copiándolos). No puede lanzar `qm`
desde la VM de trabajo.

Después:

- P1: montar la topología en Packet Tracer y pegar los ficheros de `p1/out/`.
- P2: comprobar `cat /proc/mdstat` y el montaje.
- P3: revisar la tabla de resultados de `fio`.
- P4: entrar en `web1`, `web2` y `app` y ejecutar
  `sudo ./p4/servicios.sh web1|web2|app` dentro de cada una.
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
- «Para P4/P5, separa lo que va en el host Proxmox de lo que va dentro de la VM
  Debian. No mezcles los dos entornos.»
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

## 8. Desinstalar OpenCode

Si se instaló con el script (lo normal):

```bash
rm -rf ~/.opencode
rm -rf ~/.config/opencode
rm -rf ~/.local/share/opencode
rm -rf ~/.cache/opencode
```

Comprobar que ya no queda:

```bash
command -v opencode
ls ~/.opencode 2>/dev/null
```

No debe devolver nada.

### Si el instalador modificó el PATH

Si se instaló **sin** `--no-modify-path`, el script añadió una línea al final de
`~/.bashrc`, `~/.zshrc` o `~/.profile`. Búscala con:

```bash
grep -n opencode ~/.bashrc ~/.zshrc ~/.profile
```

Elimina la línea que añade `~/.opencode/bin` al `PATH` y recarga la shell:

```bash
exec "$SHELL"
```

### Si se instaló como root

Los archivos estarán en `/root`, no en el home de `proxmox`. Hay que borrarlos
como root:

```bash
rm -rf /root/.opencode
rm -rf /root/.config/opencode
rm -rf /root/.local/share/opencode
rm -rf /root/.cache/opencode
```

### Otras formas de instalación

- **npm:** `npm uninstall -g @opencode/cli`
- **Homebrew:** `brew uninstall opencode-v2`
- **Desktop:** desinstalar desde Aplicaciones/Configuración y borrar sus datos.
- **Windows:** borrar `%USERPROFILE%\.opencode`, revisar
  `%USERPROFILE%\.config\opencode` y `%LOCALAPPDATA%\opencode`, y quitar la línea
  del `PATH` si se añadió.

### Datos y credenciales

- `~/.local/share/opencode` puede contener sesiones y credenciales. Al borrarlo
  se cierra la sesión.
- Si se usó un token de GitHub, revocarlo desde GitHub.
- Revisar si el proyecto creó configuración local:

```bash
find ~/Examen -maxdepth 2 \( -name opencode.json -o -name .opencode \) -print
```

No borres esos archivos si los quieres conservar; solo son configuración local
de OpenCode.

## 9. Limpieza del laboratorio

Además de borrar OpenCode:

- Cerrar sesión o revocar el token de GitHub si se usó uno.
- Borrar `config.env` y los ficheros locales con datos del laboratorio si el
  siguiente grupo va a usar el mismo equipo.
- No dejar el repositorio con cambios sin commit que no se quieran entregar.
- Comprobar que no queda ninguna credencial en el historial de la shell.
