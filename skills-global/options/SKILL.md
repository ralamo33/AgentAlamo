---
name: options
description: Answer a decision with a scannable list of high-level options — one line each, `* label - why you'd pick it`, and nothing else. Invoked explicitly by the user as /options. Do not trigger this on your own, and do not offer it unprompted.
---

# Options

The user invoked `/options`. They have a decision in front of them and want to see the shape of the choice in about five seconds. Give them a list and stop.

Detail is a tax here. Every sentence they have to read is one they didn't ask for, and a recommendation from you short-circuits the whole exercise — they invoked this because they want to be the one who picks.

With no argument, the decision is whatever is live in the conversation.

## Format

```
* label - why you'd pick this one
* label - why you'd pick this one
```

Label: a noun phrase, one to three words. Reason: a fragment, under about eight words.

Count: however many genuinely distinct options exist, usually three to five. Don't pad to hit a number, don't drop a real one to stay tidy.

Nothing above the list, nothing below it. No preamble, no framing line, no recommendation, no "let me know which one."

## What makes the reasons work

```
* hotdogs - simple
* italian - romantic
* thai - for the curry sauce
```

Each reason is a different *motivation*, not a description of the option. Effort, occasion, craving — three separate axes. The user scans, recognizes their own situation in one of them, and points.

`italian - pasta and pizza` fails: it describes the food and says nothing about when you'd want it. Test each line by asking whether it could be swapped onto a different bullet without becoming wrong. If it could, it isn't doing any work.

## Making the options distinct

Options should differ in kind, not degree. "Rewrite in Rust / rewrite in Go / rewrite in Zig" is one option wearing three hats. Span the actual space: the cheap fix, the proper fix, the sidestep, the reframe.

Include *do nothing* whenever it's genuinely live. It often is, and it's the one nobody volunteers.

## Before you answer

Investigate as much as you need — read the code, check the config, look at the data. Do it silently and let the bullets be the entire visible output.

If the problem is underspecified, don't ask a clarifying question first. Let the options span the interpretations; whichever they pick tells you what they meant.

## Examples

Slow CI:

```
* cache deps - one line, buys 40%
* split the suite - parallel, needs runner budget
* drop the e2e tier - fastest, loses coverage
* leave it - it's six minutes
```

Auth for a new API:

```
* session cookies - simplest, same-origin only
* jwt - stateless, revocation is a pain
* reuse the existing gateway - no new surface
```

First engineering hire:

```
* senior generalist - unblocks you everywhere
* junior plus your time - cheap, costs your focus
* contractor - reversible
* don't - runway
```
