#!/usr/bin/env bash
set -euo pipefail

STATUS="${1:?usage: set-agent-status.sh <status>}"

if [[ -n "${CLAUDE_AGENT_STATUS_FILE:-}" ]]; then
  mkdir -p "$(dirname "$CLAUDE_AGENT_STATUS_FILE")"
  printf '%s\n' "$STATUS" > "$CLAUDE_AGENT_STATUS_FILE"
fi

if command -v zellij &>/dev/null && [[ -n "${ZELLIJ:-}" ]]; then
  PANE_ID="${ZELLIJ_PANE_ID:-}"
  if [[ -z "$PANE_ID" ]]; then
    exit 0
  fi

  PANE_INFO=$(zellij action list-panes --json 2>/dev/null \
    | python3 -c "
import json, sys
try:
    panes = json.load(sys.stdin)
    pid = int(sys.argv[1])
    for p in panes:
        if p.get('id') == pid and not p.get('is_plugin', False):
            print(p.get('tab_id', ''))
            print(p.get('tab_name', ''))
            break
except Exception:
    pass
" "$PANE_ID" 2>/dev/null || true)

  TAB_ID=$(echo "$PANE_INFO" | head -1)
  TAB_NAME=$(echo "$PANE_INFO" | tail -1)

  if [[ -z "$TAB_NAME" || -z "$TAB_ID" ]]; then
    exit 0
  fi

  BASE_NAME="${TAB_NAME%%:*}"
  if [[ "$STATUS" == "clear" ]]; then
    zellij action rename-tab --tab-id "$TAB_ID" "${BASE_NAME}" 2>/dev/null || true
  else
    zellij action rename-tab --tab-id "$TAB_ID" "${BASE_NAME}:${STATUS}" 2>/dev/null || true
  fi
fi
