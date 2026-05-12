#!/usr/bin/env zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT/skills/llzz"
TARGET_DIR="${CODEX_HOME:-$HOME/.codex}/skills/llzz"

if [[ ! -f "$SOURCE_DIR/SKILL.md" ]]; then
  echo "Source skill not found: $SOURCE_DIR/SKILL.md" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET_DIR")"

if [[ -e "$TARGET_DIR" ]]; then
  BACKUP_DIR="$TARGET_DIR.backup.$(date +%Y%m%d%H%M%S)"
  mv "$TARGET_DIR" "$BACKUP_DIR"
  echo "Backed up existing skill to: $BACKUP_DIR"
fi

cp -R "$SOURCE_DIR" "$TARGET_DIR"

echo "Installed llzz skill to: $TARGET_DIR"
