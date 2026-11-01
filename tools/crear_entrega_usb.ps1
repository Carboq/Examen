param(
    [string]$Destino = "",
    [string]$Git = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$Repo = Split-Path -Parent $PSScriptRoot
$Base = Split-Path -Parent $Repo

if ([string]::IsNullOrWhiteSpace($Destino)) {
    $Destino = Join-Path $Base "Entrega_Examen_USB"
}
$Zip = "$Destino.zip"

if (Test-Path $Destino) {
    if (-not $Force) {
        throw "Ya existe $Destino. Usa -Force para regenerarla."
    }
    Remove-Item -LiteralPath $Destino -Recurse -Force
}
if (Test-Path $Zip) {
    Remove-Item -LiteralPath $Zip -Force
}

if ([string]::IsNullOrWhiteSpace($Git)) {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd) {
        $Git = $cmd.Source
    } else {
        $candidato = "C:\Users\carle\AppData\Local\GitHubDesktop\app-3.6.9\resources\app\git\cmd\git.exe"
        if (Test-Path $candidato) {
            $Git = $candidato
        } else {
            throw "No encuentro git. Instala Git o pasa -Git <ruta>."
        }
    }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("icd-usb-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null
$tmpZip = Join-Path $tmp "repo.zip"

try {
    Write-Host "Exportando el repositorio desde HEAD..."
    $status = & $Git -C $Repo status --porcelain
    if ($status) {
        Write-Warning "Hay cambios sin commit. El USB se genera desde HEAD, no desde el working tree."
    }
    & $Git -C $Repo archive --format=zip -o $tmpZip HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "git archive ha fallado."
    }

    $repoCopy = Join-Path $Destino "REPOSITORIO"
    New-Item -ItemType Directory -Path $repoCopy -Force | Out-Null
    Expand-Archive -LiteralPath $tmpZip -DestinationPath $repoCopy -Force

    foreach ($d in @("GUIAS_PDF", "OPENCODE", "VIDEO", "CONTENEDORES", "ANEXOS", "P5_CONFIG")) {
        New-Item -ItemType Directory -Path (Join-Path $Destino $d) -Force | Out-Null
    }

    Copy-Item -Path (Join-Path $Repo "docs\guiones\*.pdf") -Destination (Join-Path $Destino "GUIAS_PDF") -Force
    Copy-Item -Path (Join-Path $Repo "AGENTS.md") -Destination (Join-Path $Destino "OPENCODE\AGENTS.md") -Force
    Copy-Item -Path (Join-Path $Repo "docs\VIDEO_DEMO.md") -Destination (Join-Path $Destino "VIDEO\GUION_VIDEO.md") -Force
    Copy-Item -Path (Join-Path $Repo "docs\CONTENEDORES.md") -Destination (Join-Path $Destino "CONTENEDORES\LEEME_CONTENEDORES.md") -Force
    Copy-Item -Path (Join-Path $Repo "docs\ENTORNO_EXAMEN.md") -Destination (Join-Path $Destino "ANEXOS\ENTORNO_EXAMEN.md") -Force
    Copy-Item -Path (Join-Path $Repo "docs\CHECKLIST_EXAMEN.md") -Destination (Join-Path $Destino "CHECKLIST_EXAMEN.md") -Force
    Copy-Item -Path (Join-Path $Repo "contenedores\*") -Destination (Join-Path $Destino "CONTENEDORES") -Recurse -Force

    $p5cfg = Join-Path $Repo "p5\config.xml"
    if (Test-Path $p5cfg) {
        Copy-Item -Path $p5cfg -Destination (Join-Path $Destino "P5_CONFIG\config.xml") -Force
    } else {
        $aviso = @'
# P5_CONFIG

No se ha encontrado `p5/config.xml` en el repositorio.

Antes de ir al examen:

1. Entra en tu pfSense.
2. Diagnostics → Backup & Restore → Backup.
3. Guarda el `config.xml` en esta carpeta.

No subas este archivo a GitHub: contiene configuración y posibles credenciales.
'@
        [System.IO.File]::WriteAllText(
            (Join-Path $Destino "P5_CONFIG\LEEME.txt"),
            $aviso,
            ([System.Text.UTF8Encoding]::new($false))
        )
    }

    $leeme = @'
# Entrega ICD — carpeta para el USB

Esta carpeta está pensada para copiarse a un USB y llevarla al examen. No
sustituye al repositorio de GitHub: es una copia de apoyo.

## Contenido

| Carpeta | Qué hay |
|---|---|
| `REPOSITORIO/` | Copia del repositorio (sin `.git` ni datos locales). |
| `GUIAS_PDF/` | Guiones oficiales de P1–P5. |
| `OPENCODE/` | Guía de instalación, uso y desinstalación de OpenCode. |
| `VIDEO/` | Guion para grabar la demostración. |
| `CONTENEDORES/` | Guía y scripts LXC de P4 y P5. |
| `ANEXOS/` | Entorno real y discos reales. |
| `P5_CONFIG/` | Sitio para guardar el `config.xml` de pfSense. |
| `CHECKLIST_EXAMEN.md` | Lista de comprobación antes/durante/después. |

## Primeros pasos

1. Copia esta carpeta al USB.
2. En la VM Debian, copia `REPOSITORIO/` a tu home.
3. Crea la configuración local:

   ```bash
   cd REPOSITORIO
   cp config.env.example config.env
   cp p1/valores.env.example p1/valores.env
   cp p4/vms.conf.example p4/vms.conf
   ```

4. Edita `config.env` con los valores del enunciado.
5. Lee `docs/GUIA_EJECUCION.md` y `docs/ENTORNO_EXAMEN.md`.
6. Si vas a usar LXC, descarga la plantilla Debian 12 y sigue
   `docs/CONTENEDORES.md`.
7. Para el vídeo, sigue `VIDEO/GUION_VIDEO.md`.

## Avisos

- `config.env`, `p4/vms.conf`, `p1/valores.env`, `p1/out/` y
  `p5/config.xml` no están en GitHub. Cópialos de los `.example` o expórtalos
  antes del examen.
- `P5_CONFIG/config.xml` puede contener credenciales. No lo subas a GitHub ni lo
  dejes en un equipo compartido.
- Los scripts de P2 son destructivos. Revisa los discos antes de ejecutar.
- `pct` y `qm` se ejecutan en el host Proxmox, no dentro de la VM Debian.
- pfSense es una VM, no un contenedor LXC.

## Regenerar la carpeta

Desde el repositorio, en Windows:

```powershell
powershell -ExecutionPolicy Bypass -File tools/crear_entrega_usb.ps1 -Force
```
'@
    [System.IO.File]::WriteAllText(
        (Join-Path $Destino "LEEME_PRIMERO.md"),
        $leeme,
        ([System.Text.UTF8Encoding]::new($false))
    )

    $openCode = @'
# OpenCode para el examen

La guía completa está en `AGENTS.md`, en esta misma carpeta.

## Instalar en la VM Debian

```bash
sudo apt update && sudo apt install -y curl tar
curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path
~/.opencode/bin/opencode
```

Abre OpenCode desde la carpeta del repositorio:

```bash
cd /ruta/al/repositorio/Examen
~/.opencode/bin/opencode
```

## Desinstalar

```bash
rm -rf ~/.opencode ~/.config/opencode ~/.local/share/opencode ~/.cache/opencode
```

Si el instalador modificó el `PATH`, revisa `~/.bashrc`, `~/.zshrc` o
`~/.profile` y elimina la línea de OpenCode.

No instales OpenCode en el host Proxmox si puedes evitarlo.
'@
    [System.IO.File]::WriteAllText(
        (Join-Path $Destino "OPENCODE\LEEME.md"),
        $openCode,
        ([System.Text.UTF8Encoding]::new($false))
    )

    Write-Host "Comprimiendo la entrega..."
    Compress-Archive -Path (Join-Path $Destino "*") -DestinationPath $Zip -Force

    $size = (Get-ChildItem -LiteralPath $Destino -Recurse -File | Measure-Object -Property Length -Sum).Sum
    Write-Host ""
    Write-Host "Carpeta: $Destino"
    Write-Host "ZIP:     $Zip"
    Write-Host ("Tamaño:  {0:N1} MB" -f ($size / 1MB))
    Write-Host "Copia la carpeta o el ZIP al USB."
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
