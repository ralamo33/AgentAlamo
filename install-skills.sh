#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_SOURCE_DIR="$REPO_DIR/skills-global"
LOCAL_SOURCE_DIR="$REPO_DIR/skills-local"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"
GLOBAL_AGENTS_DIR="$HOME/.claude/agents"
LOCAL_SKILLS_DIR="$(pwd)/.claude/skills"
LOCAL_AGENTS_DIR="$(pwd)/.claude/agents"

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

# ── Q1: scope ─────────────────────────────────────────────────────────────────
header "Q1 — Which skills to install?"
echo "  skills-global/ → ~/.claude/skills/   (always)"
echo "  skills-local/  → .claude/skills/     (only with option 2)"
echo ""
echo "  1) Global only   (skills-global/ → ~/.claude/skills/)"
echo "  2) Global + Local (also skills-local/ → ./.claude/skills/)"
echo ""
read -rp "  Choice [1/2]: " scope_choice
echo ""

case "$scope_choice" in
  1) DO_LOCAL=false ;;
  2) DO_LOCAL=true  ;;
  *) err "Invalid choice '$scope_choice'. Aborting."; exit 1 ;;
esac

# ── Q2: also register in agents directory? ────────────────────────────────────
header "Q2 — Also symlink into agents directory?"
echo "  Skills are in ~/.claude/skills/. Agents live in ~/.claude/agents/."
echo "  Some workflows expect sub-agents to be registered there too."
echo ""
echo "  1) Global agents only   (~/.claude/agents/)"
echo "  2) Claude agents only   (.claude/agents/ in current dir)"
echo "  3) Both"
echo "  4) Neither (skills only)"
echo ""
read -rp "  Choice [1/2/3/4]: " agent_choice
echo ""

case "$agent_choice" in
  1) DO_GLOBAL_AGENTS=true;  DO_LOCAL_AGENTS=false ;;
  2) DO_GLOBAL_AGENTS=false; DO_LOCAL_AGENTS=true  ;;
  3) DO_GLOBAL_AGENTS=true;  DO_LOCAL_AGENTS=true  ;;
  4) DO_GLOBAL_AGENTS=false; DO_LOCAL_AGENTS=false ;;
  *) err "Invalid choice '$agent_choice'. Aborting."; exit 1 ;;
esac

# ── helper: symlink one skill dir ─────────────────────────────────────────────
# Usage: link_skill <skill_dir> <target_parent_dir>
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
      ok "$name  →  $link  (already correct)"
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

# Global skills always go to ~/.claude/skills/ (and optionally ~/.claude/agents/)
for skill_dir in "${GLOBAL_SKILLS[@]}"; do
  info "── $(basename "$skill_dir")  [global]"
  link_skill "$skill_dir" "$GLOBAL_SKILLS_DIR"
  if $DO_GLOBAL_AGENTS; then
    link_skill "$skill_dir" "$GLOBAL_AGENTS_DIR"
  fi
  if $DO_LOCAL_AGENTS; then
    link_skill "$skill_dir" "$LOCAL_AGENTS_DIR"
  fi
done

# Local skills go to ./.claude/skills/ (only when DO_LOCAL=true)
if $DO_LOCAL; then
  for skill_dir in "${LOCAL_SKILLS[@]}"; do
    info "── $(basename "$skill_dir")  [local]"
    link_skill "$skill_dir" "$LOCAL_SKILLS_DIR"
    if $DO_GLOBAL_AGENTS; then
      link_skill "$skill_dir" "$GLOBAL_AGENTS_DIR"
    fi
    if $DO_LOCAL_AGENTS; then
      link_skill "$skill_dir" "$LOCAL_AGENTS_DIR"
    fi
  done
elif [[ ${#LOCAL_SKILLS[@]} -gt 0 ]]; then
  info "(skipping ${#LOCAL_SKILLS[@]} local skill(s) — run with option 2 to include)"
fi

# ── Q3: symlink settings? ─────────────────────────────────────────────────────
REPO_SETTINGS="$REPO_DIR/.claude/settings.json"
GLOBAL_SETTINGS="$HOME/.claude/settings.json"

header "Q3 — Symlink settings.json?"
echo "  $REPO_SETTINGS"
echo "  → $GLOBAL_SETTINGS"
echo ""
echo "  1) Yes — back up existing and replace with symlink"
echo "  2) No  — leave settings untouched"
echo ""
read -rp "  Choice [1/2]: " settings_choice
echo ""

if [[ "$settings_choice" == "1" ]]; then
  if [[ ! -f "$REPO_SETTINGS" ]]; then
    err "Repo settings not found at $REPO_SETTINGS — skipping"
  elif [[ -L "$GLOBAL_SETTINGS" ]]; then
    existing_target="$(readlink "$GLOBAL_SETTINGS")"
    if [[ "$existing_target" == "$REPO_SETTINGS" ]]; then
      ok "settings.json already linked correctly — nothing to do"
    else
      warn "settings.json links to $existing_target — replacing"
      rm "$GLOBAL_SETTINGS"
      ln -s "$REPO_SETTINGS" "$GLOBAL_SETTINGS"
      ok "settings.json  →  $GLOBAL_SETTINGS"
    fi
  elif [[ -f "$GLOBAL_SETTINGS" ]]; then
    BACKUP="$GLOBAL_SETTINGS.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$GLOBAL_SETTINGS" "$BACKUP"
    info "Backed up existing settings to $BACKUP"
    rm "$GLOBAL_SETTINGS"
    ln -s "$REPO_SETTINGS" "$GLOBAL_SETTINGS"
    ok "settings.json  →  $GLOBAL_SETTINGS"
  else
    ln -s "$REPO_SETTINGS" "$GLOBAL_SETTINGS"
    ok "settings.json  →  $GLOBAL_SETTINGS"
  fi
else
  info "(skipping settings symlink)"
fi

header "Done"
echo ""
info "All symlinks point back into $REPO_DIR."
info "Edit skills or settings.json in the repo and changes are live immediately."
echo ""
