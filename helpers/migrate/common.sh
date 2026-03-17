#!/usr/bin/env bash
# migrate/common.sh — shared config, utilities and domain mapping
# Sourced by the main script and by each phase script.

# =============================================================================
# CONFIGURATION — adjust these values to your environment
# =============================================================================

PROD_HOST="${PROD_HOST:-ada}"                   # production server
TEST_HOST="${TEST_HOST:-cory}"                  # test/staging server
SSH_USER="${SSH_USER:-marc}"                    # sudo-enabled user (NOPASSWD required)
SSH_OPTS="-o StrictHostKeyChecking=no -o BatchMode=yes"

DOJO_BASE="${DOJO_BASE:-/home/docker}"          # dojo base path on both servers
STORAGE_BASE="${STORAGE_BASE:-/srv}"            # persistent storage path

TEST_BASE_DOMAIN="${TEST_BASE_DOMAIN:-precarietat.net}"
TEST_PREFIX="${TEST_PREFIX:-cory}"              # cory-<name>.precarietat.net

DRY_RUN="${DRY_RUN:-false}"
LOG_FILE="${LOG_FILE:-./migration-$(date +%Y%m%d-%H%M%S).log}"

declare -A DOMAIN_MAP=()

# =============================================================================
# COLORS AND LOGGING
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()     { echo -e "${BLUE}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2; }
section() {
    echo -e "\n${CYAN}========================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN} $*${NC}"                                        | tee -a "$LOG_FILE"
    echo -e "${CYAN}========================================${NC}" | tee -a "$LOG_FILE"
}

# =============================================================================
# SSH AND RSYNC HELPERS
# =============================================================================

# prod is always read-only source; test is write target
prod_ssh() { ssh $SSH_OPTS "${SSH_USER}@${PROD_HOST}" "$@"; }
test_ssh() { ssh $SSH_OPTS "${SSH_USER}@${TEST_HOST}" "$@"; }

# rsync from prod to test — executed ON prod, pushed TO test.
# Uses sudo rsync on both sides to handle root-owned files.
# Requires prod to have SSH key access to test (checked in preflight).
#
# Usage: rsync_to_test <src_path_on_prod> <dst_path_on_test> [extra_rsync_flags]
rsync_to_test() {
    local src="$1" dst="$2" extra="${3:-}" dry_flag=""
    [[ "$DRY_RUN" == "true" ]] && dry_flag="--dry-run"
    log "  rsync prod:${src} → test:${dst} ${extra} ${dry_flag}"
    prod_ssh "sudo rsync -az --progress ${dry_flag} ${extra} \
        --rsync-path='sudo rsync' \
        -e 'ssh ${SSH_OPTS}' \
        '${src}' '${SSH_USER}@${TEST_HOST}:${dst}'"
}

# Require literal 'yes' before any destructive action.
confirm_action() {
    local desc="$1"
    echo "" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}  !! CONFIRMATION REQUIRED !!${NC}" | tee -a "$LOG_FILE"
    echo -e "  ${desc}"                                   | tee -a "$LOG_FILE"
    echo ""
    local answer
    read -rp "  Type 'yes' to continue, anything else to abort: " answer
    echo "  User answered: ${answer}" >> "$LOG_FILE"
    if [[ "$answer" != "yes" ]]; then warn "Aborted by user."; exit 0; fi
}

# =============================================================================
# DOMAIN MAPPING
# =============================================================================

GENERIC_SUBDOMAINS=("www" "mail" "ftp" "smtp" "imap" "pop" "pop3" "webmail")

is_generic() {
    local l="$1"
    for g in "${GENERIC_SUBDOMAINS[@]}"; do [[ "$l" == "$g" ]] && return 0; done
    return 1
}

domain_to_shortname() {
    local domain="$1"
    local parts; IFS='.' read -ra parts <<< "$domain"
    if [[ ${#parts[@]} -ge 3 ]]; then
        is_generic "${parts[0]}" && echo "${parts[1]}" || echo "${parts[0]}"
    else
        echo "${parts[0]}"
    fi
}

build_domain_map() {
    [[ ${#DOMAIN_MAP[@]} -gt 0 ]] && return

    log "Reading PROJECT_DOMAIN from prod .env files..."
    local sites
    sites=$(prod_ssh "sudo ls ${DOJO_BASE}/sites/ 2>/dev/null") || {
        warn "Could not list sites on prod — DOMAIN_MAP will be empty"; return
    }

    local collisions=0
    for site in $sites; do
        local prod_domain
        prod_domain=$(prod_ssh \
            "sudo grep -E '^PROJECT_DOMAIN=' '${DOJO_BASE}/sites/${site}/.env' 2>/dev/null \
             | cut -d'=' -f2 | tr -d '\"' | tr -d \"'\" | tr -d ' '") || true

        [[ -z "$prod_domain" ]] && { warn "  [$site] PROJECT_DOMAIN not found — skipping"; continue; }
        [[ -v "DOMAIN_MAP[$prod_domain]" ]] && { warn "  SKIP (duplicate): $prod_domain"; continue; }

        local shortname test_domain
        shortname=$(domain_to_shortname "$prod_domain")
        test_domain="${TEST_PREFIX}-${shortname}.${TEST_BASE_DOMAIN}"

        local conflict=""
        for k in "${!DOMAIN_MAP[@]}"; do
            [[ "${DOMAIN_MAP[$k]}" == "$test_domain" ]] && { conflict="$k"; break; }
        done
        if [[ -n "$conflict" ]]; then
            warn "  COLLISION: '${prod_domain}' and '${conflict}' → '${test_domain}'"
            warn "  → '${prod_domain}' skipped. Edit domain_to_shortname() to resolve."
            collisions=$((collisions + 1)); continue
        fi

        DOMAIN_MAP["$prod_domain"]="$test_domain"
        log "  [$site] $prod_domain  →  $test_domain"
    done

    if [[ ${#DOMAIN_MAP[@]} -eq 0 ]]; then
        warn "No domains mapped — check .env files contain PROJECT_DOMAIN"
    else
        ok "Domain map: ${#DOMAIN_MAP[@]} entries"
        [[ $collisions -gt 0 ]] && warn "${collisions} collision(s) require manual resolution"
    fi
}

apply_domain_map_in_test() {
    local target_dir="$1"
    [[ ${#DOMAIN_MAP[@]} -eq 0 ]] && { warn "DOMAIN_MAP empty — skipping substitutions in ${target_dir}"; return; }
    for prod_domain in "${!DOMAIN_MAP[@]}"; do
        local test_domain="${DOMAIN_MAP[$prod_domain]}"
        log "  Replacing: ${prod_domain} → ${test_domain} in ${target_dir}"
        [[ "$DRY_RUN" == "true" ]] && { warn "  [dry-run] sed skipped"; continue; }
        test_ssh "sudo find '${target_dir}' -type f \
            \( -name '.env' -o -name '*.yml' -o -name '*.yaml' \
            -o -name '*.conf' -o -name '*.php' -o -name '*.ini' \) \
            -exec sudo sed -i 's|${prod_domain}|${test_domain}|g' {} \;"
    done
}
