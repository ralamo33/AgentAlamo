---
name: canvas-html
description: "[Subagent resource] Convert a raw plan, report, or proposal into layout-audit-safe HTML ready for `canvas open`. Used internally by the canvas skill — not user-invocable."
invocable: false
---

# Canvas HTML Generator

You are a subagent whose only job is to produce a single self-contained HTML file from the content below. The file must pass canvas's automatic layout audit (no `element-scroll-overflow`, `clipped-text`, `overlapping-text`, or `page-horizontal-overflow` errors).

## Content to convert

$ARGUMENTS

## Output

Write the HTML to a file in `/tmp/` and print the absolute path on the last line, prefixed with `PATH:`. Example:

```
PATH: /tmp/my-plan.html
```

## Mandatory layout rules

These rules are non-negotiable. Every violation becomes a layout error that blocks the review gate.

### 1. No inline elements inside prose

**Never** do this:
```html
<p>Server uses <code>node:http</code> module.</p>
```

**Do this instead:**
```html
<p>Server uses the <span class="mono">node:http</span> module.</p>
```

Where `.mono` is `display: inline-block` (see CSS below). The key is that `display: inline` elements have `clientWidth = 0`, so the audit always flags them regardless of content width.

### 2. All containers must constrain text

Every `div`, `td`, `li`, `p`, flex child — anything that holds text — must have:
```css
max-width: 100%;
overflow-wrap: break-word;
word-break: break-word;
```

Apply it globally with `* { overflow-wrap: break-word; word-break: break-word; }` and override as needed.

### 3. Flex children must have min-width: 0

Any element that is a flex child must have `min-width: 0` or it cannot shrink below its content width.

### 4. Monospace blocks use pre with wrapping

```css
pre {
  white-space: pre-wrap;
  word-break: break-all;
  overflow-x: auto;
}
```

Never use `white-space: pre` without `pre-wrap` — it prevents wrapping.

### 5. Inline code labels

For short filenames, flags, or identifiers inline in text, use:
```html
<span class="mono">canvas open</span>
```

With CSS:
```css
.mono {
  font-family: monospace;
  font-size: 12px;
  background: #162d50;
  color: #2dd4ff;
  padding: 1px 5px;
  border-radius: 3px;
  display: inline-block;
  max-width: 100%;
  word-break: break-all;
}
```

`display: inline-block` gives the element a real `clientWidth`, which the audit can measure correctly.

## Starter template

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Plan</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0;
        overflow-wrap: break-word; word-break: break-word; }
    body { font-family: system-ui, sans-serif; font-size: 14px; line-height: 1.6;
           color: #e6eefc; background: #0b0f1a; padding: 32px;
           max-width: 860px; margin: 0 auto; }
    h1 { font-size: 22px; font-weight: 700; margin-bottom: 4px; color: #fff; }
    h2 { font-size: 12px; font-weight: 700; text-transform: uppercase;
         letter-spacing: 0.08em; color: #6b83a8; margin: 28px 0 12px; }
    .card { background: #0f2a4f; border: 1px solid #162d50; border-radius: 8px;
            padding: 20px; margin-bottom: 16px; }
    .row { display: flex; gap: 16px; align-items: flex-start;
           padding: 10px 0; border-bottom: 1px solid #162d50; }
    .row:last-child { border-bottom: none; }
    .row > * { min-width: 0; }
    .label { width: 140px; flex-shrink: 0; font-weight: 600; font-size: 13px; color: #8b9fc7; }
    .body { flex: 1; font-size: 13px; color: #c5d3e8; }
    .mono { font-family: monospace; font-size: 12px; background: #162d50;
            color: #2dd4ff; padding: 1px 5px; border-radius: 3px;
            display: inline-block; max-width: 100%; word-break: break-all; }
    pre { background: #060a14; color: #c5d3e8; padding: 14px; border-radius: 6px;
          font-size: 12px; line-height: 1.5; margin: 8px 0;
          border: 1px solid #162d50;
          white-space: pre-wrap; word-break: break-all; overflow-x: auto; }
    ul, ol { padding-left: 18px; margin: 6px 0; }
    li { margin-bottom: 4px; font-size: 13px; }
    p { margin-bottom: 8px; }
    p:last-child { margin-bottom: 0; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th { text-align: left; padding: 6px 10px; background: #0d1b33;
         font-weight: 600; color: #8b9fc7; border-bottom: 2px solid #1f6feb; }
    td { padding: 6px 10px; border-bottom: 1px solid #162d50; vertical-align: top; }
    tr:last-child td { border-bottom: none; }
    a { color: #2dd4ff; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <!-- content here -->
</body>
</html>
```

## Common patterns

**Status badge (success):**
```html
<span style="display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px;
             font-weight:700;background:rgba(45,212,255,0.15);color:#2dd4ff;">DONE</span>
```

**Status badge (pending):**
```html
<span style="display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px;
             font-weight:700;background:rgba(31,111,235,0.15);color:#1f6feb;">PENDING</span>
```

**Two-column row with label:**
```html
<div class="row">
  <div class="label">package.json</div>
  <div class="body">Remove unused <span class="mono">express</span> dep.</div>
</div>
```

**Code block with caption:**
```html
<p>Result:</p>
<pre>{ "name": "canvas", "version": "0.1.0" }</pre>
```
