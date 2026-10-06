---
title: Backup & Restore
description: Backup and restore strategies for PKP sites in dojo — ZFS and rsync backends
tags: dojo, backup, restore, zfs, rsync, ojs, omp, ansible
---

# Backup & Restore

:::info
This guide documents the two backup backends implemented in dojo:

- **ZFS** — for production hosts with ZFS pools (`backup-snap.yml`, `backup-list.yml`, `backup-prune.yml`, `restore-snap.yml`).
- **rsync** — for hosts without ZFS, typically test/staging (`backup-rsync-snap.yml`, `backup-rsync-list.yml`, `backup-rsync-prune.yml`, `restore-rsync-snap.yml`).

Both backends share the same philosophy: a per-site snapshot set, identified by a timestamp/tag, with consistency modes and safety guards.
:::

---

## Data architecture

All persistent site data lives under two roots:

| Path | Contents |
|:--|:--|
| `/srv/volumes/db/<site>/` | MariaDB/PostgreSQL data files |
| `/srv/volumes/files/config/<site>/` | `config.inc.php`, `db.custom.cnf`, `php.custom.ini`, `apache.conf` |
| `/srv/volumes/files/private/<site>/` | Private uploads (submissions, revisions) |
| `/srv/volumes/files/public/<site>/` | Public files (published articles, issues) |
| `/srv/volumes/logs/<site>/` | Apache/PHP logs |

On ZFS hosts these paths live on three shared datasets (`srv/volumes/db`, `srv/volumes/files`, `srv/volumes/logs`). On rsync hosts they are plain directories under `/srv`.

:::warning
On ZFS hosts, these datasets are **shared by every site on the host**. A snapshot captures the whole dataset, not a single site. Restoration extracts only the `<site>/` subfolder, so other sites are never affected.
:::

### Pre-restore backups (`_pre-restore/`)

Both backends move the live data aside **before** overwriting it during a restore. Instead of scattering `<site>.pre-restore-<ts>` folders at the top of each dataset (which pollutes listings and complicates bulk cleanup), the pre-restore data is stored in a dedicated subfolder:

```
/srv/volumes/db/
├── anuarioiet/                                 ← live data
├── othersite/
└── _pre-restore/
    └── anuarioiet-<timestamp>/                 ← previous data
```

- The `_pre-restore/` folder name starts with `_` so it sorts first and never collides with a site name.
- Inside, each entry is `<site>-<timestamp>`, matching the naming convention used by the rsync snapshots.
- Bulk cleanup becomes a single command:

  ```bash
  rm -rf /srv/volumes/db/_pre-restore/anuarioiet-* \
         /srv/volumes/files/config/_pre-restore/anuarioiet-* \
         /srv/volumes/files/private/_pre-restore/anuarioiet-* \
         /srv/volumes/files/public/_pre-restore/anuarioiet-* \
         /srv/volumes/logs/_pre-restore/anuarioiet-*
  ```

:::danger
**The `_pre-restore/` folders are your only safety net during a restore.**

The data moved aside is **created after the snapshot is taken**, so it is **not backed up anywhere**. If a subsequent restore step fails and someone cleans those folders to free space, there is **no way back**.

- Never delete them automatically.
- Delete them only after verifying the site is healthy.
- If in doubt, keep them; a single site's `files/config` is usually tiny.
:::

---

## ZFS backend

### Key concepts

#### Snapshot set

A **snapshot set** is three ZFS snapshots sharing the same tag (`backup-<UTC-timestamp>`) on the three datasets. They are created together so that a restore is coherent.

```
srv/volumes/db@backup-20241005-143022
srv/volumes/files@backup-20241005-143022
srv/volumes/logs@backup-20241005-143022
```

#### What is NOT included

:::danger
Site definition files are **not covered** by any ZFS snapshot:

- `/home/docker/sites/<site>/docker-compose.yml`
- `/home/docker/sites/<site>/docker-compose.override.yml`
- `/home/docker/sites/<site>/.env`

