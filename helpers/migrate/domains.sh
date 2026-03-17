#!/usr/bin/env bash
# migrate/domains.sh — review prod → test domain mapping (read-only)

phase_domains() {
    section "PHASE: Domain mapping review (read-only)"

    build_domain_map

    echo "" | tee -a "$LOG_FILE"
    printf "  %-42s  %-42s\n" "PRODUCTION DOMAIN" "TEST DOMAIN"                       | tee -a "$LOG_FILE"
    printf "  %-42s  %-42s\n" "------------------------------------------" "------------------------------------------" | tee -a "$LOG_FILE"
    for prod in "${!DOMAIN_MAP[@]}"; do
        printf "  %-42s  %-42s\n" "$prod" "${DOMAIN_MAP[$prod]}" | tee -a "$LOG_FILE"
    done
    echo "" | tee -a "$LOG_FILE"

    warn "If any mapping is wrong, edit domain_to_shortname() in migrate/common.sh before running infra or volumes."
    ok "Review complete — no files modified"
}
