---
title: Backup & Restore (ZFS)
description: Guía de copias de seguridad y restauración con ZFS para sitios PKP en dojo
tags: dojo, zfs, backup, restore, ojs, omp, ansible
---

# Backup & Restore (ZFS)

:::info
Esta guía documenta el sistema de backup y restauración basado en ZFS implementado en los playbooks `backup-snap.yml`, `backup-list.yml`, `backup-prune.yml` y `restore-snap.yml` del proyecto **dojo**.
:::

## Arquitectura de datos

Todos los datos persistentes de cada sitio viven en tres datasets ZFS independientes:

| Dataset | Contenido | Ruta en el host |
|:--|:--|:--|
| `srv/volumes/db` | Datos de MariaDB/PostgreSQL por sitio | `/srv/volumes/db/<site>/` |
| `srv/volumes/files` | `config/`, `private/`, `public/` (ficheros OJS/OMP) | `/srv/volumes/files/{config,private,public}/<site>/` |
| `srv/volumes/logs` | Logs de Apache/PHP por sitio | `/srv/volumes/logs/<site>/` |

:::warning
Estos datasets son **compartidos por todos los sitios del host**. Un snapshot captura el dataset completo, no solo un sitio. La restauración extrae únicamente la subcarpeta `<site>/`, por lo que el resto de sitios nunca se ven afectados.
:::

## Conceptos clave

### Snapshot set

Un **snapshot set** es el conjunto de tres snapshots ZFS que comparten la misma etiqueta (`backup-<UTC-timestamp>`) en los tres datasets. Se crean de forma coordinada para que la restauración sea coherente.

```
srv/volumes/db@backup-20241005-143022
srv/volumes/files@backup-20241005-143022
srv/volumes/logs@backup-20241005-143022
```

### Qué NO se incluye en el snapshot

:::danger
Los ficheros de definición del sitio **no están cubiertos** por ningún snapshot:

- `/home/docker/sites/<site>/docker-compose.yml`
- `/home/docker/sites/<site>/docker-compose.override.yml`
- `/home/docker/sites/<site>/.env`

Estos ficheros son **regenerables** desde el inventario + vault (principio GitOps). Si faltan, el playbook de restauración **falla antes de tocar nada** e indica que ejecutes `just dojo-create` primero.
:::

## Comandos disponibles

### Crear un backup

```bash
# Snapshot rápido, consistencia best-effort (InnoDB crash recovery)
just dojo-backup-snap myjournal $SERVER

# Pausa el contenedor de la app durante el snapshot (más seguro para OJS)
just dojo-backup-snap myjournal $SERVER consistency=pause

# Detiene app + db completamente (más limpio, con downtime)
just dojo-backup-snap myjournal $SERVER consistency=stop

# Snapshot con etiqueta personalizada (útil antes de un upgrade)
just dojo-backup-snap myjournal $SERVER snapshot_tag=pre-upgrade-3_5

# Prefijo de snapshot personalizado (por defecto: backup)
just dojo-backup-snap myjournal $SERVER snapshot_prefix=manual
```

### Listar snapshots

```bash
# Lista todos los snapshots de los datasets del sitio
just dojo-backup-list myjournal $SERVER

# Filtra por prefijo
just dojo-backup-list myjournal $SERVER snapshot_prefix=backup
```

### Purgar snapshots antiguos

```bash
# Mantiene los últimos 7 por dataset (por defecto)
just dojo-backup-prune myjournal $SERVER

# Mantiene los últimos 14
just dojo-backup-prune myjournal $SERVER keep=14
```

:::warning
El parámetro `keep` debe ser **mayor o igual a 1**. El playbook rechaza `keep=0` o valores negativos para evitar borrar todos los snapshots.

Además, como los snapshots son **por dataset** (no por sitio), el conteo es compartido entre todos los sitios del mismo host. `just dojo-backup-prune <site>` cuenta y destruye el mismo pool de snapshots que vería cualquier otro sitio.
:::

### Restaurar desde un snapshot

```bash
# 1. Localiza la etiqueta del snapshot a restaurar
just dojo-backup-list myjournal $SERVER

# 2. Restaura (el token de confirmación es obligatorio)
just dojo-restore-snap myjournal $SERVER backup-20241005-143022 \
    confirm=RESTORE-myjournal
```

El token `confirm=RESTORE-<site>` protege contra restauraciones accidentales. El playbook falla si no coincide exactamente.

## Modos de consistencia

| Modo | Acción | Uso recomendado |
|:--|:--|:--|
| `none` (default) | Sin intervención. Confía en InnoDB crash recovery | Backups rutinarios, mínima interrupción |
| `pause` | `docker pause` del contenedor de la app durante el snapshot | Backups importantes sin downtime |
| `stop` | `docker compose stop` (app + db) durante el snapshot | Backups críticos, pre-upgrade, migraciones |

:::tip
**MariaDB/InnoDB** es crash-consistent: un snapshot `none` se recupera al arrancar. Usa `pause` o `stop` si necesitas un estado byte-a-byte consistente.

**PostgreSQL** (Plausible): `none` suele ser suficiente; `stop` para restauraciones críticas.

El modo `stop` levanta los contenedores de nuevo con `docker compose up -d`, pero **no espera** a que MySQL esté listo. Verifica después con `just dojo-manage <site> <host> ps`.
:::

## Procedimiento de restauración

El playbook `restore-snap.yml` ejecuta los siguientes pasos en orden:

