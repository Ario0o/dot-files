#!/usr/bin/env bash

set -Eeuo pipefail

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

info() {
    printf "%b[INFO]%b %s\n" "$GREEN" "$NC" "$1"
}

warn() {
    printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"
}

error() {
    printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1"
}

step() {
    printf "%b==>%b %s\n" "$BLUE" "$NC" "$1"
}

if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root."
    exit 1
fi

readonly DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SRC="$DOTFILES/dotfiles/.config"
readonly THEMES_SRC="$DOTFILES/dotfiles/.themes"

USE_SYMLINKS=false
TARGET_DIR=""

for arg in "$@"; do
    case "$arg" in
        --symlink)
            USE_SYMLINKS=true
            ;;

        --help|-h)
            cat <<EOF
Usage: ./update_config.sh [OPTIONS] [DIRECTORY]

Options:
  --symlink     Update as symlinks instead of copies
  --help, -h    Show this help message

Arguments:
  DIRECTORY     Path to update (default: current directory)
EOF
            exit 0
            ;;

        -*)
            error "Unknown option: $arg"
            printf "Use './update_config.sh --help' for usage.\n"
            exit 2
            ;;

        *)
            TARGET_DIR="$arg"
            ;;
    esac
done

TARGET_DIR="${TARGET_DIR:-.}"

validate_repo() {
    local repo_path="$1"

    step "Validating repository: $repo_path"

    if [[ ! -d "$repo_path" ]]; then
        error "Directory does not exist: $repo_path"
        return 1
    fi

    if [[ ! -d "$repo_path/.git" ]]; then
        error "Not a Git repository: $repo_path"
        return 1
    fi

    if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        error "Cannot access Git repository: $repo_path"
        return 1
    fi

    info "Git repository validated."
}

check_git_state() {
    local repo_path="$1"

    step "Checking Git state"

    if ! git -C "$repo_path" diff --quiet; then
        error "Uncommitted changes detected in working directory."
        error "Please commit or stash your changes before updating."
        return 1
    fi

    if ! git -C "$repo_path" diff --cached --quiet; then
        error "Staged changes detected."
        error "Please commit or unstage your changes before updating."
        return 1
    fi

    if [[ -n "$(git -C "$repo_path" ls-files --others --exclude-standard)" ]]; then
        warn "Untracked files detected in repository."
        warn "These will not be affected by updates."
    fi

    info "Git state is clean."
}

main() {
    if ! validate_repo "$TARGET_DIR"; then
        exit 1
    fi

    if ! check_git_state "$TARGET_DIR"; then
        exit 1
    fi

    printf "\n"
    if [[ "$USE_SYMLINKS" == true ]]; then
        info "Repository is ready for symlink updates."
    else
        info "Repository is ready for updates."
    fi
}

main "$@"