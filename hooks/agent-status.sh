#!/usr/bin/env bash

: "${AS_DIR:=/tmp/claude-status}"
: "${AS_COLOR_WORKING:=🟡}"
: "${AS_COLOR_BLOCKED:=🔴}"
: "${AS_COLOR_IDLE:=⚪}"
: "${AS_COLOR_STALE:=🔴}"
: "${AS_NAME_UNNAMED:=1}"
: "${AS_STALE_AFTER:=300}"
: "${AS_BLOCK_HOLD:=2}"
: "${AS_TICK:=0.4}"
: "${AS_SWEEP_EVERY:=5}"
: "${AS_REAP_MISSES:=3}"
: "${AS_IDLE_EXIT:=120}"

AS_SELF="${BASH_SOURCE[0]}"

as_now() {
  if [[ -n "${EPOCHSECONDS:-}" ]]; then
    printf '%s' "$EPOCHSECONDS"
  else
    printf '%(%s)T' -1
  fi
}

_as_transition() {
  local current="$1" event="$2" detail="${3:-}"
  case "$event" in
    SessionStart) AS_OUT="idle" ;;
    UserPromptSubmit|PreToolUse|SubagentStart|SubagentStop) AS_OUT="working" ;;
    PermissionRequest|Elicitation) AS_OUT="blocked" ;;
    Stop) AS_OUT="idle" ;;
    SessionEnd) AS_OUT="none" ;;
    PostToolUse)
      if [[ "$current" == "blocked" ]]; then AS_OUT="working"; else AS_OUT="$current"; fi ;;
    Notification)
      if [[ "$detail" == "permission" ]]; then AS_OUT="blocked"; else AS_OUT="$current"; fi ;;
    *) AS_OUT="$current" ;;
  esac
}

as_transition() {
  _as_transition "$@"
  printf '%s' "$AS_OUT"
}

_as_color() {
  local state="$1" idle_age="$2" hold_until="${3:-0}" now
  now="$(as_now)"
  if [[ "$state" != "none" && "$hold_until" -gt "$now" ]]; then
    AS_OUT="$AS_COLOR_BLOCKED"
    return
  fi
  case "$state" in
    working) AS_OUT="$AS_COLOR_WORKING" ;;
    blocked) AS_OUT="$AS_COLOR_BLOCKED" ;;
    idle)
      if (( idle_age > AS_STALE_AFTER )); then
        AS_OUT="$AS_COLOR_STALE"
      else
        AS_OUT="$AS_COLOR_IDLE"
      fi ;;
    *) AS_OUT="" ;;
  esac
}

as_color() {
  _as_color "$@"
  printf '%s' "$AS_OUT"
}

_as_aggregate() {
  local c seen_working="" seen_idle=""
  for c in "$@"; do
    case "$c" in
      "$AS_COLOR_BLOCKED") AS_OUT="$AS_COLOR_BLOCKED"; return ;;
      "$AS_COLOR_WORKING") seen_working=1 ;;
      "$AS_COLOR_IDLE") seen_idle=1 ;;
    esac
  done
  if [[ -n "$seen_working" ]]; then
    AS_OUT="$AS_COLOR_WORKING"
  elif [[ -n "$seen_idle" ]]; then
    AS_OUT="$AS_COLOR_IDLE"
  else
    AS_OUT=""
  fi
}

as_aggregate() {
  _as_aggregate "$@"
  printf '%s' "$AS_OUT"
}

_as_strip_marker() {
  local name="$1" m
  for m in "$AS_COLOR_WORKING" "$AS_COLOR_BLOCKED" "$AS_COLOR_IDLE" "$AS_COLOR_STALE" 🟢 🟡 🔴 ⚪ ⚫ 🔵; do
    [[ -z "$m" ]] && continue
    name="${name#"$m" }"
    name="${name%" $m"}"
    name="${name%":$m"}"
  done
  AS_OUT="$name"
}

as_strip_marker() {
  _as_strip_marker "$@"
  printf '%s' "$AS_OUT"
}

set -uo pipefail

