#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/sakurelle/ACCAC.git}"
TARGET_DIR="${TARGET_DIR:-ACCAC}"
BRANCH="${BRANCH:-main}"

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git command not found" >&2
  exit 1
fi

if [ -d "$TARGET_DIR/.git" ]; then
  git -C "$TARGET_DIR" pull --ff-only
elif [ ! -d "$TARGET_DIR" ]; then
  git clone --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"
fi

cd "$TARGET_DIR"

if [ ! -f "./install_accac.sh" ]; then
  echo "ERROR: install_accac.sh not found in $TARGET_DIR" >&2
  exit 1
fi

chmod +x install_accac.sh
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x db/postgresql/run_all.sh 2>/dev/null || true
chmod +x tests/jmeter/run_accac_db_limits.sh 2>/dev/null || true

./install_accac.sh
