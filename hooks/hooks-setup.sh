#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_DIR/hooks"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$BIN_DIR"

symlink() {
  local src="$1"
  local dst="$2"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    echo "warning: $dst exists and is not a symlink — skipping"
    return
  fi
  ln -s "$src" "$dst"
  echo "linked: $dst -> $src"
}

symlink "$HOOKS_DIR/agent-runner"        "$BIN_DIR/agent-runner"
symlink "$HOOKS_DIR/set-agent-status.sh" "$BIN_DIR/set-agent-status.sh"

echo
echo "Done. Make sure $BIN_DIR is on your PATH."
echo "Add to ~/.bashrc or ~/.zshrc if needed:"
echo '  export PATH="$HOME/.local/bin:$PATH"'
echo
echo "Claude Code hooks are configured in .claude/settings.json in this repo."
echo "Copy or symlink it to your project's .claude/settings.json to activate hooks."
