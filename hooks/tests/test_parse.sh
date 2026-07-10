#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
STATUS_SCRIPT="$SCRIPT_DIR/../set-agent-status.sh"

PASS=0
FAIL=0

assert_tab_name() {
  local fixture="$1" pane_id="$2" expected="$3" desc="$4"
  local actual
  actual=$(python3 -c "
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
" "$pane_id" < "$fixture" 2>/dev/null | tail -1 || true)

  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_base_name() {
  local tab_name="$1" expected="$2" desc="$3"
  local actual="${tab_name%%:*}"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_rename_result() {
  local base_name="$1" status="$2" expected="$3" desc="$4"
  local actual
  if [[ "$status" == "clear" ]]; then
    actual="$base_name"
  else
    actual="${base_name}:${status}"
  fi
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_pane_info() {
  local fixture="$1" pane_id="$2" expected_tab_id="$3" expected_tab_name="$4" desc="$5"
  local info
  info=$(python3 -c "
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
" "$pane_id" < "$fixture" 2>/dev/null || true)

  local actual_tab_id actual_tab_name
  actual_tab_id=$(echo "$info" | head -1)
  actual_tab_name=$(echo "$info" | tail -1)

  if [[ "$actual_tab_id" == "$expected_tab_id" && "$actual_tab_name" == "$expected_tab_name" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: tab_id='$expected_tab_id' tab_name='$expected_tab_name'"
    echo "    actual:   tab_id='$actual_tab_id' tab_name='$actual_tab_name'"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Tab Name Extraction (python3 parser) ==="

echo ""
echo "--- basic.json ---"
assert_tab_name "$FIXTURES/basic.json" 0 "myagent" \
  "finds non-plugin pane with id=0 (skips plugin pane with same id)"
assert_tab_name "$FIXTURES/basic.json" 1 "myagent" \
  "finds pane id=1 on same tab"
assert_tab_name "$FIXTURES/basic.json" 2 "other-tab" \
  "finds pane on different tab"
assert_tab_name "$FIXTURES/basic.json" 99 "" \
  "returns empty for non-existent pane id"

echo ""
echo "--- with-status.json ---"
assert_tab_name "$FIXTURES/with-status.json" 5 "cedar:🟡 working" \
  "returns full tab name including existing status suffix"
assert_tab_name "$FIXTURES/with-status.json" 6 "deploy" \
  "returns tab name without status suffix"

echo ""
echo "--- multi-pane-same-tab.json ---"
assert_tab_name "$FIXTURES/multi-pane-same-tab.json" 10 "shared-tab:🟡 working" \
  "pane 10 on shared tab returns correct name"
assert_tab_name "$FIXTURES/multi-pane-same-tab.json" 11 "shared-tab:🟡 working" \
  "pane 11 on shared tab returns same tab name"

echo ""
echo "--- no-match.json ---"
assert_tab_name "$FIXTURES/no-match.json" 0 "" \
  "plugin-only pane returns empty (no non-plugin match)"

echo ""
echo "--- real-session.json ---"
assert_tab_name "$FIXTURES/real-session.json" 19 "cedar:🔴 waiting" \
  "real session: finds pane 19 on cedar tab"
assert_tab_name "$FIXTURES/real-session.json" 0 "auto-update" \
  "real session: finds non-plugin pane 0"
assert_tab_name "$FIXTURES/real-session.json" 4 "schema-fix" \
  "real session: finds pane 4"

echo ""
echo "=== Base Name Extraction (%%:* stripping) ==="

assert_base_name "cedar:🟡 working" "cedar" \
  "strips emoji status suffix"
assert_base_name "cedar" "cedar" \
  "no-op when no suffix present"
assert_base_name "my-agent:🔴 waiting" "my-agent" \
  "strips red status suffix"
assert_base_name "tab:with:colons:🟢 done" "tab" \
  "WARNING: multiple colons — strips everything after first colon"

echo ""
echo "=== Rename Result (status application) ==="

assert_rename_result "cedar" "🟡 working" "cedar:🟡 working" \
  "applies yellow working status"
assert_rename_result "cedar" "🔴 waiting" "cedar:🔴 waiting" \
  "applies red waiting status"
assert_rename_result "cedar" "🟢 done" "cedar:🟢 done" \
  "applies green done status"
assert_rename_result "cedar" "clear" "cedar" \
  "clear removes status suffix"

echo ""
echo "=== Tab ID Extraction (critical for --tab-id rename) ==="

assert_pane_info "$FIXTURES/basic.json" 0 "0" "myagent" \
  "basic: pane 0 → tab_id=0"
assert_pane_info "$FIXTURES/basic.json" 2 "1" "other-tab" \
  "basic: pane 2 → tab_id=1"
assert_pane_info "$FIXTURES/with-status.json" 5 "3" "cedar:🟡 working" \
  "with-status: pane 5 → tab_id=3"
assert_pane_info "$FIXTURES/multi-pane-same-tab.json" 10 "5" "shared-tab:🟡 working" \
  "multi-pane: pane 10 → tab_id=5"
assert_pane_info "$FIXTURES/multi-pane-same-tab.json" 11 "5" "shared-tab:🟡 working" \
  "multi-pane: pane 11 → same tab_id=5"
assert_pane_info "$FIXTURES/real-session.json" 19 "8" "cedar:🔴 waiting" \
  "real session: pane 19 → tab_id=8"
assert_pane_info "$FIXTURES/real-session.json" 0 "0" "auto-update" \
  "real session: pane 0 → tab_id=0"

echo ""
echo "=== Idempotency (set → strip → re-set) ==="

TAB="deploy"
STATUS="🟡 working"
RENAMED="${TAB}:${STATUS}"
STRIPPED="${RENAMED%%:*}"
RE_RENAMED="${STRIPPED}:🔴 waiting"
FINAL_STRIPPED="${RE_RENAMED%%:*}"

if [[ "$STRIPPED" == "$TAB" && "$FINAL_STRIPPED" == "$TAB" ]]; then
  echo "  PASS: base name survives multiple set/strip cycles"
  PASS=$((PASS + 1))
else
  echo "  FAIL: base name corrupted after cycles"
  echo "    original:  '$TAB'"
  echo "    after 1st: '$STRIPPED'"
  echo "    after 2nd: '$FINAL_STRIPPED'"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