These files are **regenerable** from inventory + vault (GitOps principle). If they are missing, the restore playbook **fails before touching anything** and tells you to run `just dojo-create` first.
:::

### Commands

#### Create a backup

```bash
# Fast snapshot, best-effort consistency (InnoDB crash recovery)
just dojo-backup-snap myjournal $SERVER

# Pause the app container during the snapshot (safer for OJS)
just dojo-backup-snap myjournal $SERVER consistency=pause

# Stop app + db completely (cleanest, has downtime)
just dojo-backup-snap myjournal $SERVER consistency=stop

# Tagged snapshot (useful before an upgrade)
just dojo-backup-snap myjournal $SERVER snapshot_tag=pre-upgrade-3_5

# Custom snapshot prefix (default: backup)
just dojo-backup-snap myjournal $SERVER snapshot_prefix=manual
```

#### List snapshots

```bash
# List all snapshots on the datasets for this site
just dojo-backup-list myjournal $SERVER

# Filter by prefix
just dojo-backup-list myjournal $SERVER snapshot_prefix=backup
```

#### Prune old snapshots

```bash
# Keep the last 7 per dataset (default)
just dojo-backup-prune myjournal $SERVER

# Keep the last 14
just dojo-backup-prune myjournal $SERVER keep=14
```

:::warning
`keep` must be **greater than or equal to 1**. The playbook refuses `keep=0` or negative values to avoid deleting every snapshot.

Also, since snapshots are **per dataset** (not per site), the count is shared across all sites on the same host. `just dojo-backup-prune <site>` counts and destroys the same snapshot pool that any other site would see.
:::

#### Restore from a snapshot

```bash
# 1. Locate the snapshot tag to restore
just dojo-backup-list myjournal $SERVER

# 2. Restore (the confirm token is mandatory)
just dojo-restore-snap myjournal $SERVER backup-20241005-143022 \
    confirm=RESTORE-myjournal
```

The `confirm=RESTORE-<site>` token protects against accidental restores. The playbook fails if it does not match exactly.

### Consistency modes

| Mode | Action | Recommended use |
|:--|:--|:--|
| `none` (default) | No intervention. Relies on InnoDB crash recovery | Routine backups, minimal disruption |
| `pause` | `docker pause` the app container during the snapshot | Important backups without downtime |
| `stop` | `docker compose stop` (app + db) during the snapshot | Critical backups, pre-upgrade, migrations |

:::tip
**MariaDB/InnoDB** is crash-consistent: a `none` snapshot recovers on next start. Use `pause` or `stop` if you need a byte-for-byte consistent state.

**PostgreSQL** (Plausible): `none` is usually fine; `stop` for critical restores.

`stop` mode brings containers down and back up, but **does not wait** for MySQL readiness. Verify with `just dojo-manage <site> <host> ps` afterwards.
:::

### Restoration procedure

The `restore-snap.yml` playbook runs the following steps in order:

1. **Validation** — Confirms the snapshot exists on every dataset and contains `<site>/`.
2. **Stop** — `docker compose down` on the site (other sites keep running).
3. **Move aside** — Moves current data to `<dataset>/_pre-restore/<site>-<ts>/`.
4. **Restore** — `rsync -aHAX --delete` from `.zfs/snapshot/<tag>/...` to the live path.
5. **Permissions** — Fixes ownership/mode using `volumes.db.*` and `volumes.app.*` (fallback to `user.run`/`user.group`).
6. **Start** — `docker compose up -d`.

### Rollback after a failed restore

```bash
# 1. Stop the site containers
just dojo-manage myjournal $SERVER down

# 2. Rename the _pre-restore folders back to their original names
#    (do it manually on the server)

# 3. Start again
just dojo-manage myjournal $SERVER up
```

Delete the `_pre-restore/<site>-<ts>/` folders once the restore has been verified.

