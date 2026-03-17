#!/usr/bin/env bash
# migrate/verify.sh — post-migration verification on test

phase_verify() {
    section "PHASE 6: Post-migration verification on test"

    log "Container status:"
    test_ssh "sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" | tee -a "$LOG_FILE"

    local exited
    exited=$(test_ssh "sudo docker ps -a --filter status=exited --format '{{.Names}}'") || true
    if [[ -z "$exited" ]]; then
        ok "No exited containers"
    else
        warn "Exited containers:"; echo "$exited" | tee -a "$LOG_FILE"
    fi

    log "\nDocker networks:"; test_ssh "sudo docker network ls"        | tee -a "$LOG_FILE"
    log "\nDisk usage:";      test_ssh "df -h '${DOJO_BASE}' '${STORAGE_BASE}'" | tee -a "$LOG_FILE"
    log "\nListening ports:"; test_ssh "ss -tlnp | grep -E ':80 |:443 |:22 '"   | tee -a "$LOG_FILE"

    log "\nHTTP status per test domain:"
    [[ "${#DOMAIN_MAP[@]:-0}" -eq 0 ]] && build_domain_map
    for prod_domain in "${!DOMAIN_MAP[@]}"; do
        local test_domain="${DOMAIN_MAP[$prod_domain]}"
        local http_status
        http_status=$(curl -sI --max-time 5 "http://${test_domain}" \
            | head -1 | tr -d '\r') || http_status="no response"
        printf "  %-45s %s\n" "http://${test_domain}" "$http_status" | tee -a "$LOG_FILE"
    done

    if [[ -n "$exited" ]]; then
        section "Last 20 log lines from exited containers"
        for container in $exited; do
            warn "--- ${container} ---"
            test_ssh "sudo docker logs --tail 20 '${container}' 2>&1" | tee -a "$LOG_FILE"
        done
    fi

    ok "Verification complete — full report in $LOG_FILE"
}