as_emit() {
  local event="${1:-}" detail="" pane="${ZELLIJ_PANE_ID:-}" payload=""
  [[ -z "$event" || -z "$pane" || -z "${ZELLIJ:-}" ]] && return 0

  if [[ "$event" == "Notification" ]]; then
    IFS= read -r -t 0.2 -d '' payload 2>/dev/null
    case "$payload" in
      *permission*|*Permission*|*approve*|*Approve*) detail="permission" ;;
      *) detail="other" ;;
    esac
  fi

  [[ -d "$AS_DIR/log" ]] || mkdir -p "$AS_DIR/log" 2>/dev/null
  printf '%s %s\n' "$event" "$detail" >> "$AS_DIR/log/$pane"

  local pid=""
  [[ -r "$AS_DIR/daemon.pid" ]] && read -r pid < "$AS_DIR/daemon.pid"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    ( "$AS_SELF" daemon >/dev/null 2>&1 </dev/null & )
  fi
  return 0
}

as_fold_logs() {
  local now="$1" pane log pending state idle_since hold_until event detail
  shopt -s nullglob
  for log in "$AS_DIR"/log/*; do
    pane="${log##*/}"
    pending="$AS_DIR/pending.$pane"
    mv -f "$log" "$pending" 2>/dev/null || continue

    state="none"; idle_since="$now"; hold_until=0
    if [[ -r "$AS_DIR/state/$pane" ]]; then
      read -r state idle_since hold_until < "$AS_DIR/state/$pane"
    fi

    while read -r event detail; do
      _as_transition "$state" "$event" "$detail"
      if [[ "$state" == "blocked" && "$AS_OUT" != "blocked" ]]; then
        hold_until=$((now + AS_BLOCK_HOLD))
      fi
      if [[ "$AS_OUT" == "idle" && "$state" != "idle" ]]; then
        idle_since="$now"
      fi
      state="$AS_OUT"
    done < "$pending"
    rm -f "$pending"

    if [[ "$state" == "none" ]]; then
      rm -f "$AS_DIR/state/$pane" "$AS_DIR/miss/$pane"
    else
      [[ -d "$AS_DIR/state" ]] || mkdir -p "$AS_DIR/state"
      printf '%s %s %s\n' "$state" "$idle_since" "$hold_until" > "$AS_DIR/state/$pane"
    fi
  done
  shopt -u nullglob
}

as_rename() {
  zellij action rename-tab --tab-id "$1" "$2" 2>/dev/null
}

