#!/usr/bin/env bash
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AS_SOURCE_ONLY=1
# shellcheck source=../hooks/agent-status.sh
source "$REPO_DIR/hooks/agent-status.sh"

PASS=0
FAIL=0

check() {
  local desc="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf '  ✗ %s\n      want: %s\n      got:  %s\n' "$desc" "$want" "$got"
  fi
}

replay() {
  local state="none" ev detail
  for ev in "$@"; do
    detail="${ev#*:}"
    [[ "$detail" == "$ev" ]] && detail=""
    state="$(as_transition "$state" "${ev%%:*}" "$detail")"
  done
  printf '%s' "$state"
}

section() { printf '\n%s\n' "$1"; }

# ── transition table ────────────────────────────────────────────────────────
section "transitions"

check "SessionStart yields idle" \
  "idle" "$(replay SessionStart)"
check "UserPromptSubmit yields working" \
  "working" "$(replay SessionStart UserPromptSubmit)"
check "PreToolUse yields working" \
  "working" "$(replay SessionStart PreToolUse)"
check "SubagentStart yields working" \
  "working" "$(replay SessionStart SubagentStart)"
check "SubagentStop stays working (only Stop may finish a turn)" \
  "working" "$(replay SessionStart UserPromptSubmit SubagentStart SubagentStop)"
check "PermissionRequest yields blocked" \
  "blocked" "$(replay SessionStart PreToolUse PermissionRequest)"
check "Stop yields idle" \
  "idle" "$(replay SessionStart UserPromptSubmit PreToolUse Stop)"
check "SessionEnd yields none" \
  "none" "$(replay SessionStart UserPromptSubmit SessionEnd)"

# ── guarded transitions ─────────────────────────────────────────────────────
section "guards"

check "PostToolUse releases blocked to working" \
  "working" "$(replay SessionStart PreToolUse PermissionRequest PostToolUse)"
check "PostToolUse does not disturb idle" \
  "idle" "$(replay SessionStart UserPromptSubmit Stop PostToolUse)"
check "PostToolUse does not disturb working" \
  "working" "$(replay SessionStart PreToolUse PostToolUse)"
check "Notification about permission yields blocked" \
  "blocked" "$(replay SessionStart UserPromptSubmit Notification:permission)"
check "Notification about idling does not disturb idle" \
  "idle" "$(replay SessionStart UserPromptSubmit Stop Notification:other)"
check "unrecognised Notification does not disturb working" \
  "working" "$(replay SessionStart PreToolUse Notification:other)"
check "unknown event does not disturb state" \
  "working" "$(replay SessionStart PreToolUse WidgetInvented)"

# ── the four bugs, replayed ─────────────────────────────────────────────────
section "regressions"

check "bug: Notification lands after Stop and pins red" \
  "idle" "$(replay SessionStart UserPromptSubmit PreToolUse Stop Notification:other)"
check "bug: straggler PostToolUse clobbers green" \
  "idle" "$(replay SessionStart UserPromptSubmit PreToolUse Stop PostToolUse)"
check "bug: red never clears after approving a permission" \
  "idle" "$(replay SessionStart UserPromptSubmit PreToolUse PermissionRequest PostToolUse Stop)"
check "bug: red never clears because user replied" \
  "working" "$(replay SessionStart PermissionRequest UserPromptSubmit)"

# ── colour rendering ────────────────────────────────────────────────────────
section "colours"

check "working renders yellow" \
  "🟡" "$(as_color working 0 0)"
check "blocked renders red" \
  "🔴" "$(as_color blocked 0 0)"
check "fresh idle renders white" \
  "⚪" "$(as_color idle 5 0)"
check "stale idle escalates to red" \
  "🔴" "$(as_color idle 9999 0)"
check "none renders empty" \
  "" "$(as_color none 0 0)"
check "leaving blocked holds red for the debounce window" \
  "🔴" "$(as_color working 0 "$(( $(date +%s) + 2 ))")"
check "expired debounce stops holding red" \
  "🟡" "$(as_color working 0 1)"

# ── tab aggregation ─────────────────────────────────────────────────────────
section "aggregation"

check "blocked outranks working" \
  "🔴" "$(as_aggregate 🟡 🔴 ⚪)"
check "working outranks idle" \
  "🟡" "$(as_aggregate ⚪ 🟡 ⚪)"
check "all idle stays idle" \
  "⚪" "$(as_aggregate ⚪ ⚪)"
check "nothing renders empty" \
  "" "$(as_aggregate)"
check "empty panes are ignored" \
  "⚪" "$(as_aggregate "" ⚪ "")"

# ── log folding (emitter -> state, no zellij) ───────────────────────────────
section "folding"

