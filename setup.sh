#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_SOURCE_DIR="$REPO_DIR/skills-global"
LOCAL_SOURCE_DIR="$REPO_DIR/skills-local"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"
LOCAL_SKILLS_DIR="$(pwd)/.claude/skills"

# ── colours ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

header() { echo -e "\n${CYAN}${BOLD}$*${RESET}"; }
ok()     { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()   { echo -e "  ${YELLOW}!${RESET}  $*"; }
err()    { echo -e "  ${RED}✗${RESET}  $*"; }
info()   { echo -e "     $*"; }


# ── symlink settings ──────────────────────────────────────────────────
header "Linking settings"
SETTINGS_SRC="$REPO_DIR/claude-settings.json"
SETTINGS_DST="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
if [[ -L "$SETTINGS_DST" ]]; then
  existing="$(readlink "$SETTINGS_DST")"
  if [[ "$existing" == "$SETTINGS_SRC" ]]; then
    ok "settings.json already linked"
  else
    warn "settings.json links to $existing — replacing"
    rm "$SETTINGS_DST"
    ln -s "$SETTINGS_SRC" "$SETTINGS_DST"
    ok "settings.json  →  $SETTINGS_DST"
  fi
elif [[ -e "$SETTINGS_DST" ]]; then
  warn "settings.json exists and is not a symlink — backing up to settings.json.bak"
  mv "$SETTINGS_DST" "${SETTINGS_DST}.bak"
  ln -s "$SETTINGS_SRC" "$SETTINGS_DST"
  ok "settings.json  →  $SETTINGS_DST"
else
  ln -s "$SETTINGS_SRC" "$SETTINGS_DST"
  ok "settings.json  →  $SETTINGS_DST"
fi

# ── discover skills by source dir ────────────────────────────────────────────
discover_skills() {
  local src="$1"
  [[ -d "$src" ]] || return 0
  find "$src" -mindepth 2 -maxdepth 2 -name "SKILL.md" \
    | sed 's|/SKILL\.md$||' \
    | sort
}

mapfile -t GLOBAL_SKILLS < <(discover_skills "$GLOBAL_SOURCE_DIR")
mapfile -t LOCAL_SKILLS  < <(discover_skills "$LOCAL_SOURCE_DIR")

if [[ ${#GLOBAL_SKILLS[@]} -eq 0 && ${#LOCAL_SKILLS[@]} -eq 0 ]]; then
  err "No skills found under $GLOBAL_SOURCE_DIR or $LOCAL_SOURCE_DIR"
  exit 1
fi

header "Skills found in repo"
for s in "${GLOBAL_SKILLS[@]}"; do
  info "• $(basename "$s")  ${YELLOW}[global]${RESET}"
done
for s in "${LOCAL_SKILLS[@]}"; do
  info "• $(basename "$s")  ${YELLOW}[local]${RESET}"
done

# ── helper: symlink one skill dir ─────────────────────────────────────────────
link_skill() {
  local skill_dir="$1"
  local target_parent="$2"
  local name
  name="$(basename "$skill_dir")"
  local link="$target_parent/$name"

  mkdir -p "$target_parent"

  if [[ -L "$link" ]]; then
    local existing_target
    existing_target="$(readlink "$link")"
    if [[ "$existing_target" == "$skill_dir" ]]; then
      return
    else
      warn "$name  →  $link already links to $existing_target — replacing"
      rm "$link"
    fi
  elif [[ -e "$link" ]]; then
    warn "$name  →  $link exists and is not a symlink — skipping (remove manually)"
    return
  fi

  ln -s "$skill_dir" "$link"
  ok "$name  →  $link"
}

# ── install ───────────────────────────────────────────────────────────────────
header "Linking skills"

for skill_dir in "${GLOBAL_SKILLS[@]}"; do
  info "── $(basename "$skill_dir")  [global]"
  link_skill "$skill_dir" "$GLOBAL_SKILLS_DIR"
done

for skill_dir in "${LOCAL_SKILLS[@]}"; do
  info "── $(basename "$skill_dir")  [local]"
  link_skill "$skill_dir" "$LOCAL_SKILLS_DIR"
done

# ── hooks ────────────────────────────────────────────────────────────────────
HOOKS_DIR="$REPO_DIR/hooks"
BIN_DIR="${HOME}/.local/bin"

if [[ -d "$HOOKS_DIR" ]]; then
  header "Linking hooks"
  mkdir -p "$BIN_DIR"
  for hook in "$HOOKS_DIR"/*.sh; do
    [[ "$(basename "$hook")" == "hooks-setup.sh" ]] && continue
    [[ -f "$hook" ]] || continue
    name="$(basename "$hook")"
    dst="$BIN_DIR/$name"
    chmod +x "$hook"
    if [[ -L "$dst" ]]; then
      rm "$dst"
    elif [[ -e "$dst" ]]; then
      warn "$name — $dst exists and is not a symlink — skipping"
      continue
    fi
    ln -s "$hook" "$dst"
    ok "$name  →  $dst"
  done

  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo ""
    warn "Add $BIN_DIR to your PATH if it isn't already:"
    info 'export PATH="$HOME/.local/bin:$PATH"'
  fi
fi

# ── tools ────────────────────────────────────────────────────────────────────
TOOLS_DIR="$REPO_DIR/tools"

if [[ -d "$TOOLS_DIR" ]]; then
  header "Linking tools"
  mkdir -p "$BIN_DIR"

  # canvas
  CANVAS_BIN="$TOOLS_DIR/canvas/bin/canvas"
  if [[ -f "$CANVAS_BIN" ]]; then
    chmod +x "$CANVAS_BIN"
    dst="$BIN_DIR/canvas"
    if [[ -L "$dst" ]]; then
      existing="$(readlink "$dst")"
      if [[ "$existing" == "$CANVAS_BIN" ]]; then
        ok "canvas already linked"
      else
        warn "canvas links to $existing — replacing"
        rm "$dst"
        ln -s "$CANVAS_BIN" "$dst"
        ok "canvas  →  $dst"
      fi
    elif [[ -e "$dst" ]]; then
      warn "canvas — $dst exists and is not a symlink — skipping"
    else
      ln -s "$CANVAS_BIN" "$dst"
      ok "canvas  →  $dst"
    fi
  fi
fi

header "Done"
echo ""
info "All symlinks point back into $REPO_DIR."
info "Edit skills in the repo and changes are live immediately."
echo ""
