# Contenedores LXC

Scripts para crear los contenedores de P4 y P5 en el **host Proxmox**.

| Archivo | Para qué |
|---|---|
| `lib.sh` | Funciones comunes: comprobar plantilla, crear, arrancar, copiar scripts y destruir. |
| `p4/lxc.sh` | Crea `web1`, `web2` y `app` y ejecuta `p4/servicios.sh`. |
| `p5/lxc.sh` | Crea `dmz-web`, `intra-web`, `db` y `app` y ejecuta `p5/servicios.sh`. |
| `p5/servicios.sh` | Configura Apache, MariaDB, Flask y nginx dentro de los LXC de P5. |

## Orden

```bash
# En el host Proxmox
pveam update
pveam available --section system | grep debian-12
pveam download local debian-12-standard_12.7-1_amd64.tar.zst

# P4
./icd.sh p4 lxc create
./icd.sh p4 lxc status

# P5: primero la VM de pfSense, después los LXC de apoyo
./icd.sh p5 todo --mac-base <MAC> --pc <PC>
./icd.sh p5 lxc create
./icd.sh p5 lxc status
```

pfSense **no** se puede crear con LXC. Sigue siendo una VM FreeBSD.

La guía completa, con tablas de IPs, variables y solución de problemas, está en
[`docs/CONTENEDORES.md`](../docs/CONTENEDORES.md).

> Los scripts se ejecutan en el host Proxmox con `pct`. No los ejecutes dentro
> de la VM Debian: allí no existe `pct`.