AS_DIR="$(mktemp -d)"
trap 'rm -rf "$AS_DIR"' EXIT
mkdir -p "$AS_DIR/log" "$AS_DIR/state"

fold_state() {
  local pane="$1"; shift
  local ev
  rm -f "$AS_DIR/state/$pane"
  : > "$AS_DIR/log/$pane"
  for ev in "$@"; do
    local detail="${ev#*:}"
    [[ "$detail" == "$ev" ]] && detail=""
    printf '%s %s\n' "${ev%%:*}" "$detail" >> "$AS_DIR/log/$pane"
  done
  as_fold_logs "$(as_now)"
  [[ -r "$AS_DIR/state/$pane" ]] || { printf 'none'; return; }
  local s rest
  read -r s rest < "$AS_DIR/state/$pane"
  printf '%s' "$s"
}

check "folds a whole turn down to idle" \
  "idle" "$(fold_state 1 SessionStart UserPromptSubmit PreToolUse PostToolUse Stop)"
check "folds the Notification-after-Stop bug to idle" \
  "idle" "$(fold_state 2 SessionStart UserPromptSubmit Stop Notification:other)"
check "folds a permission cycle back to working" \
  "working" "$(fold_state 3 SessionStart PreToolUse PermissionRequest PostToolUse)"
check "SessionEnd removes the pane state file" \
  "none" "$(fold_state 4 SessionStart UserPromptSubmit SessionEnd)"
check "consumes the log so events are not replayed" \
  "0" "$(ls -1 "$AS_DIR/log" | wc -l | tr -d ' ')"

fold_state 5 SessionStart PreToolUse PermissionRequest >/dev/null
printf 'PostToolUse \n' >> "$AS_DIR/log/5"
as_fold_logs "$(as_now)"
read -r _ _ HOLD < "$AS_DIR/state/5"
check "leaving blocked arms the debounce hold" \
  "yes" "$([[ "$HOLD" -gt "$(as_now)" ]] && echo yes || echo no)"

# ── rendering against a fake zellij (aggregation + reaping) ─────────────────
section "rendering"

RENAMES="$AS_DIR/renames"
as_rename() { printf '%s\t%s\n' "$1" "$2" >> "$RENAMES"; }

export AS_PANES_JSON='[
 {"id":10,"is_plugin":false,"tab_id":1,"tab_name":"alpha","pane_command":"claude"},
 {"id":11,"is_plugin":false,"tab_id":1,"tab_name":"alpha","pane_command":"claude"},
 {"id":20,"is_plugin":false,"tab_id":2,"tab_name":"beta","pane_command":"claude"},
 {"id":30,"is_plugin":false,"tab_id":3,"tab_name":"gamma","pane_command":"claude"},
 {"id":40,"is_plugin":false,"tab_id":4,"tab_name":"untracked","pane_command":"/bin/zsh"},
 {"id":50,"is_plugin":false,"tab_id":5,"tab_name":"legacy:🟡","pane_command":"/bin/zsh"},
 {"id":60,"is_plugin":false,"tab_id":6,"tab_name":"reaped","pane_command":"/bin/zsh"},
 {"id":99,"is_plugin":true,"tab_id":7,"tab_name":"plugin","pane_command":"zellij"}
]'

set_state() { printf '%s %s %s\n' "$2" "$3" "${4:-0}" > "$AS_DIR/state/$1"; }

