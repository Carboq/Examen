# Lista de comprobación para el examen

> Úsala la noche anterior y otra vez al llegar al laboratorio. Si algo falla,
> no improvises: revisa primero el enunciado y los documentos enlazados.

## 1. La noche anterior

- [ ] El repositorio está actualizado en GitHub y en el USB.
- [ ] El USB contiene `REPOSITORIO`, `GUIAS_PDF`, `OPENCODE`, `VIDEO` y
  `CONTENEDORES`.
- [ ] `config.env.example` está revisado; no se ha subido `config.env`.
- [ ] `p4/vms.conf.example` y `p1/valores.env.example` están revisados.
- [ ] Has exportado `p5/config.xml` de tu pfSense y lo has guardado en el USB
  (fuera de GitHub).
- [ ] Has probado el vídeo en otro equipo.
- [ ] Has comprobado que OpenCode se instala y se desinstala.

## 2. Al llegar al laboratorio

- [ ] La VM Debian arranca y tiene IP.
- [ ] `ping 8.8.8.8` y `getent hosts github.com` funcionan.
- [ ] El repositorio está en la VM (USB, ZIP o `git clone`).
- [ ] Has creado `config.env` desde el ejemplo.
- [ ] Has identificado el disco del sistema.
- [ ] Los discos reales de P2 aparecen en `lsblk`.
- [ ] El host Proxmox tiene la plantilla Debian 12 para LXC.
- [ ] Los bridges `vmbr0`, `vmbr1` y `vmbr2` existen si los vas a usar.

## 3. P1

- [ ] Packet Tracer abre la topología.
- [ ] Los routers tienen la configuración pegada.
- [ ] DHCP entrega IP a los PCs.
- [ ] DNS resuelve el nombre del servidor.
- [ ] Hay ping entre redes distintas.
- [ ] `show ip route` muestra las rutas.

## 4. P2

- [ ] `./icd.sh p2 detect` muestra los discos correctos.
- [ ] La matriz `/dev/md0` está activa.
- [ ] Hay 3 discos activos y 1 de repuesto, o lo que pida el enunciado.
- [ ] `mdadm --detail /dev/md0` muestra `clean`.
- [ ] `/mnt/raid5` está montado.
- [ ] Has simulado el fallo y la reconstrucción, o sabes explicarlo.
- [ ] No has usado el disco del sistema.

## 5. P3

- [ ] `/mnt/raid5` es un punto de montaje.
- [ ] `fio` está instalado.
- [ ] `p3/resultados/resultados.csv` existe.
- [ ] Sabes explicar 4K vs 1M y lectura vs escritura.
- [ ] Los resultados son de la matriz, no del disco raíz.

## 6. P4

- [ ] `web1` responde en `192.168.50.11`.
- [ ] `web2` responde en `192.168.50.12` y muestra “Servidor 2”.
- [ ] `app` responde en `192.168.50.13`.
- [ ] `/salud` devuelve `estado: ok`.
- [ ] La tabla de productos se ve en el navegador.
- [ ] MariaDB solo acepta conexiones desde la IP de `app`.
- [ ] `systemctl status icdapp nginx mariadb` está correcto.
- [ ] Si usas LXC, `pct list` muestra los contenedores.

## 7. P5

- [ ] pfSense es una VM, no un LXC.
- [ ] WAN tiene IP por DHCP y la MAC reservada.
- [ ] LAN tiene la IP del enunciado.
- [ ] DMZ tiene la IP del enunciado.
- [ ] DHCP entrega IP en la LAN.
- [ ] DNS resuelve.
- [ ] Las reglas de firewall están aplicadas.
- [ ] NAT funciona si se pide.
- [ ] La web de la DMZ y la de la intranet responden.
- [ ] Flask responde en `/salud`.
- [ ] `pfctl -sn` y `pfctl -sr` muestran lo esperado.

## 8. Vídeo

- [ ] Se ven las cinco prácticas.
- [ ] Se ve el entorno: Proxmox, VM Debian y contenedores.
- [ ] Se entiende qué es automático y qué es manual.
- [ ] No hay contraseñas, tokens ni `config.xml`.
- [ ] El audio y el texto se entienden.
- [ ] El vídeo está guardado en el USB y en la nube.

## 9. Antes de entregar

- [ ] El repositorio no tiene cambios sin commit.
- [ ] No se ha subido `config.env`, `p4/vms.conf`, `p1/valores.env`,
  `p1/out/`, `p5/config.xml` ni credenciales.
- [ ] El USB se expulsa de forma segura.
- [ ] Tienes una copia del vídeo y del repositorio en otro sitio.
- [ ] Has borrado OpenCode y sus datos si el equipo es compartido.