as_render() {
  local now="$1"
  local panes_json pane_id tab_id tab_name pane_cmd pane_cwd
  local -A tab_colors=() tab_base=() tab_raw=()
  local -a live_panes=()

  panes_json="${AS_PANES_JSON:-$(zellij action list-panes --json --tab 2>/dev/null)}" || return 1
  [[ -z "$panes_json" ]] && return 1

  # Unit separator, not tab: tab is IFS whitespace, so bash would collapse an
  # empty tab_name and shift every later field one to the left.
  local rows sep=$'\037'
  rows="$(printf '%s' "$panes_json" | jq -r --arg sep "$sep" '
    .[] | select(.is_plugin | not)
    | [(.id|tostring), (.tab_id|tostring), (.pane_command // ""), (.tab_name // ""), (.pane_cwd // "")]
    | join($sep)' 2>/dev/null)" || return 1

  while IFS="$sep" read -r pane_id tab_id pane_cmd tab_name pane_cwd; do
    [[ -z "$pane_id" ]] && continue
    live_panes+=("$pane_id")
    _as_strip_marker "$tab_name"
    local base="$AS_OUT"
    if [[ -z "$base" && -r "$AS_DIR/base/$tab_id" ]]; then
      IFS= read -r base < "$AS_DIR/base/$tab_id"
    fi
    # A tab the user never renamed reports tab_name "". Fall back to the cwd of
    # its first claude pane, so a tab spanning two repos keeps one stable name.
    if [[ -z "$base" && "$AS_NAME_UNNAMED" == "1" && -n "$pane_cwd" \
          && -z "${tab_base[$tab_id]:-}" ]]; then
      case "$pane_cmd" in
        claude|claude\ *|*/claude|*/claude\ *) base="${pane_cwd##*/}" ;;
      esac
    fi
    [[ -z "$base" ]] && continue
    if [[ "$base" != "${tab_base[$tab_id]:-}" ]]; then
      [[ -d "$AS_DIR/base" ]] || mkdir -p "$AS_DIR/base"
      printf '%s\n' "$base" > "$AS_DIR/base/$tab_id"
    fi
    tab_base["$tab_id"]="$base"
    tab_raw["$tab_id"]="$tab_name"

    local state idle_since hold_until misses=0
    [[ -r "$AS_DIR/state/$pane_id" ]] || continue
    read -r state idle_since hold_until < "$AS_DIR/state/$pane_id"

    if [[ "$state" != "working" ]]; then
      case "$pane_cmd" in
        claude|claude\ *|*/claude|*/claude\ *) misses=0 ;;
        *)
          [[ -r "$AS_DIR/miss/$pane_id" ]] && read -r misses < "$AS_DIR/miss/$pane_id"
          misses=$((misses + 1)) ;;
      esac
      [[ -d "$AS_DIR/miss" ]] || mkdir -p "$AS_DIR/miss"
      printf '%s\n' "$misses" > "$AS_DIR/miss/$pane_id"
      if (( misses >= AS_REAP_MISSES )); then
        rm -f "$AS_DIR/state/$pane_id" "$AS_DIR/miss/$pane_id"
        continue
      fi
    else
      rm -f "$AS_DIR/miss/$pane_id"
    fi

    _as_color "$state" "$((now - idle_since))" "$hold_until"
    tab_colors["$tab_id"]+="${AS_OUT} "
  done <<< "$rows"

  shopt -s nullglob
  local sf pane
  for sf in "$AS_DIR"/state/*; do
    pane="${sf##*/}"
    local found=""
    for pane_id in "${live_panes[@]}"; do
      [[ "$pane" == "$pane_id" ]] && { found=1; break; }
    done
    [[ -z "$found" ]] && rm -f "$sf" "$AS_DIR/miss/$pane"
  done
  shopt -u nullglob

  local want prev marker
  for tab_id in "${!tab_base[@]}"; do
    [[ -z "${tab_base[$tab_id]// /}" ]] && continue
    # shellcheck disable=SC2086
    _as_aggregate ${tab_colors[$tab_id]:-}
    marker="$AS_OUT"
    if [[ -z "$marker" && ! -r "$AS_DIR/tab/$tab_id" \
          && "${tab_raw[$tab_id]}" == "${tab_base[$tab_id]}" ]]; then
      continue
    fi
    if [[ -n "$marker" ]]; then
      want="${marker} ${tab_base[$tab_id]}"
    else
      want="${tab_base[$tab_id]}"
    fi
    prev=""
    [[ -r "$AS_DIR/tab/$tab_id" ]] && IFS= read -r prev < "$AS_DIR/tab/$tab_id"
    [[ "$prev" == "$want" ]] && continue
    as_rename "$tab_id" "$want" || continue
    [[ -d "$AS_DIR/tab" ]] || mkdir -p "$AS_DIR/tab"
    printf '%s\n' "$want" > "$AS_DIR/tab/$tab_id"
  done

  [[ ${#tab_colors[@]} -gt 0 ]]
}

as_reconcile() {
  local now dirty=""
  now="$(as_now)"
  shopt -s nullglob
  local f
  for f in "$AS_DIR"/log/*; do dirty=1; break; done
  shopt -u nullglob
  [[ -n "$dirty" ]] && as_fold_logs "$now"
  printf '%s' "$dirty"
}

as_daemon() {
  if (( BASH_VERSINFO[0] < 4 )); then
    printf 'agent-status: needs bash 4+, got %s\n' "${BASH_VERSION}" >&2
    exit 1
  fi
  mkdir -p "$AS_DIR/log" "$AS_DIR/state" "$AS_DIR/tab" "$AS_DIR/miss"

  local lock="$AS_DIR/daemon.lock" other tries
  if ! mkdir "$lock" 2>/dev/null; then
    other=""
    for tries in 1 2 3 4 5; do
      [[ -r "$lock/pid" ]] && { read -r other < "$lock/pid"; break; }
      sleep 0.2
    done
    if [[ -n "$other" ]] && kill -0 "$other" 2>/dev/null; then
      exit 0
    fi
    rm -rf "$lock"
    mkdir "$lock" 2>/dev/null || exit 0
  fi
  printf '%s\n' "$$" > "$lock/pid"
  printf '%s\n' "$$" > "$AS_DIR/daemon.pid"
  trap 'rm -rf "$AS_DIR/daemon.lock"; rm -f "$AS_DIR/daemon.pid"; exit 0' EXIT INT TERM

  local last_sweep=0 empty_since=0 now dirty
  while :; do
    now="$(as_now)"
    dirty="$(as_reconcile)"
    if [[ -n "$dirty" ]] || (( now - last_sweep >= AS_SWEEP_EVERY )); then
      last_sweep="$now"
      if as_render "$now"; then
        empty_since=0
      else
        (( empty_since == 0 )) && empty_since="$now"
        (( now - empty_since >= AS_IDLE_EXIT )) && break
      fi
    fi
    sleep "$AS_TICK"
  done
}

as_dryrun() {
  local now pane arg
  for arg in "$@"; do
    case "$arg" in
      --name-unnamed) AS_NAME_UNNAMED=1 ;;
      --blocked|--idle|--working) AS_DRY_STATE="${arg#--}" ;;
    esac
  done
  now="$(as_now)"
  AS_DIR="${AS_DRY_DIR:-/tmp/claude-status-dryrun}"
  rm -rf "$AS_DIR"
  mkdir -p "$AS_DIR/state"
  as_rename() { printf '  tab %-4s -> [%s]\n' "$1" "$2"; }

  while IFS= read -r pane; do
    [[ -z "$pane" ]] && continue
    printf '%s %s 0\n' "${AS_DRY_STATE:-working}" "$now" > "$AS_DIR/state/$pane"
  done < <(zellij action list-panes --json --tab 2>/dev/null \
    | jq -r '.[] | select(.is_plugin | not)
             | select((.pane_command // "") | test("(^|/)claude($| )"))
             | .id')

  printf 'dry run — every claude pane treated as "%s", nothing is renamed\n' \
    "${AS_DRY_STATE:-working}"
  if as_render "$now"; then
    printf 'renders above are what the daemon would apply\n'
  else
    printf '  (no tab would be touched)\n'
  fi
  rm -rf "$AS_DIR"
}

as_clear_all() {
  shopt -s nullglob
  local sf tab_id name
  for sf in "$AS_DIR"/tab/*; do
    tab_id="${sf##*/}"
    IFS= read -r name < "$sf"
    _as_strip_marker "$name"
    zellij action rename-tab --tab-id "$tab_id" "$AS_OUT" 2>/dev/null || true
  done
  shopt -u nullglob
  rm -rf "$AS_DIR"
  printf 'cleared %s\n' "$AS_DIR"
}

if [[ -n "${AS_SOURCE_ONLY:-}" ]]; then
  return 0 2>/dev/null || true
fi

case "${1:-}" in
  emit)      shift; as_emit "$@" ;;
  daemon)    as_daemon ;;
  reconcile) mkdir -p "$AS_DIR"/{log,state,tab,miss}; now="$(as_now)"; as_reconcile >/dev/null; as_render "$now" || true ;;
  dryrun)    shift; as_dryrun "$@" ;;
  clear)     as_clear_all ;;
  dump)
    shopt -s nullglob
    for f in "$AS_DIR"/state/*; do printf 'pane %-6s %s\n' "${f##*/}" "$(<"$f")"; done
    for f in "$AS_DIR"/tab/*; do printf 'tab  %-6s %s\n' "${f##*/}" "$(<"$f")"; done
    printf '\nstate: %s\n' "$AS_DIR" ;;
  *)
    printf 'usage: %s {emit <Event>|daemon|reconcile|dryrun|clear|dump}\n' "${0##*/}" >&2
    exit 2 ;;
esac
