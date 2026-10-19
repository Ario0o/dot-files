#!/usr/bin/env bash

set -Eeuo pipefail

# Script metadata
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="${1:-.}"  # Allow override via first argument, default to current dir

# Functions #

# Print error message and exit
error() {
    local -r message="$1"
    local -r exit_code="${2:-1}"
    printf "[ERROR] %s\n" "$message" >&2
    exit "$exit_code"
}

# Print informational message
info() {
    local -r message="$1"
    printf "[INFO] %s\n" "$message"
}

# Print warning message
warn() {
    local -r message="$1"
    printf "[WARN] %s\n" "$message" >&2
}

# Validate inputs
validate_inputs() {
    if [[ ! -d "$REPO_DIR" ]]; then
        error "Directory does not exist: $REPO_DIR"
    fi
}

# Check if directory is a Git repository
is_git_repo() {
    git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Check for uncommitted changes
has_uncommitted_changes() {
    [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]
}

# Display uncommitted changes
show_uncommitted_changes() {
    printf "\nUncommitted changes:\n"
    git -C "$REPO_DIR" status --short
}

# Main validation logic
main() {
    info "Validating repository: $REPO_DIR"
    
    # Validate inputs
    validate_inputs
    
    # Check if it's a Git repository
    if ! is_git_repo; then
        error "$REPO_DIR is not a valid Git repository"
    fi
    info "✓ Valid Git repository"
    
    # Check for uncommitted changes
    if has_uncommitted_changes; then
        warn "Uncommitted changes detected in $REPO_DIR"
        show_uncommitted_changes
        printf "\nPlease commit, stash, or remove these changes before proceeding.\n" >&2
        exit 1
    fi
    info "✓ No uncommitted changes"
    
    # Success
    info "Repository validation passed"
    exit 0
}

# Entry Point #

main "$@"