rm -f "$AS_DIR"/state/* "$AS_DIR"/tab/* "$AS_DIR"/miss/* "$RENAMES" 2>/dev/null
mkdir -p "$AS_DIR/state" "$AS_DIR/tab" "$AS_DIR/miss"
NOW="$(as_now)"

set_state 10 working "$NOW"
set_state 11 idle "$NOW"
set_state 20 blocked "$NOW"
set_state 30 idle "$NOW"
set_state 60 idle "$NOW"
set_state 70 working "$NOW"

as_render "$NOW" >/dev/null

renamed_to() { grep -m1 "^$1	" "$RENAMES" 2>/dev/null | cut -f2; }

check "working outranks idle within one tab" \
  "🟡 alpha" "$(renamed_to 1)"
check "blocked tab renders red" \
  "🔴 beta" "$(renamed_to 2)"
check "idle tab renders white" \
  "⚪ gamma" "$(renamed_to 3)"
check "untracked clean tab is left alone" \
  "" "$(renamed_to 4)"
check "legacy ':🟡' suffix is cleaned off" \
  "legacy" "$(renamed_to 5)"
check "pane absent from zellij has its state dropped" \
  "no" "$([[ -r "$AS_DIR/state/70" ]] && echo yes || echo no)"
check "non-claude pane is not reaped on the first miss" \
  "yes" "$([[ -r "$AS_DIR/state/60" ]] && echo yes || echo no)"

as_render "$NOW" >/dev/null
as_render "$NOW" >/dev/null
check "non-claude pane is reaped after AS_REAP_MISSES" \
  "no" "$([[ -r "$AS_DIR/state/60" ]] && echo yes || echo no)"

set_state 10 working "$NOW"
: > "$RENAMES"
as_render "$NOW" >/dev/null
check "unchanged tabs are not renamed again" \
  "" "$(renamed_to 1)"

set_state 10 idle "$((NOW - 9999))"
set_state 11 idle "$((NOW - 9999))"
: > "$RENAMES"
as_render "$NOW" >/dev/null
check "ignored idle tab escalates to red" \
  "🔴 alpha" "$(renamed_to 1)"

# ── never destroy a tab name ────────────────────────────────────────────────
section "name safety"

rm -f "$AS_DIR"/state/* "$AS_DIR"/tab/* "$AS_DIR"/miss/* "$AS_DIR"/base/* "$RENAMES" 2>/dev/null
mkdir -p "$AS_DIR/base"

export AS_PANES_JSON='[
 {"id":10,"is_plugin":false,"tab_id":1,"tab_name":"alpha","pane_command":"claude"}
]'
set_state 10 working "$NOW"
as_render "$NOW" >/dev/null
check "a healthy base name is remembered" \
  "alpha" "$(cat "$AS_DIR/base/1" 2>/dev/null)"

: > "$RENAMES"
export AS_PANES_JSON='[
 {"id":10,"is_plugin":false,"tab_id":1,"tab_name":"🟡 ","pane_command":"claude"}
]'
set_state 10 blocked "$NOW"
as_render "$NOW" >/dev/null
check "a marker-only name is rebuilt from the remembered base" \
  "🔴 alpha" "$(renamed_to 1)"

rm -f "$AS_DIR/base/1" "$AS_DIR/tab/1"
: > "$RENAMES"
set_state 10 blocked "$NOW"
as_render "$NOW" >/dev/null
check "a marker-only name with nothing remembered is left untouched" \
  "" "$(renamed_to 1)"

rm -f "$AS_DIR/base/1" "$AS_DIR/tab/1"
: > "$RENAMES"
export AS_PANES_JSON='[
 {"id":10,"is_plugin":false,"tab_id":1,"tab_name":"","pane_command":"claude"}
]'
set_state 10 working "$NOW"
as_render "$NOW" >/dev/null
check "an empty tab name is never renamed to a bare marker" \
  "" "$(renamed_to 1)"

check "no rename ever produces a marker-only name" \
  "0" "$(grep -cE $'\t[🟡🔴⚪]? *$' "$RENAMES" 2>/dev/null || true)"

# zellij reports tab_name:"" for any tab the user never explicitly renamed —
# the common case, and the one that originally shredded live tab names.
rm -f "$AS_DIR/base/1" "$AS_DIR/tab/1"
: > "$RENAMES"
export AS_PANES_JSON='[
 {"id":10,"is_plugin":false,"tab_id":1,"tab_name":"","pane_command":"claude","pane_cwd":"/Users/ryan/Workspace/agent-alamo"}
]'
set_state 10 working "$NOW"
AS_NAME_UNNAMED=0 as_render "$NOW" >/dev/null
check "an unnamed tab is left alone when naming is off" \
  "" "$(renamed_to 1)"

rm -f "$AS_DIR/base/1" "$AS_DIR/tab/1"
: > "$RENAMES"
AS_NAME_UNNAMED=1 as_render "$NOW" >/dev/null
check "an unnamed tab can opt in to a cwd-derived name" \
  "🟡 agent-alamo" "$(renamed_to 1)"

rm -f "$AS_DIR/base/1" "$AS_DIR/tab/1" "$AS_DIR"/state/*
: > "$RENAMES"
export AS_PANES_JSON='[
 {"id":11,"is_plugin":false,"tab_id":1,"tab_name":"","pane_command":"/bin/zsh","pane_cwd":"/w/scratch"},
 {"id":10,"is_plugin":false,"tab_id":1,"tab_name":"","pane_command":"claude","pane_cwd":"/w/real-repo"},
 {"id":12,"is_plugin":false,"tab_id":1,"tab_name":"","pane_command":"claude","pane_cwd":"/w/other-repo"}
]'
set_state 10 working "$NOW"
AS_NAME_UNNAMED=1 as_render "$NOW" >/dev/null
check "a multi-repo unnamed tab takes its first claude pane's cwd" \
  "🟡 real-repo" "$(renamed_to 1)"

unset AS_PANES_JSON

# ── summary ─────────────────────────────────────────────────────────────────
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
