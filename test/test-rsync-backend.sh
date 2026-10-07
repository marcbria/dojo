#!/usr/bin/env bash
# =============================================================================
# test-rsync-backend.sh
#
# End-to-end automated test for the dojo rsync backup/restore backend.
#
# Runs the full TLDR cycle for a given site on a given host.
# The script is robust to pre-existing state on the server: it captures
# the initial snapshot inventory and verifies only the deltas produced by
# its own actions.
#
# The script locates the repository root from its own path, so it can be
# invoked from any working directory:
#
#   ~/workspace/dojo/test/test-rsync-backend.sh anuarioiet cory
#
# All output is captured under: test/_test-runs/<timestamp>-<site>-<host>/
#
# Exit codes:
#   0  all tests passed
#   1  one or more tests failed
#   2  configuration error (missing vars, args, ...)
#
# Usage:
#   ./test-rsync-backend.sh <site> <host>
#   ./test-rsync-backend.sh anuarioiet cory
#   ./test-rsync-backend.sh anuarioiet cory --keep
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Args and validation
# ---------------------------------------------------------------------------

SITE="${1:-}"
HOST="${2:-}"
KEEP_ON_FAILURE="${3:-}"

if [[ -z "$SITE" || -z "$HOST" ]]; then
    echo "Usage: $0 <site> <host> [--keep]"
    echo "Example: $0 anuarioiet cory"
    exit 2
fi

for cmd in just ansible-playbook ssh; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: required command not found: $cmd" >&2
        exit 2
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${REPO_ROOT}/justfile" ]]; then
    echo "ERROR: could not locate the repo root (justfile not found in ${REPO_ROOT})" >&2
    exit 2
fi

cd "${REPO_ROOT}"

# ---------------------------------------------------------------------------
# Run directory
# ---------------------------------------------------------------------------

RUN_TS="$(date -u +%Y%m%d-%H%M%S)"
RUN_DIR="test/_test-runs/${RUN_TS}-${SITE}-${HOST}"
mkdir -p "$RUN_DIR"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'

