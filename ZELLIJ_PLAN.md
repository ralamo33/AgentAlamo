Plan: Zellij Multi-Agent Claude Status Dashboard
Goal
Build a Zellij-based orchestration setup where:
Each Claude agent runs in its own Zellij pane.
Each pane title shows that agent’s live status.
If a Zellij tab contains only one agent pane, the tab name also reflects that agent’s color/status.
The system is simple, shell-scriptable, and does not require writing a custom Zellij plugin in the first version.
Core Design
Use three layers:
```text
Zellij layout
  -> starts one or more agent panes

agent-runner script
  -> launches Claude
  -> owns pane title updates
  -> optionally owns tab title updates

Claude Code hooks
  -> emit semantic status to a status file
  -> examples: running, waiting for input, using tool, done, failed
```
Zellij supports renaming the current pane and current tab from the CLI via actions such as `rename-pane` and `rename-tab`. It also supports layouts with panes that run commands and accept `args`. Claude Code hooks can run commands at lifecycle events such as `PreToolUse`, `PostToolUse`, `Notification`, `Stop`, and `SubagentStop`.
Important Constraint
Prefer this model:
```text
each pane updates itself
```
Do not start by building a central controller that renames arbitrary panes/tabs. Cross-pane/tab orchestration is more complex than self-updating panes and may require stable IDs or a plugin.
Status Model
Each agent gets:
```text
.agent-status/<agent-name>.status
```
Recommended statuses:
```text
⚪ starting
🟢 working
🟡 waiting
🟣 tool
🔵 editing
✅ done
🔴 failed
```
Recommended color mapping:
```text
green   -> working / healthy
yellow  -> waiting for user input or permission
purple  -> running tool
blue    -> editing / thinking / reading
white   -> starting / idle
red     -> failed
check   -> done
```
Because terminal tab bars often cannot display arbitrary background colors directly through `rename-tab`, represent color using emoji or short labels:
```text
🟢 auth-api
🟡 billing
🔴 frontend
✅ tests
```
Desired Behavior
Pane title
Every agent pane should show:
```text
<agent-name> <status>
```
Example:
```text
auth-api 🟢 working
billing 🟡 waiting
frontend 🔴 failed
```
Tab title
If a tab contains only one agent pane, the tab name should show the same color/status:
```text
🟢 auth-api
🟡 billing
🔴 frontend
```
If a tab contains multiple panes, do not let individual agents fight over the tab name. Use a stable group name instead:
```text
backend
frontend
all-agents
```
Implementation Steps
1. Create `agent-runner`
Create this file:
```bash
#!/usr/bin/env bash
set -euo pipefail

AGENT_NAME="${1:?usage: agent-runner <agent-name> [--single-pane-tab] [claude args...]}"
shift

SINGLE_PANE_TAB="false"

if [[ "${1:-}" == "--single-pane-tab" ]]; then
  SINGLE_PANE_TAB="true"
  shift
fi

STATUS_DIR=".agent-status"
STATUS_FILE="$STATUS_DIR/$AGENT_NAME.status"

mkdir -p "$STATUS_DIR"

write_status() {
  local status="$1"
  printf '%s\n' "$status" > "$STATUS_FILE"
}

set_titles() {
  local status="$1"

  zellij action rename-pane "$AGENT_NAME $status" 2>/dev/null || true

  if [[ "$SINGLE_PANE_TAB" == "true" ]]; then
    zellij action rename-tab "$status $AGENT_NAME" 2>/dev/null || true
  fi
}

set_status() {
  local status="$1"
  write_status "$status"
  set_titles "$status"
}

set_status "⚪ starting"

(
  last_status=""

  while true; do
    if [[ -f "$STATUS_FILE" ]]; then
      current_status="$(cat "$STATUS_FILE")"

      if [[ "$current_status" != "$last_status" ]]; then
        set_titles "$current_status"
        last_status="$current_status"
      fi
    fi

    sleep 1
  done
) &

WATCHER_PID=$!

cleanup() {
  kill "$WATCHER_PID" 2>/dev/null || true
}

trap cleanup EXIT

export CLAUDE_AGENT_NAME="$AGENT_NAME"
export CLAUDE_AGENT_STATUS_FILE="$STATUS_FILE"

set_status "🟢 working"

if claude "$@"; then
  set_status "✅ done"
else
  set_status "🔴 failed"
  exit 1
fi
```
Make executable:
```bash
chmod +x ./agent-runner
```
2. Test manually inside Zellij
Start Zellij:
```bash
zellij
```
Run:
```bash
./agent-runner auth-api --single-pane-tab
```
Expected result:
```text
Pane title: auth-api 🟢 working
Tab title:  🟢 auth-api
```
Stop Claude or let it finish.
Expected result:
```text
Pane title: auth-api ✅ done
Tab title:  ✅ auth-api
```
3. Add helper script for Claude hooks
Create:
```bash
mkdir -p .claude-hooks
```
Create `.claude-hooks/set-agent-status.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

STATUS="${1:?usage: set-agent-status.sh <status>}"

if [[ -z "${CLAUDE_AGENT_STATUS_FILE:-}" ]]; then
  exit 0
fi

mkdir -p "$(dirname "$CLAUDE_AGENT_STATUS_FILE")"
printf '%s\n' "$STATUS" > "$CLAUDE_AGENT_STATUS_FILE"
```
Make executable:
```bash
chmod +x .claude-hooks/set-agent-status.sh
```
4. Wire Claude hooks
Add or update Claude settings so hook events write status.
Use the local Claude Code hook configuration location appropriate for the project.
Conceptual settings:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude-hooks/set-agent-status.sh '🟣 tool'"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude-hooks/set-agent-status.sh '🟢 working'"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude-hooks/set-agent-status.sh '🟡 waiting'"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude-hooks/set-agent-status.sh '✅ done'"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude-hooks/set-agent-status.sh '✅ done'"
          }
        ]
      }
    ]
  }
}
```
Notes:
`Stop` means Claude finished responding, not necessarily that the whole project task is complete.
`Notification` is useful for “needs input” or “waiting for permission.”
`PreToolUse` and `PostToolUse` are good enough for a first-pass “tool running” indicator.
Keep the wrapper’s process exit handling as the source of truth for final `failed` status.
5. Create a Zellij layout with single-agent tabs
Create `agents.kdl`:
```kdl
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="auth-api" {
        pane command="./agent-runner" {
            args "auth-api" "--single-pane-tab"
        }
    }

    tab name="billing" {
        pane command="./agent-runner" {
            args "billing" "--single-pane-tab"
        }
    }

    tab name="frontend" {
        pane command="./agent-runner" {
            args "frontend" "--single-pane-tab"
        }
    }

    tab name="tests" {
        pane command="./agent-runner" {
            args "tests" "--single-pane-tab"
        }
    }
}
```
Run:
```bash
zellij --layout ./agents.kdl
```
Expected tab bar:
```text
🟢 auth-api | 🟢 billing | 🟢 frontend | 🟢 tests
```
As agents change state:
```text
🟢 auth-api | 🟡 billing | 🔴 frontend | ✅ tests
```
6. Create a layout with mixed tabs
For tabs with multiple panes, do not use `--single-pane-tab`.
Example:
```kdl
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="backend" {
        pane split_direction="vertical" {
            pane command="./agent-runner" {
                args "auth-api"
            }
            pane command="./agent-runner" {
                args "billing"
            }
        }
    }

    tab name="frontend" {
        pane command="./agent-runner" {
            args "frontend" "--single-pane-tab"
        }
    }

    tab name="tests" {
        pane command="./agent-runner" {
            args "tests" "--single-pane-tab"
        }
    }
}
```
Expected behavior:
```text
backend       -> stable tab name, because multiple panes
🟢 frontend   -> dynamic tab name, because single agent pane
🟢 tests      -> dynamic tab name, because single agent pane
```
7. Optional: Add a status overview pane
Create `agent-status-board`:
```bash
#!/usr/bin/env bash
set -euo pipefail

