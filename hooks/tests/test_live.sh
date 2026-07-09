#!/usr/bin/env bash
#
# Live smoke test for set-agent-status.sh
#
# Run this from a plain zellij shell (NOT inside Claude Code),
# otherwise Claude Code hooks will stomp the tab name between assertions.
#
#   bash hooks/tests/test_live.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_SCRIPT="$SCRIPT_DIR/../set-agent-status.sh"

if [[ -z "${ZELLIJ:-}" ]]; then
  echo "SKIP: not running inside zellij — run this from a plain zellij shell"
  exit 0
fi

PANE_ID="${ZELLIJ_PANE_ID:-}"
if [[ -z "$PANE_ID" ]]; then
  echo "SKIP: ZELLIJ_PANE_ID not set"
  exit 0
fi

get_pane_info() {
  zellij action list-panes --json 2>/dev/null \
    | python3 -c "
import json, sys
panes = json.load(sys.stdin)
pid = int(sys.argv[1])
for p in panes:
    if p.get('id') == pid and not p.get('is_plugin', False):
        print(p.get('tab_id', ''))
        print(p.get('tab_name', ''))
        break
" "$PANE_ID"
}

get_tab_name() {
  get_pane_info | tail -1
}

PANE_INFO=$(get_pane_info)
TAB_ID=$(echo "$PANE_INFO" | head -1)
ORIGINAL_TAB=$(echo "$PANE_INFO" | tail -1)
ORIGINAL_BASE="${ORIGINAL_TAB%%:*}"
echo "Original tab: '$ORIGINAL_TAB' (base: '$ORIGINAL_BASE')"
echo "Pane ID: $PANE_ID, Tab ID: $TAB_ID"

PASS=0
FAIL=0

assert_tab() {
  local expected="$1" desc="$2"
  sleep 0.15
  local actual
  actual=$(get_tab_name)
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc → '$actual'"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== Live Rename Tests ==="

bash "$STATUS_SCRIPT" '🟡 working'
assert_tab "${ORIGINAL_BASE}:🟡 working" "set yellow working"

bash "$STATUS_SCRIPT" '🔴 waiting'
assert_tab "${ORIGINAL_BASE}:🔴 waiting" "switch to red waiting"

bash "$STATUS_SCRIPT" '🟢 done'
assert_tab "${ORIGINAL_BASE}:🟢 done" "switch to green done"

bash "$STATUS_SCRIPT" '⚪ ready'
assert_tab "${ORIGINAL_BASE}:⚪ ready" "set ready status"

bash "$STATUS_SCRIPT" 'clear'
assert_tab "${ORIGINAL_BASE}" "clear restores base name"

bash "$STATUS_SCRIPT" '🟡 working'
assert_tab "${ORIGINAL_BASE}:🟡 working" "re-set after clear"

echo ""
echo "=== Rapid Succession (simulates hook flurry) ==="

for status in '🟣 tool' '🟡 working' '🟣 tool' '🟡 working' '🔴 waiting'; do
  bash "$STATUS_SCRIPT" "$status"
done
assert_tab "${ORIGINAL_BASE}:🔴 waiting" "rapid succession ends on last status"

echo ""
echo "=== Double Clear ==="

bash "$STATUS_SCRIPT" 'clear'
bash "$STATUS_SCRIPT" 'clear'
assert_tab "${ORIGINAL_BASE}" "double clear is safe"

echo ""
echo "=== Cleanup ==="

zellij action rename-tab --tab-id "$TAB_ID" "$ORIGINAL_TAB" 2>/dev/null || true
echo "Restored tab to: '$ORIGINAL_TAB'"

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo ""
echo "NOTE: If running inside Claude Code, hooks will interfere."
echo "      Run from a plain zellij shell for accurate results."
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
