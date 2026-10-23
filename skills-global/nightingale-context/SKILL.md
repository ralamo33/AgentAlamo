---
name: nightingale-context
description: Read-only research across Notion, Granola, Slack, GitHub, and Linear for context on the Nightingale project (Summa nurse-scheduling / workforce product, Linear project "ClinOps - Nightingale", repo Percepta-Core/summa-os). Use whenever the user asks what is going on with Nightingale, wants background before a meeting, ticket, or PR, asks "what did we decide about X in Nightingale", who owns something, what a customer or nurse manager said, or needs to ramp up on any Nightingale, Module 1, CLINOPS, or Summa workforce topic, even if they never say "search".
---

# Nightingale Context

Research only. Never post, comment, create, update, or edit anything in any system. If the user wants a ticket, hand off to `nightingale-ticket`.

## Sources

Load deferred MCP tools with ToolSearch before use. Query all sources in parallel (subagents for broad questions), then synthesize.

| Source | Start here | Tools |
|---|---|---|
| Notion | [Working With Nightingale: Getting Started](https://app.notion.com/p/percepta-ai/Tyson-MDF-Working-With-Nightingale-Getting-Started-3c7ab8e637498165ad15fb695da74548). Fetch it first and follow its links. Also "Nightingale Module 1 Home" and the "Nightingale Workforce Command Panes PRD". Then the docs index below. | `notion-fetch`, `notion-search`, `notion-query-data-sources` |
| Linear | Project [ClinOps - Nightingale](https://linear.app/aitco/project/clinops-nightingale-c7464c5e6b9e/overview), team CLINOPS. Project description holds the standards and current framing. | `get_project`, `list_issues`, `get_issue`, `list_comments`, `list_documents` |
| GitHub | `Percepta-Core/summa-os` (main repo). Related: `Percepta-Core/summa_databricks_dash` (analyses). | `gh search prs/issues/code`, `gh pr view`, `gh api` |
| Slack | Channels below. | `slack_read_channel`, `slack_search_public_and_private`, `slack_read_thread` |
| Granola | Meeting notes and transcripts mentioning Nightingale. | `query_granola_meetings`, `list_meetings`, `get_meeting_transcript` |

### Notion docs index

[Percepta Hospitals Documents](https://app.notion.com/p/percepta-ai/2e7ab8e6374980e991a7fd14aa233f67) is the main doc database (`collection://2e7ab8e6-3749-80ef-a01c-000b83dd5f9f`, under Hospitals Home). Query it directly rather than relying on free-text search alone. Filter on `Product` contains `Nightingale` and/or `Focus Area` contains `Workforce (Nightingale)`, sorted by `Last updated time` descending. Useful properties:

- `Doc Status`: prefer `Canonical`, then `Working Doc`; `Weekly Readout` shows recent progress
- `Category`: `Key Docs`, `Primer`, `Product`, `Onboarding`, `Meeting Notes`, `Onsite`, `Decomps`
- `Granola`: link to the source meeting, so jump from a meeting-notes row to its transcript
- `Customer` (Summa, Cinci, Wellspan) and `System` (UKG, Lawson, Databricks) to narrow further

Skip `Archive` unless history matters.

### Slack channels

Ranked by Nightingale signal. The Slack API does not expose the user's sidebar sections (Now / Hourly / Daily), so this list is inferred from activity; ask the user to correct it if results look thin.

- `#wg-hospitals-workforce-module-1`: Module 1 working group, analyses, PRDs
- `#customer-summa-workforce-eng`: engineering and prod ops (maintenance, features, analyses)
- `#customer-hospitals-workforce`: strategy, demos, design docs
- `#customer-summa-workforce-support`: customer-reported issues (ORC tickets)
- `#customer-hospitals-squad`, `#staffing-updates`: who is staffed where
- `#customer-summa-command-center`, `#research-summa-workforce`: adjacent products and research

Search by keyword across all channels as well; the list is a starting point, not a boundary.

## Method

1. Restate the question in one line and pick the sources that matter. Questions about *why* lean on Slack, Granola, Notion. Questions about *state* lean on Linear and GitHub. Questions about *how it works* lean on the repo and Notion.
2. Start from the anchors above, then widen with keyword searches. Open threads, not just top-level messages; decisions usually live in replies.
3. Prefer recent material (the project moves fast). When sources disagree, the newer one wins unless it is a chat remark contradicting a doc, so flag the conflict instead of choosing silently.
4. Stop when the question is answered; do not exhaustively dump every source.

## Output

Lead with the answer, then support it. Keep it scannable:

- **Answer**: a few sentences.
- **Evidence**: bullets, each ending with a source link (Slack permalink, Notion URL, Linear ID, PR number, Granola meeting title + date).
- **Gaps / conflicts**: what you could not find, which sources were unreachable, and any disagreement between sources.
- **People**: who to ask, when ownership is relevant.

Never quote demo passwords or credentials that appear in messages; point to the message instead.
