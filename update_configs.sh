#!/usr/bin/env bash
# update_configs.sh - Update the dotfiles repository and apply the latest configs

set -Eeuo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

info "Downloading the latest dotfiles..."

if ! git pull --ff-only; then
    error "Could not update the repository."
    warn "You may need to resolve the Git issue manually."
    exit 1
fi

info "Applying the updated configuration files..."

if [[ -x "./install.sh" ]]; then
    ./install.sh
else
    bash ./install.sh
fi

echo
info "Dotfiles updated successfully."
info "Restart Hyprland or log out and back in if necessary."