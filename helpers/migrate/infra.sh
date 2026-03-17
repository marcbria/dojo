#!/usr/bin/env bash
# migrate/infra.sh — sync docker-compose, .env, configs and recreate symlinks on test
#
# Dojo directory layout:
#
#   DOJO_BASE/                              (e.g. /home/docker)
#   ├── service/proxy/                      ← Traefik and other services
#   └── sites/<site>/
#       ├── docker-compose.yml
#       ├── docker-compose.override.yml
#       ├── .env
#       └── volumes  →  STORAGE_BASE/volumes/all/<site>/   (SYMLINK)
#
#   STORAGE_BASE/volumes/                   (e.g. /srv/volumes)
#   ├── all/<site>/                         ← symlinks only, no real data
#   ├── db/<site>/                          ← real database files
#   ├── db_import/<site>/
#   ├── files/config/<site>/
#   ├── files/private/<site>/
#   ├── files/public/<site>/
#   └── logs/<site>/
#
# IMPORTANT: all/<site>/ contains ONLY symlinks. They must be recreated on
# test pointing to test's own local paths — never copied from prod.

phase_infra() {
    section "PHASE 2: Sync infrastructure to test (docker-compose, .env, configs)"

    confirm_action "This will overwrite docker-compose, .env and config files on TEST (${TEST_HOST}).
  prod (${PROD_HOST}) will NOT be modified."

    # ── 1. Directory tree on test ──────────────────────────────────────────────
    log "Creating directory structure on test..."
    test_ssh "sudo mkdir -p \
        '${DOJO_BASE}/service' '${DOJO_BASE}/sites' \
        '${STORAGE_BASE}/backups' \
        '${STORAGE_BASE}/volumes/all' \
        '${STORAGE_BASE}/volumes/db' \
        '${STORAGE_BASE}/volumes/db_import' \
        '${STORAGE_BASE}/volumes/files/config' \
        '${STORAGE_BASE}/volumes/files/private' \
        '${STORAGE_BASE}/volumes/files/public' \
        '${STORAGE_BASE}/volumes/logs'"
    ok "Directory tree ready on test"

    # ── 2. Sync proxy service ──────────────────────────────────────────────────
    log "Syncing service/ (Traefik) to test..."
    rsync_to_test "${DOJO_BASE}/service/" "${DOJO_BASE}/service/" \
        "--exclude='*.log' --exclude='acme.json' --exclude='acme/' \
         --exclude='letsencrypt/' --exclude='certificates/'"
    ok "service/ synced"

    # ── 3. Sync site definition files (no volumes symlink) ────────────────────
    local sites
    sites=$(prod_ssh "ls ${DOJO_BASE}/sites/") || { error "Could not list sites on prod"; exit 1; }

    for site in $sites; do
        log "  → Syncing site definition: ${site}"
        rsync_to_test "${DOJO_BASE}/sites/${site}/" "${DOJO_BASE}/sites/${site}/" \
            "--exclude='volumes' --exclude='*.log'"
        ok "    ${site} synced"
    done

    # ── 4. Per-site data directories on test ──────────────────────────────────
    log "Creating per-site data directories on test..."
    for site in $sites; do
        test_ssh "sudo mkdir -p \
            '${STORAGE_BASE}/volumes/all/${site}' \
            '${STORAGE_BASE}/volumes/db/${site}' \
            '${STORAGE_BASE}/volumes/db_import/${site}' \
            '${STORAGE_BASE}/volumes/files/config/${site}' \
            '${STORAGE_BASE}/volumes/files/private/${site}' \
            '${STORAGE_BASE}/volumes/files/public/${site}' \
            '${STORAGE_BASE}/volumes/logs/${site}' \
            '${STORAGE_BASE}/backups/${site}'"
    done
    ok "Per-site directories created"

    # ── 5. Recreate internal symlinks in volumes/all/<site>/ ──────────────────
    log "Recreating internal symlinks in ${STORAGE_BASE}/volumes/all/<site>/..."
    for site in $sites; do
        test_ssh "
            SRV='${STORAGE_BASE}/volumes'; S='${site}'
            sudo rm -f  \${SRV}/all/\${S}/config \${SRV}/all/\${S}/db \${SRV}/all/\${S}/db_import \
                        \${SRV}/all/\${S}/logs   \${SRV}/all/\${S}/private \${SRV}/all/\${S}/public
            sudo ln -s  \${SRV}/files/config/\${S}   \${SRV}/all/\${S}/config
            sudo ln -s  \${SRV}/db/\${S}              \${SRV}/all/\${S}/db
            sudo ln -s  \${SRV}/db_import/\${S}       \${SRV}/all/\${S}/db_import
            sudo ln -s  \${SRV}/logs/\${S}            \${SRV}/all/\${S}/logs
            sudo ln -s  \${SRV}/files/private/\${S}   \${SRV}/all/\${S}/private
            sudo ln -s  \${SRV}/files/public/\${S}    \${SRV}/all/\${S}/public
        "
        ok "    symlinks OK: ${site}"
    done

    # ── 6. Recreate sites/<site>/volumes → all/<site> symlink ─────────────────
    log "Recreating sites/<site>/volumes symlinks on test..."
    for site in $sites; do
        test_ssh "
            sudo rm -f '${DOJO_BASE}/sites/${site}/volumes'
            sudo ln -s '${STORAGE_BASE}/volumes/all/${site}' '${DOJO_BASE}/sites/${site}/volumes'
        "
        ok "    volumes → all/${site} OK"
    done

    # ── 7. Apply domain substitutions ─────────────────────────────────────────
    log "Building domain map..."; build_domain_map
    log "Applying domain substitutions in test sites/..."
    apply_domain_map_in_test "${DOJO_BASE}/sites"
    log "Applying domain substitutions in test service/..."
    apply_domain_map_in_test "${DOJO_BASE}/service"

    # ── 8. Verify ─────────────────────────────────────────────────────────────
    log "Verifying structure on test:"
    test_ssh "echo '--- DOJO_BASE ---'; find '${DOJO_BASE}' -maxdepth 3 | sort
              echo ''; echo '--- volumes/all ---'
              find '${STORAGE_BASE}/volumes/all' -maxdepth 2 | sort" | tee -a "$LOG_FILE"

    ok "Infrastructure synced to test"
}