### Full recovery when the site directory is missing

If `/home/docker/sites/<site>/` has disappeared entirely:

```bash
# 1. Regenerate the site definition from inventory + vault
just dojo-create myjournal $SERVER

# 2. Restore the data from the snapshot
just dojo-restore-snap myjournal $SERVER backup-20241005-143022 \
    confirm=RESTORE-myjournal
```

:::info
`dojo-create` also rewrites `/srv/volumes/files/config/<site>/*` (`config.inc.php`, `db.custom.cnf`, `php.custom.ini`, `apache.conf`). Those files are re-restored from the snapshot by the restore playbook immediately afterwards.
:::

### Off-site backup

:::tip
ZFS snapshots live on the same pool. For off-site or cross-pool backups use `zfs send | zfs receive` to `/srv/backups` or a remote host:

```bash
zfs send srv/volumes/db@backup-20241005-143022 \
  | ssh remote-host zfs receive backup/volumes/db
```
:::

### Variable reference

| Variable | Default | Description |
|:--|:--|:--|
| `snapshot_prefix` | `backup` | Snapshot tag prefix |
| `snapshot_tag` | UTC timestamp | Specific snapshot tag |
| `consistency` | `none` | Consistency mode: `none`, `pause`, `stop` |
| `keep` | `7` | Number of snapshots to keep on prune |
| `zfs_dataset_db` | derived | Override the DB dataset |
| `zfs_dataset_files` | derived | Override the files dataset |
| `zfs_dataset_logs` | derived | Override the logs dataset |
| `confirm` | — | Mandatory token for restore: `RESTORE-<site>` |

### Troubleshooting (ZFS)

#### Snapshot already exists

```
Snapshot backup-20241005-143022 already exists on srv/volumes/db
```

Use a different tag with `snapshot_tag=<new-tag>`.

#### Dataset not mounted

```
Dataset srv/volumes/db is missing or not mounted
```

Check with `zfs get mounted srv/volumes/db` and mount it with `zfs mount srv/volumes/db`.

#### zfs not installed

```
zfs is not installed on <host>
```

Install ZFS on the server: `just infra-run install-zfstools $SERVER`.

#### Snapshot does not contain the site

```
Missing in snapshot: /srv/volumes/db/.zfs/snapshot/<tag>/<site>
```

The snapshot was taken before the site existed, or belongs to another dataset. List available snapshots with `just dojo-backup-list <site> <host>`.

#### Missing site definition files

```
Missing site definition file(s) in /home/docker/sites/<site>/:
  - docker-compose.yml
  - docker-compose.override.yml
  - .env
```

These files are not covered by ZFS. Run `just dojo-create <site> <host>` first, then retry the restore.

---

## rsync backend (hosts without ZFS)

Hosts without ZFS (typically test/staging such as `cory`) use an alternative backend based on `rsync` that replicates the same philosophy: one snapshot per site, identified by a timestamp, with equivalent consistency modes and safety guards.

### Differences from ZFS

| Aspect | ZFS | rsync |
|:--|:--|:--|
| Atomicity | Yes (per dataset) | No — `stop` mode recommended |
| Includes `docker-compose*.yml` and `.env` | No (GitOps) | Yes (self-contained) |
| Location | `.zfs/snapshot/<tag>/` | `/srv/backup/<site>/<tag>/` |
| Restore requires prior `dojo-create` | Yes | No |
| Space cost | Instant (COW) | Full copy |

:::info
The rsync backend uses `/srv/backup/<site>/` (singular), which is independent from the ZFS backend's `/srv/backups/<site>/` (plural) referenced in `configs/dojo.yml`. Both can coexist on the same host.
:::

### Snapshot layout

```
/srv/backup/<site>/<timestamp>/
├── definition/
│   ├── docker-compose.yml
│   ├── docker-compose.override.yml
│   └── .env
├── db/
├── config/
├── logs/
├── private/          ← omitted when skip_private=true
├── public/           ← omitted when skip_public=true
└── SNAPSHOT.info
```

