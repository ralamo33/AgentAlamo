#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"
HOOKS_DIR="$REPO_DIR/hooks"
BIN_DIR="${HOME}/.local/bin"

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

header "Zellij tab status hooks for Claude Code"

# ── symlink hook scripts into PATH ──────────────────────────────────────────
header "Linking hook scripts"
mkdir -p "$BIN_DIR"
for hook in "$HOOKS_DIR"/*.sh; do
  [[ -f "$hook" ]] || continue
  name="$(basename "$hook")"
  dst="$BIN_DIR/$name"
  chmod +x "$hook"
  if [[ -L "$dst" ]]; then
    existing="$(readlink "$dst")"
    if [[ "$existing" == "$hook" ]]; then
      ok "$name already linked"
      continue
    fi
    warn "$name links to $existing — replacing"
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

# ── merge hooks into settings.json ──────────────────────────────────────────
header "Adding hooks to $SETTINGS"

mkdir -p "$(dirname "$SETTINGS")"
if [[ ! -f "$SETTINGS" ]]; then
  echo '{}' > "$SETTINGS"
  ok "Created empty $SETTINGS"
fi

HAS_HOOKS=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
print('yes' if s.get('hooks') else 'no')
" "$SETTINGS" 2>/dev/null || echo "no")

if [[ "$HAS_HOOKS" == "yes" ]]; then
  warn "Existing hooks found in $SETTINGS — this will override them."
  printf "  Continue? [y/N]: "
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "Skipping hook installation."
    exit 0
  fi
fi

HOOKS_JSON=$(cat <<'HOOKS_EOF'
{
  "PreToolUse": [{"hooks": [{"type": "command", "command": "set-agent-status.sh '🟡'"}]}],
  "PostToolUse": [{"hooks": [{"type": "command", "command": "set-agent-status.sh '🟡'"}]}],
  "SubagentStart": [{"hooks": [{"type": "command", "command": "set-agent-status.sh '🟡'"}]}],
  "Notification": [{"hooks": [{"type": "command", "command": "set-agent-status.sh '🔴'"}]}],
  "PermissionRequest": [{"hooks": [{"type": "command", "command": "set-agent-status.sh '🔴'"}]}],
  "Elicitation": [{"hooks": [{"type": "command", "command": "set-agent-status.sh '🔴'"}]}],
  "Stop": [{"hooks": [{"type": "command", "command": "set-agent-status.sh '🟢'"}]}],
  "SessionEnd": [{"hooks": [{"type": "command", "command": "set-agent-status.sh 'clear'"}]}],
  "StopFailure": [{"hooks": [{"type": "command", "command": "set-agent-status.sh '🔴'"}]}]
}
HOOKS_EOF
)

python3 -c "
import json, sys

settings_path = sys.argv[1]
new_hooks = json.loads(sys.argv[2])

with open(settings_path) as f:
    settings = json.load(f)

existing_hooks = settings.get('hooks', {})

for event, entries in new_hooks.items():
    if event not in existing_hooks:
        existing_hooks[event] = []
    for entry in entries:
        cmd = entry['hooks'][0]['command']
        already = any(
            h['hooks'][0].get('command') == cmd
            for h in existing_hooks[event]
            if h.get('hooks')
        )
        if not already:
            existing_hooks[event].append(entry)

settings['hooks'] = existing_hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')
" "$SETTINGS" "$HOOKS_JSON"

ok "Hooks merged into $SETTINGS"

header "Done"
echo ""
info "Zellij tabs will now show agent status:"
info "  🟡  working   🔴  needs attention   🟢  done"
echo ""
