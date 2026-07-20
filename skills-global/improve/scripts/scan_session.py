#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

MULTIPLEXERS = {
    "git", "gh", "gt", "npm", "pnpm", "yarn", "bun", "npx", "uv", "uvx",
    "cargo", "docker", "kubectl", "poetry", "python", "python3", "node",
    "pip", "pip3", "brew", "make", "go", "fern", "terraform", "aws", "gcloud",
}

FEEDBACK_PATTERNS = [
    r"\bno[,.\s]", r"\bdon'?t\b", r"\bdo not\b", r"\bstop\b", r"\bactually\b",
    r"\binstead\b", r"\byou should\b", r"\bnext time\b", r"\balways\b",
    r"\bnever\b", r"\bi prefer\b", r"\bi'd prefer\b", r"\bplease don'?t\b",
    r"\bthat'?s wrong\b", r"\bnot what i\b", r"\bi asked\b", r"\bwhy did you\b",
    r"\byou keep\b", r"\bagain\b.*\b(don'?t|stop|no)\b", r"\bwrong\b",
    r"\brevert\b", r"\bundo\b", r"\bi told you\b", r"\bshould have\b",
    r"\buse .* instead\b", r"\bfrom now on\b",
]
FEEDBACK_RE = re.compile("|".join(FEEDBACK_PATTERNS), re.IGNORECASE)


def resolve_transcript(cwd, explicit):
    if explicit:
        return Path(explicit)
    slug = str(Path(cwd).resolve()).replace("/", "-")
    proj = Path.home() / ".claude" / "projects" / slug
    if not proj.is_dir():
        sys.exit(f"No transcript dir for cwd: {proj}")
    files = sorted(proj.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not files:
        sys.exit(f"No transcripts found in {proj}")
    return files[0]


def load_allow(settings_path):
    try:
        data = json.loads(Path(settings_path).read_text())
    except Exception as e:
        sys.exit(f"Could not read settings {settings_path}: {e}")
    return data.get("permissions", {}).get("allow", [])


def bash_patterns(allow):
    pats = []
    bare_bash = False
    tool_names = set()
    for rule in allow:
        m = re.match(r"^Bash\s*\((.*)\)$", rule.strip())
        if m:
            pats.append(m.group(1).strip())
        elif rule.strip() == "Bash":
            bare_bash = True
        else:
            tool_names.add(rule.strip())
    return pats, bare_bash, tool_names


def covers(pattern, command):
    rx = "".join(".*" if ch == "*" else re.escape(ch) for ch in pattern)
    return re.fullmatch(rx, command, re.DOTALL) is not None


def suggest_rule(command):
    toks = command.strip().split()
    if not toks:
        return None
    head = toks[0]
    if head in MULTIPLEXERS and len(toks) > 1 and not toks[1].startswith("-"):
        return f"Bash({head} {toks[1]} *)"
    return f"Bash({head} *)"


def iter_records(path):
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def extract(path):
    bash_cmds = []
    other_tools = set()
    user_msgs = []
    denials = set()
    for rec in iter_records(path):
        t = rec.get("type")
        msg = rec.get("message") or {}
        if t == "assistant":
            for block in msg.get("content", []) or []:
                if isinstance(block, dict) and block.get("type") == "tool_use":
                    name = block.get("name", "")
                    inp = block.get("input", {}) or {}
                    if name == "Bash":
                        cmd = (inp.get("command") or "").strip()
                        if cmd:
                            bash_cmds.append(cmd)
                    elif name not in ("Read", "Glob", "Grep", "Edit", "Write",
                                      "TodoWrite", "Task", "Skill", "WebFetch",
                                      "WebSearch", "NotebookEdit"):
                        other_tools.add(name)
        elif t == "user":
            if rec.get("isMeta"):
                continue
            content = msg.get("content")
            texts = []
            if isinstance(content, str):
                texts.append(content)
            elif isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        texts.append(block.get("text", ""))
                    elif isinstance(block, dict) and block.get("type") == "tool_result":
                        rc = block.get("content")
                        blob = rc if isinstance(rc, str) else json.dumps(rc)
                        if "doesn't want to proceed" in blob or "user doesn't want" in blob:
                            denials.add("denied")
            for txt in texts:
                if not txt.strip():
                    continue
                if txt.lstrip().startswith("<") and "command-name" in txt:
                    continue
                user_msgs.append(txt.strip())
    return bash_cmds, other_tools, user_msgs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--transcript")
    ap.add_argument("--cwd", default=os.getcwd())
    ap.add_argument("--settings",
                    default=str(Path.home() / "Workspace" / "AgentAlamo" / "claude-settings.json"))
    args = ap.parse_args()

    tpath = resolve_transcript(args.cwd, args.transcript)
    allow = load_allow(args.settings)
    pats, bare_bash, tool_names = bash_patterns(allow)
    bash_cmds, other_tools, user_msgs = extract(tpath)

    uncovered = {}
    for cmd in bash_cmds:
        if bare_bash or any(covers(p, cmd) for p in pats):
            continue
        rule = suggest_rule(cmd)
        uncovered.setdefault(rule, [])
        if cmd not in uncovered[rule]:
            uncovered[rule].append(cmd)

    uncovered_tools = sorted(other_tools - tool_names)

    feedback = [m for m in user_msgs if FEEDBACK_RE.search(m)]

    report = {
        "transcript": str(tpath),
        "settings": args.settings,
        "counts": {
            "bash_commands_run": len(bash_cmds),
            "candidate_allow_rules": len(uncovered),
            "uncovered_tools": len(uncovered_tools),
            "user_messages": len(user_msgs),
            "feedback_candidates": len(feedback),
        },
        "candidate_allow_rules": [
            {"suggested_rule": rule, "example_commands": cmds[:5]}
            for rule, cmds in sorted(uncovered.items())
        ],
        "uncovered_tools": uncovered_tools,
        "feedback_candidates": feedback,
    }

    out = Path("/tmp") / f"improve-scan-{int(time.time())}.json"
    out.write_text(json.dumps(report, indent=2))

    print(f"Transcript reviewed: {tpath}")
    print(f"Settings compared against: {args.settings}\n")
    print(f"Bash commands run: {report['counts']['bash_commands_run']}")
    print(f"Candidate allow rules (prompted, not yet allowed): {len(uncovered)}")
    for item in report["candidate_allow_rules"]:
        print(f"  {item['suggested_rule']}")
        for c in item["example_commands"]:
            oneline = c.replace("\n", " ")
            print(f"      e.g. {oneline[:100]}")
    if uncovered_tools:
        print(f"\nUncovered non-Bash tools used: {', '.join(uncovered_tools)}")
    print(f"\nFeedback candidates: {len(feedback)}")
    for m in feedback:
        oneline = m.replace("\n", " ")
        print(f"  - {oneline[:140]}")
    print(f"\nFull report saved: {out}")


if __name__ == "__main__":
    main()
