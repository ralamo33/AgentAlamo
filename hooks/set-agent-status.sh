#!/usr/bin/env bash
set -euo pipefail

STATUS="${1:?usage: set-agent-status.sh <status>}"

if [[ -z "${CLAUDE_AGENT_STATUS_FILE:-}" ]]; then
  exit 0
fi

mkdir -p "$(dirname "$CLAUDE_AGENT_STATUS_FILE")"
printf '%s\n' "$STATUS" > "$CLAUDE_AGENT_STATUS_FILE"
