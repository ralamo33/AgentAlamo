#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GLOBAL_SOURCE_DIR="$REPO_DIR/skills-global"
LOCAL_SOURCE_DIR="$REPO_DIR/skills-local"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"

link_skill() {
  local skill_dir="$1"
  local name
  name="$(basename "$skill_dir")"
  local link="$GLOBAL_SKILLS_DIR/$name"

  mkdir -p "$GLOBAL_SKILLS_DIR"

  if [[ -L "$link" ]]; then
    local existing_target
    existing_target="$(readlink "$link")"
    if [[ "$existing_target" == "$skill_dir" ]]; then
      echo "  ✓ $name (already linked)"
      return
    else
      echo "  ! $name links to $existing_target — replacing"
      rm "$link"
    fi
  elif [[ -e "$link" ]]; then
    echo "  ! $name exists at $link and is not a symlink — skipping"
    return
  fi

  ln -s "$skill_dir" "$link"
  echo "  ✓ $name → $link"
}

for src in "$GLOBAL_SOURCE_DIR" "$LOCAL_SOURCE_DIR"; do
  [[ -d "$src" ]] || continue
  while IFS= read -r skill_md; do
    link_skill "$(dirname "$skill_md")"
  done < <(find "$src" -name "SKILL.md" | sort)
done

echo ""
echo "Zellij status hooks are installed separately: ./setup-zellij.sh"
