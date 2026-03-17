#!/usr/bin/env bash
# migrate/images.sh — export/import non-public Docker images (streamed, no local temp file)

phase_images() {
    section "PHASE 4: Export/import Docker images"

    local images
    images=$(prod_ssh "sudo docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>'") || true

    log "All images on prod:"; echo "$images" | tee -a "$LOG_FILE"

    # Custom = not from a known public registry
    local custom_images
    custom_images=$(echo "$images" | grep -vE \
        "^(docker\.io/|ghcr\.io/|quay\.io/|public\.ecr\.|pkpofficial/|\
mariadb:|mysql:|postgres:|redis:|traefik:|louislam/|nginx:|alpine:|debian:)" || true)

    if [[ -z "$custom_images" ]]; then
        ok "No custom images — all will be pulled from registry automatically on test."
        return
    fi

    warn "Custom images found (require export):"; echo "$custom_images" | tee -a "$LOG_FILE"

    confirm_action "Export custom images from prod and import to test (streamed directly, no local temp file)."

    while IFS= read -r img; do
        [[ -z "$img" ]] && continue
        log "  → Streaming ${img}  prod → test..."
        if [[ "$DRY_RUN" == "false" ]]; then
            prod_ssh "sudo docker save '${img}' | gzip" | test_ssh "sudo docker load"
            ok "    ${img} imported on test"
        else
            warn "  [dry-run] Skipping export/import of ${img}"
        fi
    done <<< "$custom_images"
}
