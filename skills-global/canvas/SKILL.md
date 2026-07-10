---
name: canvas
description: Open an HTML artifact in a local browser review session so the user can annotate elements, type messages, and send feedback back to the agent. Use when you have generated an HTML plan, report, prototype, or visual artifact and want the user to review it interactively.
argument-hint: <path to html file or description>
---

# Canvas

Canvas is a human-in-the-loop review tool. You write an HTML file, open it with `canvas open`, and the user reviews it in their browser — annotating elements, typing messages, and hitting Send. Both `open` and `update` block until the user sends feedback. You loop with `update` until the user ends the session.

## Request

$ARGUMENTS

If the argument is an existing file path, open that file directly. If it is a description, plan content, or empty, delegate HTML generation to a subagent (see Subagent delegation below).

## Subagent delegation

When the argument is not a file path, spawn a subagent to generate the HTML artifact. Pass the plan content as context to the subagent using the `canvas-html` skill file at `skills-global/canvas-html/SKILL.md`. The subagent's only job is to produce a layout-audit-safe HTML file from the content you provide. Read the skill file and include its full instructions in the subagent prompt along with the plan content. The subagent will write the HTML to `/tmp/` and return the path.

## Workflow

1. If the argument is a description: spawn a subagent to generate the HTML (see above). If the argument is a file path: use it directly.
2. Run `canvas open <name> <path>` — registers the session, opens the browser, blocks until feedback arrives.
3. Read `next_step` in the JSON output. If it reports layout errors, fix them and re-open before asking the user to review.
4. Apply the user's feedback and write the updated HTML to disk.
5. Run `canvas update <name> <path>` — reloads the browser, blocks until the next round of feedback.
6. Repeat step 4–5 until the output has `status: "ended"` or `status: "confirmed"`.

## Commands

```
canvas open <name> <path>     # New session: copy file, open browser, block for feedback
canvas update <name> <path>   # Replace file, reload browser, block for feedback
canvas reopen <name>          # Re-open an active plan in the browser (non-blocking, user command)
canvas restore <name>         # Restore most-recent archive to active (non-blocking, user command)
```

`<name>` must be unique, alphanumeric + dashes/underscores, max 64 chars.
`<path>` is the HTML file you wrote — canvas copies it into its own storage.

If `canvas` is not on PATH, find it with `find ~/Workspace -path '*/tools/canvas/bin/canvas' -type f` and run it with `node <result>`.

## Output format

```json
{
  "session": { "name": "my-plan", "status": "feedback" },
  "prompts": [
    { "uid": "3", "prompt": "Make this bigger", "selector": "h1", "tag": "h1", "text": "Title" }
  ],
  "layout_warnings": [],
  "dom_snapshot": "uid=1 body\n  uid=2 h1 \"Title\"\n  ...",
  "next_step": "Apply feedback, then run `canvas update my-plan <path>`."
}
```

When `status` is `"ended"`, the session was closed from the agent side. Do not call `update` again.

When `status` is `"confirmed"`, the user clicked **Send & Confirm** — meaning they approved the plan and sent any final notes. The session is over and the plan is archived. Read the `prompts` array for their final feedback but do not call `update`.

Always read `next_step` first. If there are layout errors, fix them before the user sees the plan.

## HTML rules (must follow to pass the layout audit)

The browser runs an automatic layout audit after each load. Errors block the review gate until fixed.

**Block elements only for content** — never put `<code>`, `<strong>`, or `<em>` inline inside `<p>` text. Use a `<span class="mono">` styled as `display: inline-block` or plain text instead.

**Every container needs:**
```css
max-width: 100%;
overflow-wrap: break-word;
word-break: break-word;
```

**Flex children need** `min-width: 0` to allow shrinking.

**Monospace snippets** — use `<pre>` with:
```css
white-space: pre-wrap;
word-break: break-all;
overflow-x: auto;
```

**Short code labels** — if you need inline monospace, use `display: inline-block; max-width: 100%; word-break: break-all` on the element.

**Safe starter CSS:**
```css
* { box-sizing: border-box; }
body { font-family: system-ui, sans-serif; padding: 32px; max-width: 860px; margin: 0 auto;
       color: #e6eefc; background: #0b0f1a; }
.card { background: #0f2a4f; border: 1px solid #162d50; border-radius: 8px; padding: 20px; }
.mono { font-family: monospace; font-size: 12px; background: #162d50; color: #2dd4ff;
        padding: 1px 5px; border-radius: 3px;
        display: inline-block; max-width: 100%; word-break: break-all; }
pre { background: #060a14; color: #c5d3e8; padding: 14px; border-radius: 6px;
      border: 1px solid #162d50;
      font-size: 12px; white-space: pre-wrap; word-break: break-all; overflow-x: auto; }
```
