#!/usr/bin/env bash
# migrate/preflight.sh — pre-flight checks before any phase runs

phase_preflight() {
    section "Preflight checks"

    log "Checking SSH to prod (${SSH_USER}@${PROD_HOST})..."
    prod_ssh "echo OK" &>/dev/null && ok "prod reachable" \
        || { error "Cannot connect to prod (${SSH_USER}@${PROD_HOST})"; exit 1; }

    log "Checking SSH to test (${SSH_USER}@${TEST_HOST})..."
    test_ssh "echo OK" &>/dev/null && ok "test reachable" \
        || { error "Cannot connect to test (${SSH_USER}@${TEST_HOST})"; exit 1; }

    log "Checking NOPASSWD sudo on prod..."
    prod_ssh "sudo -n true" &>/dev/null && ok "sudo OK on prod" \
        || { error "sudo requires password on prod — add NOPASSWD for ${SSH_USER}"; exit 1; }

    log "Checking NOPASSWD sudo on test..."
    test_ssh "sudo -n true" &>/dev/null && ok "sudo OK on test" \
        || { error "sudo requires password on test — add NOPASSWD for ${SSH_USER}"; exit 1; }

    log "Checking Docker on prod..."
    prod_ssh "sudo docker info" &>/dev/null && ok "Docker OK on prod" \
        || { error "Docker not responding on prod"; exit 1; }

    log "Checking Docker on test..."
    test_ssh "sudo docker info" &>/dev/null && ok "Docker OK on test" \
        || { error "Docker not responding on test"; exit 1; }

    log "Checking prod → test SSH access (required for rsync push)..."
    if prod_ssh "ssh ${SSH_OPTS} ${SSH_USER}@${TEST_HOST} echo OK" &>/dev/null; then
        ok "prod can SSH into test — rsync push will work"
    else
        error "prod cannot SSH into test."
        error "Fix: from prod, run: ssh-copy-id ${SSH_USER}@${TEST_HOST}"
        exit 1
    fi

    log "Checking dojo structure on prod..."
    prod_ssh "test -d ${DOJO_BASE}/sites && test -d ${DOJO_BASE}/service" \
        && ok "dojo structure OK on prod" \
        || { error "dojo base not found on prod (${DOJO_BASE})"; exit 1; }

    log "Checking storage on prod..."
    prod_ssh "test -d ${STORAGE_BASE}/volumes" \
        && ok "Storage OK on prod" \
        || warn "Storage path not found on prod: ${STORAGE_BASE}/volumes"

    ok "All preflight checks passed"
}
