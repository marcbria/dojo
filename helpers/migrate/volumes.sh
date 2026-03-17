#!/usr/bin/env bash
# migrate/volumes.sh — sync real data volumes from prod to test
#
# Only REAL data directories are synced (never /all/ which holds only symlinks):
#   /srv/volumes/db/, db_import/, files/config/, files/private/, files/public/, logs/

phase_volumes() {
    section "PHASE 3: Sync data volumes  prod → test"

    warn "This phase can take a long time. Stopping prod containers ensures clean DB snapshots."

    confirm_action "This will OVERWRITE all volume data on TEST (${TEST_HOST}).
  prod (${PROD_HOST}) will NOT be modified — but its site containers may be briefly stopped."

    # ── Stop prod sites? ───────────────────────────────────────────────────────
    local stop_prod=false
    local stop_answer
    read -rp "  Stop site containers on prod before syncing? [y/N] " stop_answer
    echo "  stop_answer: ${stop_answer}" >> "$LOG_FILE"
    [[ "$stop_answer" =~ ^[yY]$ ]] && stop_prod=true

    if [[ "$stop_prod" == "true" ]]; then
        log "Stopping site containers on prod (Traefik stays up)..."
        local sites
        sites=$(prod_ssh "sudo ls ${DOJO_BASE}/sites/") || true
        for site in $sites; do
            log "  → Stopping: ${site}"
            prod_ssh "cd '${DOJO_BASE}/sites/${site}' && sudo docker compose down" \
                || warn "  Could not stop ${site}"
        done
        ok "Site containers stopped on prod"
    else
        warn "Syncing with live containers — DB data may be inconsistent."
    fi

    # ── Sync real data ─────────────────────────────────────────────────────────
    log "Syncing databases...";      rsync_to_test "${STORAGE_BASE}/volumes/db/"               "${STORAGE_BASE}/volumes/db/"               "--delete"
    log "Syncing db_import...";      rsync_to_test "${STORAGE_BASE}/volumes/db_import/"        "${STORAGE_BASE}/volumes/db_import/"        "--delete"
    log "Syncing config files...";   rsync_to_test "${STORAGE_BASE}/volumes/files/config/"     "${STORAGE_BASE}/volumes/files/config/"     "--delete"
    log "Syncing private files...";  rsync_to_test "${STORAGE_BASE}/volumes/files/private/"    "${STORAGE_BASE}/volumes/files/private/"    "--delete"
    log "Syncing public files...";   rsync_to_test "${STORAGE_BASE}/volumes/files/public/"     "${STORAGE_BASE}/volumes/files/public/"     "--delete"
    log "Syncing logs...";           rsync_to_test "${STORAGE_BASE}/volumes/logs/"             "${STORAGE_BASE}/volumes/logs/"             "--delete --exclude='*.log'"

    # ── Apply domain substitutions in config files inside volumes ─────────────
    log "Applying domain substitutions in volume config files on test..."
    [[ "${#DOMAIN_MAP[@]:-0}" -eq 0 ]] && build_domain_map
    apply_domain_map_in_test "${STORAGE_BASE}/volumes/files/config"

    # ── Verify symlink integrity ───────────────────────────────────────────────
    log "Verifying symlink integrity in ${STORAGE_BASE}/volumes/all/..."
    test_ssh "
        broken=0
        while IFS= read -r link; do
            [ ! -e \"\$link\" ] && echo \"  [BROKEN] \$link\" && broken=\$((broken+1))
        done < <(sudo find '${STORAGE_BASE}/volumes/all' -maxdepth 2 -type l 2>/dev/null)
        [ \$broken -eq 0 ] && echo '  All symlinks OK' \
            || echo \"  WARNING: \$broken broken symlink(s) — re-run phase infra\"
    " | tee -a "$LOG_FILE"

    # ── Restore prod if it was stopped ────────────────────────────────────────
    if [[ "$stop_prod" == "true" ]]; then
        log "Restoring site containers on prod..."
        local sites
        sites=$(prod_ssh "sudo ls ${DOJO_BASE}/sites/") || true
        for site in $sites; do
            log "  → Starting: ${site}"
            prod_ssh "cd '${DOJO_BASE}/sites/${site}' && sudo docker compose up -d" \
                || warn "  Could not start ${site}"
        done
        ok "Site containers restored on prod"
    fi

    ok "Volumes synced to test"
}
