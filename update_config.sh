#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$HOME/dot-files"

if ! git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[ERROR] $REPO_DIR is not a Git repository."
    exit 1
fi

if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
    echo "[ERROR] Local changes in $REPO_DIR; refusing to update."
    echo "Commit, stash, or remove them first:"
    git -C "$REPO_DIR" status --short
    exit 1
fi

echo "[INFO] Updating dot-files from GitHub..."
git -C "$REPO_DIR" pull --ff-only origin main

echo "[INFO] Applying the updated configs..."
exec bash "$REPO_DIR/install.sh" "$@"
