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

GLOBAL_SETTINGS="$HOME/.claude/settings.json"
HOOKS_SCRIPT="$REPO_DIR/hooks/zellij-status.sh"

install_hooks() {
  echo "Installing zellij status hooks"
  mkdir -p "$(dirname "$GLOBAL_SETTINGS")"
  [[ -f "$GLOBAL_SETTINGS" ]] || echo '{}' > "$GLOBAL_SETTINGS"

  python3 - "$GLOBAL_SETTINGS" "$HOOKS_SCRIPT" <<'PYEOF'
import json
import sys

settings_path, hooks_script = sys.argv[1], sys.argv[2]

with open(settings_path) as f:
    content = f.read().strip()
settings = json.loads(content) if content else {}

events = {
    "SessionStart": "white",
    "UserPromptSubmit": "blue",
    "Notification": "red",
    "Stop": "green",
}

hooks = settings.setdefault("hooks", {})

for event, status in events.items():
    command = f"{hooks_script} {status}"
    entries = hooks.setdefault(event, [])
    already_present = any(
        h.get("command") == command
        for entry in entries
        for h in entry.get("hooks", [])
    )
    if already_present:
        print(f"  ✓ {event} -> {status} (already present)")
        continue
    entries.append({"hooks": [{"type": "command", "command": command}]})
    print(f"  + {event} -> {status} (added)")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
}

install_hooks