### Commands

```bash
# Full backup (stop mode by default, tag ends with -full)
just dojo-backup-rsync-snap myjournal $SERVER

# Fast backup: skip private/ and public/ (tag ends with -quick)
just dojo-backup-rsync-snap myjournal $SERVER true

# List snapshots
just dojo-backup-rsync-list myjournal $SERVER

# Prune (keep >= 1)
just dojo-backup-rsync-prune myjournal $SERVER 7

# Restore (confirm token mandatory)
just dojo-restore-rsync-snap myjournal $SERVER <tag> RESTORE-myjournal
```

### Consistency modes

| Mode | Action | Recommendation |
|:--|:--|:--|
| `none` | No intervention | **Not recommended** on rsync (no atomicity) |
| `pause` | `docker pause` the app container | Backups without downtime |
| `stop` (default) | `docker compose stop` (app + db) | Critical backups |

:::warning
Unlike ZFS, `rsync` does not provide atomic filesystem snapshots. If you copy `db/` while MariaDB is writing, the backup may end up inconsistent. That is why the default is `stop`.
:::

### Restoration

The rsync restore playbook **also restores the definition files** from `definition/`, since the snapshot includes them. This means:

- If `docker-compose*.yml` or `.env` get corrupted on the server, you can recover them directly from the snapshot.
- There is no need to run `dojo-create` before the restore.

If the snapshot was created with `skip_files=true` (or `skip_private`/`skip_public`), those folders are not touched on the live site during the restore. The host's `private/` and `public/` folders keep their previous contents.

### `_pre-restore/` folders

As with the ZFS backend, the restore moves the current data to `<dataset>/_pre-restore/<site>-<ts>/` before overwriting. **Do not delete these folders until the restore has been verified.**

### Variable reference (rsync)

| Variable | Default | Description |
|:--|:--|:--|
| `snapshot_tag` | UTC timestamp | Snapshot folder name |
| `backup_root` | `/srv/backup` | Root folder for rsync backups |
| `skip_files` | `false` | Skip both `private/` and `public/` |
| `skip_private` | inherits `skip_files` | Skip `private/` only |
| `skip_public` | inherits `skip_files` | Skip `public/` only |
| `consistency` | `stop` | Consistency mode: `none`, `pause`, `stop` |
| `keep` | `7` | Number of snapshots to keep on prune (must be >= 1) |
| `confirm` | — | Mandatory token for restore: `RESTORE-<site>` |

### Troubleshooting (rsync)

#### Snapshot already exists

```
Snapshot directory already exists: /srv/backup/<site>/<tag>
```

Use a different tag with `snapshot_tag=<new-tag>`.

#### rsync not installed

```
rsync is not installed on <host>
```

Install it via `just infra-run install-basic $SERVER`.

#### Missing definition files on backup

```
Missing definition file(s) in /home/docker/sites/<site>/:
  - docker-compose.yml
  - docker-compose.override.yml
  - .env
```

Unlike the ZFS backend, rsync backups include these files, so they must exist at backup time. Run `just dojo-create <site> <host>` first.

#### Snapshot incomplete on restore

```
Missing in snapshot: definition
```

The snapshot folder is corrupted or was created by an older dojo version. Use another snapshot from `just dojo-backup-rsync-list`.

---

## Choosing a backend

| Situation | Backend |
|:--|:--|
| Production host with ZFS pool | ZFS |
| Test/staging host without ZFS | rsync |
| Need atomic, instant, space-efficient snapshots | ZFS |
| Need self-contained snapshots including site definition files | rsync |
| Cross-pool / off-site backup | `zfs send` (ZFS) or `rsync` to remote (both) |

:::tip
Both backends are fully independent. They can coexist on the same dojo installation: use `dojo-backup-*` (ZFS) for production and `dojo-backup-rsync-*` for test servers.
:::
