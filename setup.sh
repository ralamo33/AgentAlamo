#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_SOURCE_DIR="$REPO_DIR/skills-global"
LOCAL_SOURCE_DIR="$REPO_DIR/skills-local"
CONFIG_SOURCE_DIR="$REPO_DIR/config"
CONFIG_TARGET_DIR="$HOME/.config"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"
LOCAL_SKILLS_DIR="$HOME/.claude/skills"

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

# ── choose install mode ──────────────────────────────────────────────────────
CANVAS_SKILL_NAMES=("canvas" "canvas-html")

header "What would you like to install?"
echo ""
info "  1) Canvas skills only (${CANVAS_SKILL_NAMES[*]})"
info "  2) Skills only"
info "  3) Everything"
echo ""
printf "  Choose [1/2/3] (default: 2): "
read -r install_choice
install_choice="${install_choice:-2}"

# ── install skills ───────────────────────────────────────────────────────────
header "Linking skills"

for skill_dir in "${GLOBAL_SKILLS[@]}"; do
  name="$(basename "$skill_dir")"
  if [[ "$install_choice" == "1" ]]; then
    is_canvas=false
    for cn in "${CANVAS_SKILL_NAMES[@]}"; do
      [[ "$name" == "$cn" ]] && is_canvas=true && break
    done
    if ! $is_canvas; then
      info "── $name  [global] — skipped"
      continue
    fi
  fi
  info "── $name  [global]"
  link_skill "$skill_dir" "$GLOBAL_SKILLS_DIR"
done

if [[ "$install_choice" == "2" || "$install_choice" == "3" ]]; then
  for skill_dir in "${LOCAL_SKILLS[@]}"; do
    info "── $(basename "$skill_dir")  [local]"
    link_skill "$skill_dir" "$LOCAL_SKILLS_DIR"
  done
else
  for skill_dir in "${LOCAL_SKILLS[@]}"; do
    info "── $(basename "$skill_dir")  [local] — skipped"
  done
fi

# ── hooks (only for option 3) ────────────────────────────────────────────────
if [[ "$install_choice" == "3" ]]; then
  "$REPO_DIR/setup-zellij.sh"
fi

# -- other symlinks -----------------------------------------------------------
ln -sf "$REPO_DIR/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$REPO_DIR/claude-settings.json" "$HOME/.claude/settings.json"

# -- config (only for option 3)--------------------------
if [[ "$install_choice" == "3" ]]; then
  header "Linking config"
  if [[ -d "$CONFIG_SOURCE_DIR" ]]; then
    mkdir -p "$CONFIG_TARGET_DIR"
    while IFS= read -r -d '' cfg_dir; do
      link_skill "$cfg_dir" "$CONFIG_TARGET_DIR"
    done < <(find "$CONFIG_SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  else
    warn "No config directory found at $CONFIG_SOURCE_DIR"
  fi
fi

# ── tools ────────────────────────────────────────────────────────────────────
TOOLS_DIR="$REPO_DIR/tools"

BIN_DIR="$HOME/.local/bin"

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
