#!/usr/bin/env bash
# =============================================================================
# migrate-prod-to-test.sh
# Migrate dojo containers: production → test/staging
#
# DIRECTION: prod → test only. Data flow is strictly one-way.
#            Nothing is ever written back to production.
#
# Usage:
#   ./migrate-prod-to-test.sh [--help] [--dry-run] [--phase PHASE]
#
# Phases:
#   inventory   - List services on prod (read-only)
#   domains     - Show prod → test domain mapping table (read-only)
#   infra       - Sync docker-compose, .env and config files to test
#   volumes     - Sync data volumes to test
#   images      - Export/import non-public Docker images
#   start       - Start containers on test
#   verify      - Verify post-migration state on test
#   all         - Run all phases in order (default)
#
# Configuration (override via env vars or edit migrate/common.sh):
#   PROD_HOST          production server     (default: ada)
#   TEST_HOST          test/staging server   (default: cory)
#   SSH_USER           sudo user             (default: marc)
#   DOJO_BASE          dojo base path        (default: /home/docker)
#   STORAGE_BASE       storage path          (default: /srv)
#   TEST_BASE_DOMAIN   test base domain      (default: precarietat.net)
#   TEST_PREFIX        test subdomain prefix (default: cory)
#
# Requirements:
#   - SSH key access from LOCAL to prod and test (user SSH_USER, NOPASSWD sudo)
#   - SSH key access from PROD to TEST (for rsync push — checked in preflight)
#
# Examples:
#   ./migrate-prod-to-test.sh --phase inventory
#   ./migrate-prod-to-test.sh --dry-run --phase infra
#   ./migrate-prod-to-test.sh --phase all
#   PROD_HOST=myserver ./migrate-prod-to-test.sh --phase domains
# =============================================================================

set -euo pipefail

# Resolve script directory so sources work regardless of where the script is called from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATE_DIR="${SCRIPT_DIR}/migrate"

# =============================================================================
# SOURCE MODULES
# =============================================================================

# shellcheck source=migrate/common.sh
source "${MIGRATE_DIR}/common.sh"
# shellcheck source=migrate/preflight.sh
source "${MIGRATE_DIR}/preflight.sh"
# shellcheck source=migrate/inventory.sh
source "${MIGRATE_DIR}/inventory.sh"
# shellcheck source=migrate/domains.sh
source "${MIGRATE_DIR}/domains.sh"
# shellcheck source=migrate/infra.sh
source "${MIGRATE_DIR}/infra.sh"
# shellcheck source=migrate/volumes.sh
source "${MIGRATE_DIR}/volumes.sh"
# shellcheck source=migrate/images.sh
source "${MIGRATE_DIR}/images.sh"
# shellcheck source=migrate/start.sh
source "${MIGRATE_DIR}/start.sh"
# shellcheck source=migrate/verify.sh
source "${MIGRATE_DIR}/verify.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

PHASE="all"

usage() { grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'; exit 0; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage ;;
        --dry-run) DRY_RUN=true ;;
        --phase)   PHASE="$2"; shift ;;
        *) error "Unknown argument: $1"; exit 1 ;;
    esac
    shift
done

export DRY_RUN LOG_FILE

[[ "$DRY_RUN" == "true" ]] && warn "Dry-run mode — no changes will be made on test"

# =============================================================================
# MAIN
# =============================================================================

echo "=============================================" | tee  "$LOG_FILE"
echo " migrate-prod-to-test.sh"                      | tee -a "$LOG_FILE"
echo " $(date)"                                      | tee -a "$LOG_FILE"
echo " Phase    : $PHASE | Dry-run: $DRY_RUN"        | tee -a "$LOG_FILE"
echo " Direction: prod (${PROD_HOST}) → test (${TEST_HOST}) ONLY" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"

phase_preflight

case "$PHASE" in
    inventory) phase_inventory ;;
    domains)   phase_domains ;;
    infra)     phase_infra ;;
    volumes)   phase_volumes ;;
    images)    phase_images ;;
    start)     phase_start ;;
    verify)    phase_verify ;;
    all)
        phase_inventory
        phase_domains
        phase_infra
        phase_images
        phase_volumes
        phase_start
        phase_verify
        ;;
    *)
        error "Unknown phase: $PHASE"
        echo "Available: inventory, domains, infra, volumes, images, start, verify, all"
        exit 1
        ;;
esac

section "Migration complete"
ok "Full log at: $LOG_FILE"