STATUS_DIR=".agent-status"

while true; do
  clear
  echo "Claude agents"
  echo "============="
  echo

  if [[ -d "$STATUS_DIR" ]]; then
    for file in "$STATUS_DIR"/*.status; do
      [[ -e "$file" ]] || continue
      name="$(basename "$file" .status)"
      status="$(cat "$file")"
      printf "%-20s %s\n" "$name" "$status"
    done
  fi

  sleep 1
done
```
Make executable:
```bash
chmod +x ./agent-status-board
```
Add to a tab:
```kdl
tab name="overview" {
    pane command="./agent-status-board"
}
```
8. Acceptance Criteria
The implementation is complete when:
Running `./agent-runner auth-api --single-pane-tab` updates the current pane title.
The same command updates the current tab title.
Running `./agent-runner auth-api` updates only the pane title, not the tab title.
Claude hook events update `.agent-status/<agent>.status`.
Pane titles reflect status-file changes within one second.
Single-agent tabs show status in the tab name.
Multi-pane tabs keep stable names and do not flicker or fight over naming.
Agent failure sets pane title and, when applicable, tab title to `🔴 failed`.
9. Nice-to-Have Improvements
After the basic version works:
Add `--status-prefix-only` mode so tab titles show only color + name, while pane titles show full status.
Add timestamps to status files.
Add a JSON status format:
```json
{
  "agent": "auth-api",
  "status": "working",
  "icon": "🟢",
  "updated_at": "2026-06-29T16:00:00-04:00"
}
```
Add an overview pane that renders JSON cleanly.
Add a custom Zellij plugin only if shell-based renaming becomes too limiting.
