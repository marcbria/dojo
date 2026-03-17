#!/usr/bin/env bash
# migrate/start.sh — start containers on test (Traefik first, then sites)

phase_start() {
    section "PHASE 5: Start containers on test"

    confirm_action "Start all containers on TEST (${TEST_HOST}).
  Services will become accessible on test domains."

    # ── Start Traefik first ───────────────────────────────────────────────────
    log "Starting proxy (Traefik) on test..."
    if [[ "$DRY_RUN" == "false" ]]; then
        test_ssh "cd '${DOJO_BASE}/service/proxy' && sudo docker compose up -d" \
            || { error "Error starting Traefik — aborting"; exit 1; }
    else
        warn "[dry-run] Skipping: docker compose up -d for proxy"
    fi

    # Poll until Traefik is ready before starting sites
    log "Waiting for Traefik to be ready..."
    local ready=false
    for i in {1..15}; do
        test_ssh "sudo docker exec proxy traefik version" &>/dev/null && { ready=true; break; }
        log "  Attempt ${i}/15 — retrying in 2s..."; sleep 2
    done
    [[ "$ready" == "false" ]] && { error "Traefik not ready after 30s — check: sudo docker logs proxy"; exit 1; }
    ok "Traefik is ready"

    # ── Start sites ───────────────────────────────────────────────────────────
    local sites
    sites=$(test_ssh "sudo ls '${DOJO_BASE}/sites/' 2>/dev/null") || true
    for site in $sites; do
        log "  → Starting: ${site}"
        if [[ "$DRY_RUN" == "false" ]]; then
            test_ssh "cd '${DOJO_BASE}/sites/${site}' && sudo docker compose up -d" \
                || warn "  Error starting ${site}"
        else
            warn "  [dry-run] Skipping: docker compose up -d for ${site}"
        fi
    done

    ok "All containers started on test"
}
