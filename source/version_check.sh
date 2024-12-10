#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/rocm-driver-update.log"
exec 1> >(tee -a "$LOGFILE") 2>&1

function log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

function error_handler() {
    local line_no=$1
    local error_code=$2
    log "ERROR: Command failed at line ${line_no} with exit code ${error_code}"
    notify_failure "Update process failed at line ${line_no}"
}

trap 'error_handler ${LINENO} $?' ERR

function check_dependencies() {
    local deps=(curl jq git sed grep)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log "ERROR: Required dependency '$dep' is not installed"
            exit 1
        fi
    done
}

function validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "ERROR: Invalid version format: $version"
        return 1
    fi
    return 0
}

function check_rocm_versions() {
    if [[ ! -f "source/versions.yml" ]]; then
        log "ERROR: versions.yml not found"
        exit 1
    fi

    CURRENT_ROCM=$(grep "version:" source/versions.yml | head -1 | cut -d'"' -f2)
    if [[ -z "$CURRENT_ROCM" ]]; then
        log "ERROR: Could not determine current ROCm version"
        exit 1
    fi
    
    local max_attempts=3
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        LATEST_ROCM=$(curl -sf "https://github.com/RadeonOpenCompute/ROCm/releases/latest" | grep -o 'tag/[v.0-9]*' | cut -d/ -f2)
        if [[ -n "$LATEST_ROCM" ]]; then
            break
        fi
        log "Attempt $attempt to fetch latest version failed, retrying..."
        sleep 5
        ((attempt++))
    done

    if [[ -z "$LATEST_ROCM" ]]; then
        log "ERROR: Failed to fetch latest ROCm version after $max_attempts attempts"
        exit 1
    fi

    if ! validate_version "$CURRENT_ROCM" || ! validate_version "$LATEST_ROCM"; then
        exit 1
    fi

    if [[ "$LATEST_ROCM" != "$CURRENT_ROCM" ]]; then
        log "New ROCm version available: $LATEST_ROCM (current: $CURRENT_ROCM)"
        
        cp source/versions.yml source/versions.yml.bak
        cp source/compile.sh source/compile.sh.bak
        
        if ! sed -i.bak "s/version: \"$CURRENT_ROCM\"/version: \"$LATEST_ROCM\"/" source/versions.yml; then
            log "ERROR: Failed to update versions.yml"
            restore_backups
            exit 1
        fi
        
        if ! sed -i.bak "s/ROCM_VERSION=\"$CURRENT_ROCM\"/ROCM_VERSION=\"$LATEST_ROCM\"/" source/compile.sh; then
            log "ERROR: Failed to update compile.sh"
            restore_backups
            exit 1
        fi
        
        create_update_pr "$LATEST_ROCM"
    else
        log "ROCm version is up to date ($CURRENT_ROCM)"
    fi
}

function restore_backups() {
    log "Restoring backups due to error"
    [[ -f source/versions.yml.bak ]] && mv source/versions.yml.bak source/versions.yml
    [[ -f source/compile.sh.bak ]] && mv source/compile.sh.bak source/compile.sh
}

function create_update_pr() {
    local new_version=$1
    local branch="update-rocm-${new_version}"
    local title="Update ROCm to version ${new_version}"
    
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log "ERROR: GITHUB_TOKEN is not set"
        exit 1
    fi

    local response
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"ref\": \"refs/heads/$branch\",
            \"sha\": \"$(git rev-parse HEAD)\"
        }" \
        "https://api.github.com/repos/a-0e/unraid-rocm-driver/git/refs")
    
    local http_code=${response: -3}
    if [[ $http_code -ne 201 ]]; then
        log "ERROR: Failed to create branch (HTTP $http_code)"
        log "Response: ${response:0:-3}"
        exit 1
    fi

    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"$title\",
            \"head\": \"$branch\",
            \"base\": \"master\",
            \"body\": \"Automated update of ROCm to version ${new_version}\n\n- [ ] Tested with supported GPUs\n- [ ] Updated documentation\"
        }" \
        "https://api.github.com/repos/a-0e/unraid-rocm-driver/pulls")
    
    http_code=${response: -3}
    if [[ $http_code -ne 201 ]]; then
        log "ERROR: Failed to create PR (HTTP $http_code)"
        log "Response: ${response:0:-3}"
        exit 1
    fi

    log "Successfully created PR for ROCm $new_version"
}

function notify_failure() {
    local message=$1
    curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"Update Process Failed\",
            \"body\": \"$message\n\nCheck logs for more details.\",
            \"labels\": [\"bug\", \"automated-update\"]
        }" \
        "https://api.github.com/repos/a-0e/unraid-rocm-driver/issues"
}

log "Starting ROCm version check"
check_dependencies
check_rocm_versions
log "Version check completed successfully"