1. **Validación** — Comprueba que el snapshot existe en cada dataset y contiene `<site>/`.
2. **Parada** — `docker compose down` en el sitio (otros sitios siguen corriendo).
3. **Movimiento** — Mueve los datos actuales a `<path>.pre-restore-<ts>/`.
4. **Restauración** — `rsync -aHAX --delete` desde `.zfs/snapshot/<tag>/...` a la ruta viva.
5. **Permisos** — Corrige ownership/mode usando `volumes.db.*` y `volumes.app.*` (fallback a `user.run`/`user.group`).
6. **Arranque** — `docker compose up -d`.

:::danger
**Los directorios `.pre-restore-*` son tu única red de seguridad.**

Los datos movidos en el paso 3 se crean **después** de tomar el snapshot, por lo que **no están respaldados en ningún sitio**. Si el `rsync` posterior falla y alguien limpia esas carpetas para liberar espacio, **no hay vuelta atrás**.

- Nunca los borres automáticamente.
- Bórralos solo después de verificar que el sitio funciona correctamente.
- En caso de duda, consérvalos; el `files/config` de un sitio suele ser minúsculo.
:::

### Rollback tras una restauración fallida

```bash
# 1. Detén los contenedores del sitio
just dojo-manage myjournal $SERVER down

# 2. Renombra las carpetas .pre-restore-* de vuelta a sus nombres originales
#    (hazlo manualmente en el servidor o vía ansible)

# 3. Arranca de nuevo
just dojo-manage myjournal $SERVER up
```

Borra las carpetas `.pre-restore-*` una vez verificada la restauración.

## Recuperación completa cuando falta el directorio del sitio

Si el directorio `/home/docker/sites/<site>/` ha desaparecido por completo:

```bash
# 1. Regenera la definición del sitio desde inventario + vault
just dojo-create myjournal $SERVER

# 2. Restaura los datos desde el snapshot
just dojo-restore-snap myjournal $SERVER backup-20241005-143022 \
    confirm=RESTORE-myjournal
```

:::info
`dojo-create` también reescribe `/srv/volumes/files/config/<site>/*` (`config.inc.php`, `db.custom.cnf`, `php.custom.ini`, `apache.conf`). Esos ficheros serán re-restaurados desde el snapshot por el playbook de restore inmediatamente después.
:::

## Extender a otros datasets

Si tu sitio usa `plugins.type: volume-plugins` o `volume-themes`, esos volúmenes viven bajo `/srv/volumes/all/<site>/...` y **no** están cubiertos por el snapshot set por defecto. Inclúyelos explícitamente:

```bash
just dojo-backup-snap myjournal $SERVER \
    zfs_extra_datasets='["srv/volumes"]'
```

:::warning
**Los datasets extra se tratan como snapshots/restauraciones de dataset completo:**

- El backup crea `srv/volumes@backup-<tag>` (el dataset entero).
- La restauración ejecuta `rsync --delete` desde `srv/volumes/.zfs/snapshot/<tag>/` a `/srv/volumes/` — es decir, restaura **los datos de todos los sitios** en ese dataset, no solo el que pediste.
- Por tanto, usa `zfs_extra_datasets` **solo** para datasets dedicados a un único sitio. Si un dataset aloja varios sitios, no lo incluyas aquí — restaura manualmente con una ruta por sitio.
:::

La misma variable es respetada por `backup-snap.yml`, `backup-list.yml`, `backup-prune.yml` y `restore-snap.yml`.

## Backup off-site

:::tip
Los snapshots ZFS viven en el mismo pool. Para backups off-site o cross-pool usa `zfs send | zfs receive` hacia `/srv/backups` o un host remoto:

```bash
zfs send srv/volumes/db@backup-20241005-143022 \
  | ssh remote-host zfs receive backup/volumes/db
```
:::

## Referencia de variables

| Variable | Default | Descripción |
|:--|:--|:--|
| `snapshot_prefix` | `backup` | Prefijo de la etiqueta del snapshot |
| `snapshot_tag` | timestamp UTC | Etiqueta específica del snapshot |
| `consistency` | `none` | Modo de consistencia: `none`, `pause`, `stop` |
| `keep` | `7` | Número de snapshots a conservar en prune |
| `zfs_extra_datasets` | `[]` | Datasets adicionales a incluir |
| `zfs_dataset_db` | derivado | Override del dataset de DB |
| `zfs_dataset_files` | derivado | Override del dataset de files |
| `zfs_dataset_logs` | derivado | Override del dataset de logs |
| `confirm` | — | Token obligatorio para restore: `RESTORE-<site>` |

## Troubleshooting

### El snapshot ya existe

```
Snapshot backup-20241005-143022 already exists on srv/volumes/db
```

Usa una etiqueta distinta con `snapshot_tag=<nueva-etiqueta>`.

### Dataset no montado

```
Dataset srv/volumes/db is missing or not mounted
```

Verifica con `zfs get mounted srv/volumes/db` y móntalo con `zfs mount srv/volumes/db`.

### zfs no instalado

```
zfs is not installed on <host>
```

Instala ZFS en el servidor: `just infra-run install-zfstools $SERVER`.

### El snapshot no contiene el sitio

```
Missing in snapshot: /srv/volumes/db/.zfs/snapshot/<tag>/<site>
```

El snapshot fue tomado antes de que el sitio existiera, o pertenece a otro dataset. Lista los snapshots disponibles con `just dojo-backup-list <site> <host>`.

### Faltan ficheros de definición del sitio

```
Missing site definition file(s) in /home/docker/sites/<site>/:
  - docker-compose.yml
  - docker-compose.override.yml
  - .env
```

Estos ficheros no están cubiertos por ZFS. Ejecuta primero `just dojo-create <site> <host>` y luego repite la restauración.
