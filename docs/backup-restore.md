# Backup & Restore (ZFS)

All persistent site data lives on three ZFS datasets:

| Dataset              | Contains                                                     |
|:---------------------|:-------------------------------------------------------------|
| `srv/volumes/db`     | Per-site MariaDB data files                                  |
| `srv/volumes/files`  | Per-site `config/`, `private/`, `public/` (OJS/OMP files)    |
| `srv/volumes/logs`   | Per-site Apache/PHP logs                                     |

A **backup** is a set of three ZFS snapshots sharing one tag
(`backup-<UTC-timestamp>`) — created atomically per dataset.

A **restore** extracts only `<site>/` from each snapshot into the original
paths. Other sites are never touched.

> ZFS snapshots live on the same pool. For off-site / cross-pool backups use
> `zfs send | zfs receive` to `/srv/backups` or a remote host.

## Commands

```bash
# Create a snapshot set for one site (fast, best-effort consistency)
just dojo-backup-snap myjournal $SERVER

# Same, but pause the app container during the snap (safest for OJS)
just dojo-backup-snap myjournal $SERVER consistency=pause

# Same, but fully stop app+db containers (cleanest, has downtime)
just dojo-backup-snap myjournal $SERVER consistency=stop

# Tagged snapshots (useful before an upgrade)
just dojo-backup-snap myjournal $SERVER snapshot_tag=pre-upgrade-3_5

# List snapshots
just dojo-backup-list myjournal $SERVER

# Prune (keep last 7 per dataset by default; keep must be >= 1)
just dojo-backup-prune myjournal $SERVER keep=7
```

## Restore

```bash
# 1. List snapshots to find the tag
just dojo-backup-list myjournal $SERVER

# 2. Restore (the confirm token is mandatory — protects against accidents)
just dojo-restore-snap myjournal $SERVER backup-20241005-143022 \
    confirm=RESTORE-myjournal
```

What the restore does, in order:

1. Validates the snapshot exists on every dataset and contains `<site>/`.
2. `docker compose down` on the site (other sites keep running).
3. Moves current data aside to `<path>.pre-restore-<ts>/`.
4. `rsync -aHAX --delete` from `.zfs/snapshot/<tag>/...` to the live path.
5. Fixes ownership/permissions using `volumes.db.*` and `volumes.app.*`
   (falls back to `user.run`/`user.group` if not set).
6. `docker compose up -d`.

### ⚠️ The `.pre-restore-*` folders are your only safety net

The data moved aside in step 3 is **created after the snapshot is taken**, so it
is **not itself backed up anywhere**. If the subsequent `rsync` fails and someone
cleans those folders to make space, there is no way back.

- Never delete them automatically.
- Delete them only after verifying the site is healthy.
- If in doubt, keep them; a single site's `files/config` is usually tiny.

Rollback after a bad restore: stop the containers and rename the
`.pre-restore-*` folders back. Delete them once you've verified.

## Extending to other datasets

If your site uses `plugins.type: volume-plugins` or `volume-themes`, those
volumes live under `/srv/volumes/all/<site>/...` and are **not** covered by
the default snapshot set. Include them explicitly:

```bash
just dojo-backup-snap myjournal $SERVER \
    zfs_extra_datasets='["srv/volumes"]'
```

**Important:** extra datasets are handled as **whole-dataset** snapshots and
restores:

- Backup creates `srv/volumes@backup-<tag>` (the entire dataset).
- Restore runs `rsync --delete` from `srv/volumes/.zfs/snapshot/<tag>/`
  to `/srv/volumes/` — i.e., it restores **every site's data** in that dataset,
  not just the one you asked for.
- Therefore use `zfs_extra_datasets` **only** for datasets dedicated to a single
  site. If a dataset holds multiple sites, do not include it here — restore
  manually with a per-site path instead.

The same variable is honoured by `backup-snap.yml`, `backup-list.yml`,
`backup-prune.yml` and `restore-snap.yml`.

## Consistency notes

- **MariaDB/InnoDB** is crash-consistent: a `none` snapshot will recover on
  next start. Use `pause`/`stop` if you want a byte-for-byte consistent state.
- **Postgres** (Plausible): `none` is usually fine; `stop` for critical restores.
- `stop` mode brings containers down and back up; the playbook waits for
  `docker compose up -d` but does **not** wait for MySQL readiness. Run
  `just dojo-manage <site> <host> ps` afterwards to verify.
