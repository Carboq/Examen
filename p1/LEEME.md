# P1 — Packet Tracer

En P1 no hay automatización externa posible: Packet Tracer no expone una API
para crear el `.pkt` desde fuera. Lo que sí se puede automatizar es el **texto
de configuración**: los bloques de `configs/` se pegan en la pestaña CLI de cada
router y solo hay que cambiar las direcciones.

## Qué te dan y qué decides tú

El profesor entrega un **esquema** con los segmentos, los componentes, los
nombres y las IPs. Tú decides el procedimiento; lo que se evalúa es que la red
funcione, no que sea idéntica a la de la memoria. Por eso el montaje se apoya
en dos decisiones que sirven para cualquier esquema:

- **RIPv2** en lugar de rutas estáticas (se adapta a cualquier número de redes).
- **Un único servidor** con DHCP y DNS, y `ip helper-address` en los routers.

## 1. Antes de tocar Packet Tracer (5 min)

Rellena la tabla con el esquema del enunciado:

| Red | Segmento | Gateway | Servidor DHCP/DNS | Equipos |
|---|---|---|---|---|
| Red 1 | 192.168.___.0/24 | 192.168.___.1 | | |
| Red 2 | | | | |
| Red 3 | | | | |
| Red 4 | | | | |
| Red 5 | | | | |
| Enlace R1–R2 | 10.0.___.0/30 | | | |
| Enlace R2–R3 | 10.0.___.0/30 | | | |
| Enlace R3–R4 | 10.0.___.0/30 | | | |

Regla de oro: **cada router tiene tres puertos** (2911). Reparte:

- R1: dos LAN + un enlace.
- R2 y R3: una LAN + dos enlaces.
- R4: una LAN + un enlace.

## 2. Montaje (10 min)

1. Coloca 4 routers 2911, un switch 2960 por segmento, el servidor y los PCs.
2. Cablea con **cobre recto**: router ↔ switch, switch ↔ PC/servidor.
3. Renombra: `R1`–`R4`, `Switch0`–`Switch4`, `Server0`, `pc0`–`pcN`.
4. Comprueba que los enlaces router–router son GigabitEthernet (no serie).

## 3. Configuración (15 min)

Abre la CLI de cada router y pega su bloque de `configs/`, cambiando los
valores entre `{{ }}` por los de tu tabla.

| Fichero | Router |
|---|---|
| `configs/R1.txt` | dos LAN + enlace |
| `configs/R2.txt` | una LAN + dos enlaces |
| `configs/R3.txt` | una LAN + dos enlaces |
| `configs/R4.txt` | una LAN + un enlace |

Al final de cada bloque: `end` y `write memory`.

### Generarlas de una vez

En lugar de editar los cuatro ficheros a mano:

```bash
cp p1/valores.env.example p1/valores.env
$EDITOR p1/valores.env        # pon los valores del esquema
p1/generar.sh                 # escribe p1/out/R1.txt ... R4.txt
```

`generar.sh` sustituye todos los `{{ }}` y avisa si queda alguno sin valor.
Los ficheros de `p1/out/` son los que se pegan en Packet Tracer.

## 4. Servidor (10 min)

En `Server0` → pestaña **Services**:

1. **DHCP**: un *pool* por cada Red, con:
   - Gateway = IP del router en esa red.
   - DNS Server = IP del servidor.
   - Start IP = primera dirección libre (por ejemplo `.10`).
   - Subnet Mask = `255.255.255.0`.
   - Máximo de usuarios = 50 (o el que pida el enunciado).
2. **DNS**: activar el servicio y añadir un registro **A** por equipo:
   `pcN.dominio` → IP del equipo, y `servidor.dominio` → IP del servidor.

## 5. Verificación (5 min)

- `ping` desde un PC de cada red a un PC de cada una de las otras.
- `ipconfig /release` y `/renew` en un PC: debe recibir IP del pool correcto.
- `nslookup pcX.dominio`: debe resolver.
- `show ip route` en cada router: rutas `R` aprendidas por RIP.

## Errores típicos

- **Olvidar `no auto-summary`**: RIPv2 anuncia redes agregadas y el tráfico
  entre redes no vuelve.
- **Faltar `ip helper-address`**: los PCs de otras redes no obtienen IP.
- **Poner el helper con la IP del gateway** en vez de la del servidor.
- **DNS Server del pool vacío**: los equipos obtienen IP pero no resuelven.
- **Cable serie donde toca GigabitEthernet**: la interfaz no levanta.
- **No guardar** (`write memory`): al cerrar el `.pkt` se pierde.