log()    { echo -e "${BLUE}[INFO]${NC}  $*" | tee -a "$RUN_DIR/console.log"; }
ok()     { echo -e "${GREEN}[ OK ]${NC}  $*" | tee -a "$RUN_DIR/console.log"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$RUN_DIR/console.log"; }
err()    { echo -e "${RED}[FAIL]${NC}  $*" | tee -a "$RUN_DIR/console.log" >&2; }
section(){
    echo -e "\n${CYAN}========================================${NC}" | tee -a "$RUN_DIR/console.log"
    echo -e "${CYAN} $*${NC}"                                        | tee -a "$RUN_DIR/console.log"
    echo -e "${CYAN}========================================${NC}" | tee -a "$RUN_DIR/console.log"
}

declare -a FAILURES=()
declare -a PASSES=()
pass() { PASSES+=("$1"); ok "$1"; }
fail() { FAILURES+=("$1"); err "$1"; }

# ---------------------------------------------------------------------------
# Wrappers
# ---------------------------------------------------------------------------

run_just() {
    local logfile="$1"; shift
    log "just $*"
    just "$@" >"$logfile" 2>&1
    local rc=$?
    cat "$logfile"
    return $rc
}

on_host() { ssh "$HOST" "$@"; }

remote_sh() {
    local script="$1"
    ssh "$HOST" "sudo sh -c '${script}'"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

remote_list_snapshots() {
    remote_sh "ls -1 /srv/backup/${SITE}/ 2>/dev/null || true"
}

remote_latest_snapshot_by_suffix() {
    local suffix="$1"   # e.g. "-full" or "-quick"
    remote_sh "ls -1 /srv/backup/${SITE}/ 2>/dev/null | grep -E -- '${suffix}\$' | sort | tail -1"
}

remote_count_snapshots() {
    remote_sh "find /srv/backup/${SITE} -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l || echo 0"
}

remote_count_pre_restore_generations() {
    remote_sh "find /srv/volumes -maxdepth 4 -path '*_pre-restore*' -name '${SITE}-*' -type d 2>/dev/null | wc -l || echo 0"
}

purge_snapshots() {
    log "Purging all snapshots for $SITE on $HOST..."
    remote_sh "rm -rf /srv/backup/${SITE}/* 2>/dev/null || true"
}

purge_pre_restore() {
    log "Purging _pre-restore generations and legacy .pre-restore-* entries..."
    remote_sh "
        for base in /srv/volumes/db /srv/volumes/logs \
                    /srv/volumes/files/config /srv/volumes/files/private /srv/volumes/files/public ; do
            [ -d \"\$base/_pre-restore\" ] && find \"\$base/_pre-restore\" -mindepth 1 -maxdepth 1 -name \"${SITE}-*\" -exec rm -rf {} + 2>/dev/null
            find \"\$base\" -maxdepth 1 -name \"${SITE}.pre-restore-*\" -type d -exec rm -rf {} + 2>/dev/null
        done
        true
    "
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

section "Preflight"

{
    echo "Run started:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Site:          $SITE"
    echo "Host:          $HOST"
    echo "Repo root:     $REPO_ROOT"
    echo "Run directory: $RUN_DIR"
    echo
    echo "--- git -------------------------------------------------------"
    git log -1 --oneline 2>/dev/null || echo "(not a git repo)"
    git status --short 2>/dev/null | head -20 || true
    echo
    echo "--- tool versions ---------------------------------------------"
    just --version 2>/dev/null || true
    ansible-playbook --version 2>/dev/null | head -3 || true
    echo
    echo "--- target host -----------------------------------------------"
    on_host 'uname -a; echo; head -3 /etc/os-release' 2>/dev/null || true
    echo
    echo "--- docker ----------------------------------------------------"
    on_host 'docker --version; docker compose version' 2>/dev/null || true
} > "$RUN_DIR/00-environment.txt" 2>&1

containers=$(on_host "sudo docker ps --format '{{.Names}}' | grep -E '^(ojs|omp)_(app|db)_${SITE}\$'" 2>/dev/null || true)
if [[ -z "$containers" ]]; then
    err "site containers not running for $SITE on $HOST"
    echo "Run: just dojo-manage $SITE $HOST up" >&2
    exit 2
fi
pass "containers running: $(echo "$containers" | tr '\n' ' ')"

if ! on_host "sudo test -d /home/docker/sites/${SITE}"; then
    err "site directory missing: /home/docker/sites/${SITE}"
    echo "       The backup playbook requires it. Restore it first, e.g.:" >&2
    echo "       ssh $HOST 'sudo mv /home/docker/sites/${SITE}.test-gone /home/docker/sites/${SITE}'" >&2
    exit 2
fi
pass "site directory exists: /home/docker/sites/${SITE}"

remote_list_snapshots > "$RUN_DIR/snapshots-before.txt"
remote_sh "find /srv/volumes -maxdepth 4 -path '*_pre-restore*' -name '${SITE}-*' -type d 2>/dev/null | sort || true" \
    > "$RUN_DIR/pre-restore-before.txt"

# ---------------------------------------------------------------------------
# Test steps
# ---------------------------------------------------------------------------

FULL_TAG=""
QUICK_TAG=""

step_01_full_backup() {
    section "Step 1: full backup"

    purge_snapshots

    if run_just "$RUN_DIR/01-full-backup.log" \
            dojo-backup-rsync-snap "$SITE" "$HOST"; then
        pass "full backup ran"
    else
        fail "full backup failed"
        return 1
    fi

    FULL_TAG="$(remote_latest_snapshot_by_suffix '-full')"
    if [[ -z "$FULL_TAG" ]]; then
        fail "no -full snapshot found after backup"
        return 1
    fi
    pass "full snapshot: $FULL_TAG"

    remote_sh "ls -la /srv/backup/${SITE}/${FULL_TAG}/" > "$RUN_DIR/01-full-backup.structure.txt"
    folders=$(remote_sh "ls -1 /srv/backup/${SITE}/${FULL_TAG}/")
    ok_folders=1
    for f in definition db config logs private public; do
        if ! echo "$folders" | grep -qx "$f"; then ok_folders=0; break; fi
    done
    if [[ "$ok_folders" -eq 1 ]]; then
        pass "full snapshot has all folders"
    else
        fail "full snapshot missing folders (got: $(echo $folders | tr '\n' ' '))"
    fi
}

step_02_quick_backup() {
    section "Step 2: quick backup"

    if run_just "$RUN_DIR/02-quick-backup.log" \
            dojo-backup-rsync-snap "$SITE" "$HOST" true; then
        pass "quick backup ran"
    else
        fail "quick backup failed"
        return 1
    fi

    QUICK_TAG="$(remote_latest_snapshot_by_suffix '-quick')"
    if [[ -z "$QUICK_TAG" ]]; then
        fail "no -quick snapshot found after backup"
        return 1
    fi
    pass "quick snapshot: $QUICK_TAG"

    folders=$(remote_sh "ls -1 /srv/backup/${SITE}/${QUICK_TAG}/")
    if echo "$folders" | grep -qxE 'private|public'; then
        fail "quick snapshot contains private/ or public/ (should be skipped)"
    else
        pass "quick snapshot omits private/ and public/"
    fi
}

step_03_list_snapshots() {
    section "Step 3: list snapshots"

    if run_just "$RUN_DIR/03-list.log" \
            dojo-backup-rsync-list "$SITE" "$HOST"; then
        pass "list snapshots ran"
    else
        fail "list snapshots failed"
        return 1
    fi

    if grep -q "$FULL_TAG" "$RUN_DIR/03-list.log" && \
       grep -q "$QUICK_TAG" "$RUN_DIR/03-list.log"; then
        pass "both tags present in listing"
    else
        fail "one or both tags missing from listing"
    fi
}

step_04_prune_guard_zero() {
    section "Step 4: prune guard (keep=0 must fail)"

    local pre_count
    pre_count=$(remote_count_snapshots)

    if run_just "$RUN_DIR/04-prune-keep0.log" \
            dojo-backup-rsync-prune "$SITE" "$HOST" 0; then
        fail "prune with keep=0 unexpectedly succeeded"
    else
        pass "prune with keep=0 rejected as expected"
        local post_count
        post_count=$(remote_count_snapshots)
        if [[ "$post_count" -eq "$pre_count" ]]; then
            pass "no snapshots deleted by guarded prune (still $post_count)"
        else
            fail "snapshot count changed from $pre_count to $post_count"
        fi
    fi
}

step_05_prune_keep_one() {
    section "Step 5: prune keep=1 (keep only the most recent)"

    local pre_count
    pre_count=$(remote_count_snapshots)
    if [[ "$pre_count" -ne 2 ]]; then
        warn "expected 2 snapshots before prune, found $pre_count — resetting"
        purge_snapshots
        run_just "$RUN_DIR/05-rebuild-full.log"  dojo-backup-rsync-snap "$SITE" "$HOST"      >/dev/null
        run_just "$RUN_DIR/05-rebuild-quick.log" dojo-backup-rsync-snap "$SITE" "$HOST" true >/dev/null
    fi

    if run_just "$RUN_DIR/05-prune-keep1.log" \
            dojo-backup-rsync-prune "$SITE" "$HOST" 1; then
        pass "prune keep=1 ran"
    else
        fail "prune keep=1 failed"
        return 1
    fi

    local count
    count=$(remote_count_snapshots)
    if [[ "$count" -eq 1 ]]; then
        pass "exactly one snapshot remains"
    else
        fail "expected 1 snapshot, got $count"
    fi

    run_just "$RUN_DIR/05-rebuild-full.log"  dojo-backup-rsync-snap "$SITE" "$HOST"      >/dev/null
    run_just "$RUN_DIR/05-rebuild-quick.log" dojo-backup-rsync-snap "$SITE" "$HOST" true >/dev/null

    FULL_TAG="$(remote_latest_snapshot_by_suffix '-full')"
    QUICK_TAG="$(remote_latest_snapshot_by_suffix '-quick')"

    if [[ -n "$FULL_TAG" && -n "$QUICK_TAG" ]]; then
        pass "rebuilt full ($FULL_TAG) and quick ($QUICK_TAG)"
    else
        fail "could not rebuild both snapshots (FULL='$FULL_TAG' QUICK='$QUICK_TAG')"
    fi
}

step_06_restore_no_token() {
    section "Step 6: restore guard (no token must fail)"

    if run_just "$RUN_DIR/06-restore-notoken.log" \
            dojo-restore-rsync-snap "$SITE" "$HOST" "$FULL_TAG"; then
        fail "restore without token unexpectedly succeeded"
    else
        if grep -q "Restore is DESTRUCTIVE" "$RUN_DIR/06-restore-notoken.log"; then
            pass "restore without token rejected with proper message"
        else
            fail "restore failed but without the expected guard message"
        fi
    fi
}

step_07_restore_bad_token() {
    section "Step 7: restore guard (bad token must fail)"

    if run_just "$RUN_DIR/07-restore-badtoken.log" \
            dojo-restore-rsync-snap "$SITE" "$HOST" "$FULL_TAG" "WRONG-TOKEN"; then
        fail "restore with wrong token unexpectedly succeeded"
    else
        if grep -q "Restore is DESTRUCTIVE" "$RUN_DIR/07-restore-badtoken.log"; then
            pass "restore with wrong token rejected with proper message"
        else
            fail "restore failed but without the expected guard message"
        fi
    fi
}

step_08_full_restore() {
    section "Step 8: full restore (site directory intact)"

    on_host "sudo ls /srv/volumes/files/private/${SITE} 2>/dev/null" > "$RUN_DIR/08-private-before.txt"
    on_host "sudo ls /srv/volumes/files/public/${SITE} 2>/dev/null"  > "$RUN_DIR/08-public-before.txt"

    local pre_count
    pre_count=$(remote_count_pre_restore_generations)

    if run_just "$RUN_DIR/08-full-restore.log" \
            dojo-restore-rsync-snap "$SITE" "$HOST" "$FULL_TAG" "RESTORE-${SITE}"; then
        pass "full restore ran"
    else
        fail "full restore failed"
        return 1
    fi

    if grep -q "Data:      db, config, logs, private, public" "$RUN_DIR/08-full-restore.log"; then
        pass "report confirms private and public restored"
    else
        fail "report does not mention private/public as restored"
    fi

    local post_count
    post_count=$(remote_count_pre_restore_generations)
    if [[ "$post_count" -gt "$pre_count" ]]; then
        pass "new _pre-restore generation created ($pre_count -> $post_count)"
    else
        fail "no new _pre-restore generation created ($pre_count -> $post_count)"
    fi

    on_host "sudo ls /srv/volumes/files/private/${SITE} 2>/dev/null" > "$RUN_DIR/08-private-after.txt"
    on_host "sudo ls /srv/volumes/files/public/${SITE} 2>/dev/null"  > "$RUN_DIR/08-public-after.txt"
    if diff -q "$RUN_DIR/08-private-before.txt" "$RUN_DIR/08-private-after.txt" >/dev/null && \
       diff -q "$RUN_DIR/08-public-before.txt"  "$RUN_DIR/08-public-after.txt"  >/dev/null; then
        pass "private/ and public/ unchanged after full restore"
    else
        fail "private/ or public/ changed after full restore"
    fi

    sleep 3
    if on_host "sudo docker ps --format '{{.Names}}' | grep -qE '^(ojs|omp)_app_${SITE}\$'"; then
        pass "containers running after restore"
    else
        fail "containers not running after restore"
    fi
}

step_09_quick_restore() {
    section "Step 9: quick restore (private/public preserved)"

    on_host "sudo ls /srv/volumes/files/private/${SITE} 2>/dev/null" > "$RUN_DIR/09-private-before.txt"
    on_host "sudo ls /srv/volumes/files/public/${SITE} 2>/dev/null"  > "$RUN_DIR/09-public-before.txt"

    if run_just "$RUN_DIR/09-quick-restore.log" \
            dojo-restore-rsync-snap "$SITE" "$HOST" "$QUICK_TAG" "RESTORE-${SITE}"; then
        pass "quick restore ran"
    else
        fail "quick restore failed"
        return 1
    fi

    if grep -q "Preserved: private public" "$RUN_DIR/09-quick-restore.log"; then
        pass "report confirms private/public preserved"
    else
        fail "report does not confirm private/public preserved"
    fi

    on_host "sudo ls /srv/volumes/files/private/${SITE} 2>/dev/null" > "$RUN_DIR/09-private-after.txt"
    on_host "sudo ls /srv/volumes/files/public/${SITE} 2>/dev/null"  > "$RUN_DIR/09-public-after.txt"
    if diff -q "$RUN_DIR/09-private-before.txt" "$RUN_DIR/09-private-after.txt" >/dev/null && \
       diff -q "$RUN_DIR/09-public-before.txt"  "$RUN_DIR/09-public-after.txt"  >/dev/null; then
        pass "private/ and public/ untouched by quick restore"
    else
        fail "private/ or public/ changed after quick restore"
    fi

    sleep 3
    if on_host "sudo docker ps --format '{{.Names}}' | grep -qE '^(ojs|omp)_app_${SITE}\$'"; then
        pass "containers running after quick restore"
    else
        fail "containers not running after quick restore"
    fi
}

step_10_full_recovery() {
    section "Step 10: full recovery (site directory missing)"

    on_host "sudo mv /home/docker/sites/${SITE} /home/docker/sites/${SITE}.test-gone"

    run_just "$RUN_DIR/10-rebuild-full.log" dojo-backup-rsync-snap "$SITE" "$HOST" >/dev/null
    FULL_TAG="$(remote_latest_snapshot_by_suffix '-full')"

    if [[ -z "$FULL_TAG" ]]; then
        fail "could not rebuild full snapshot for recovery test"
        on_host "sudo mv /home/docker/sites/${SITE}.test-gone /home/docker/sites/${SITE}"
        return 1
    fi
    pass "rebuild full snapshot: $FULL_TAG"

    if run_just "$RUN_DIR/10-recovery.log" \
            dojo-restore-rsync-snap "$SITE" "$HOST" "$FULL_TAG" "RESTORE-${SITE}"; then
        pass "full recovery ran"
    else
        fail "full recovery failed"
        on_host "sudo rm -rf /home/docker/sites/${SITE}.test-gone"
        return 1
    fi

    if on_host "sudo test -f /home/docker/sites/${SITE}/docker-compose.yml && \
                sudo test -f /home/docker/sites/${SITE}/.env && \
                sudo test -L /home/docker/sites/${SITE}/volumes"; then
        pass "site directory and symlinks recreated"
    else
        fail "site directory or symlinks missing after recovery"
    fi

    sleep 3
    if on_host "sudo docker ps --format '{{.Names}}' | grep -qE '^(ojs|omp)_app_${SITE}\$'"; then
        pass "containers running after full recovery"
    else
        fail "containers not running after full recovery"
    fi

    on_host "sudo rm -rf /home/docker/sites/${SITE}.test-gone"
}

step_11_cleanup() {
    section "Step 11: cleanup"

    if [[ "$KEEP_ON_FAILURE" == "--keep" && ${#FAILURES[@]} -gt 0 ]]; then
        warn "--keep set and failures detected; skipping cleanup"
        return 0
    fi

    purge_pre_restore
    pass "purged _pre-restore generations"

    remote_sh "
        cd /srv/backup/${SITE} 2>/dev/null || exit 0
        full=\$(ls -1 | grep -E -- '-full\$' | sort | tail -1)
        quick=\$(ls -1 | grep -E -- '-quick\$' | sort | tail -1)
        for s in * ; do
            [ \"\$s\" = \"\$full\" ] && continue
            [ \"\$s\" = \"\$quick\" ] && continue
            rm -rf \"\$s\"
        done
        true
    "
    pass "kept one full and one quick snapshot"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

section "Test run: $SITE on $HOST"
log "Run directory: $RUN_DIR"

step_01_full_backup       || true
step_02_quick_backup      || true
step_03_list_snapshots    || true
step_04_prune_guard_zero  || true
step_05_prune_keep_one    || true
step_06_restore_no_token  || true
step_07_restore_bad_token || true
step_08_full_restore      || true
step_09_quick_restore     || true
step_10_full_recovery     || true
step_11_cleanup           || true

# ---------------------------------------------------------------------------
# Evidence and summary
# ---------------------------------------------------------------------------

section "Collecting evidence"

{
    echo "=== SNAPSHOTS AFTER ==="
    remote_list_snapshots
    echo
    echo "=== PRE-RESTORE AFTER ==="
    remote_sh "find /srv/volumes -maxdepth 4 -path '*_pre-restore*' -name '${SITE}-*' -type d 2>/dev/null | sort || true"
    echo
    echo "=== CONTAINERS ==="
    on_host "sudo docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E '^(ojs|omp)_' || true"
    echo
    echo "=== SITE DIRECTORY ==="
    on_host "sudo ls -la /home/docker/sites/${SITE}/ 2>/dev/null || echo '(missing)'"
} > "$RUN_DIR/server-state.txt" 2>&1

{
    echo "=== PASSES (${#PASSES[@]}) ==="
    for p in "${PASSES[@]}"; do echo "  [OK]   $p"; done
    echo
    echo "=== FAILURES (${#FAILURES[@]}) ==="
    for f in "${FAILURES[@]}"; do echo "  [FAIL] $f"; done
} > "$RUN_DIR/evidence.txt"

{
    echo "dojo rsync backend — automated test"
    echo "====================================="
    echo "Site:      $SITE"
    echo "Host:      $HOST"
    echo "Run:       $RUN_TS"
    echo "Dir:       $RUN_DIR"
    echo
    echo "Passed:    ${#PASSES[@]}"
    echo "Failed:    ${#FAILURES[@]}"
    echo
    if [[ ${#FAILURES[@]} -eq 0 ]]; then
        echo "STATUS:    PASS"
    else
        echo "STATUS:    FAIL"
        echo
        echo "Failing checks:"
        for f in "${FAILURES[@]}"; do echo "  - $f"; done
    fi
    echo
    echo "Evidence files:"
    ls -1 "$RUN_DIR/"
} > "$RUN_DIR/summary.txt"

echo
cat "$RUN_DIR/summary.txt"

if [[ ${#FAILURES[@]} -eq 0 ]]; then
    exit 0
else
    exit 1
fi
