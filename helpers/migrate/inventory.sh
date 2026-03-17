#!/usr/bin/env bash
# migrate/inventory.sh — list services and resources on prod (read-only)

phase_inventory() {
    section "PHASE 1: Inventory on prod (read-only)"

    log "Active containers:"
    prod_ssh "sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'" \
        | tee -a "$LOG_FILE"

    log "\nSites:";    prod_ssh "sudo ls -la ${DOJO_BASE}/sites/"   | tee -a "$LOG_FILE"
    log "\nServices:"; prod_ssh "sudo ls -la ${DOJO_BASE}/service/" | tee -a "$LOG_FILE"

    log "\nDisk usage:"
    prod_ssh "du -sh ${DOJO_BASE}/* ${STORAGE_BASE}/volumes/*/ 2>/dev/null" | tee -a "$LOG_FILE"

    log "\nDocker images:"
    prod_ssh "sudo docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'" \
        | tee -a "$LOG_FILE"

    log "\nDetected domains (PROJECT_DOMAIN per site):"
    local sites
    sites=$(prod_ssh "ls ${DOJO_BASE}/sites/") || { warn "Could not list sites"; return; }
    for site in $sites; do
        local d
        d=$(prod_ssh "grep -E '^PROJECT_DOMAIN=' '${DOJO_BASE}/sites/${site}/.env' 2>/dev/null \
             | cut -d'=' -f2 | tr -d '\"' || echo '(not found)'")
        printf "  %-25s → %s\n" "$site" "$d" | tee -a "$LOG_FILE"
    done

    ok "Inventory saved to $LOG_FILE"
}
