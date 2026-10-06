#!/usr/bin/env bash
# update_config.sh - Update the dotfiles repository and apply the latest configs

set -Eeuo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

step() {
    echo -e "${BLUE}==>${NC} $1"
}

USE_SYMLINKS=false

for arg in "$@"; do
    case "$arg" in
        --symlink)
            USE_SYMLINKS=true
            ;;

        --help|-h)
            cat <<EOF
Usage: ./update_config.sh [OPTIONS]

Options:
  --symlink     Update using symlinks
  --help, -h    Show this help message
EOF
            exit 0
            ;;

        *)
            error "Unknown option: $arg"
            echo "Use './update_config.sh --help' for usage."
            exit 2
            ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$REPO_ROOT"

if [[ ! -d ".git" ]]; then
    error "This directory is not a Git repository."
    exit 1
fi

if [[ ! -f "install.sh" ]]; then
    error "install.sh was not found."
    exit 1
fi

info "Checking for local changes..."

if [[ -n "$(git status --porcelain)" ]]; then
    error "You have local changes in the repository."
    warn "Commit, stash, or remove them before updating."
    echo
    git status --short
    exit 1
fi

step "Downloading the latest dotfiles"

if ! git pull --ff-only; then
    error "Could not update the repository."
    warn "You may need to resolve the Git issue manually."
    exit 1
fi

INSTALL_ARGS=()

if [[ "$USE_SYMLINKS" == true ]]; then
    info "Applying the configuration using symlinks."
    INSTALL_ARGS+=(--symlink)
else
    info "Applying the configuration as normal copied files."
fi

echo

if [[ -x "./install.sh" ]]; then
    ./install.sh "${INSTALL_ARGS[@]}"
else
    bash ./install.sh "${INSTALL_ARGS[@]}"
fi

echo
info "Dotfiles updated successfully."

if [[ "$USE_SYMLINKS" == true ]]; then
    info "Symlink mode was used."
else
    info "Normal copy mode was used."
fi

info "Restart Hyprland or log out and back in if necessary."