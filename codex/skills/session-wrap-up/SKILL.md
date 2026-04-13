---
name: session-wrap-up
description: Produce a concise, human-readable session summary before closing. Use when the user asks to wrap up, hand off, or close a working session — outputs a timeline, decisions, achievements, deferred items, risks, carry-forward candidates, and a close/no-close verdict.
---

# Session Wrap-Up

Generate a tight handoff report for the current session so the user can decide whether to close it safely and what context to carry into future sessions.

## When to invoke

Only when the user explicitly asks — never auto-run. Triggers: "wrap up", "before we close", "session summary", "handoff", "can we close this".

## Pre-step — verify concrete state

Before drafting Risks, run these cheap checks and fold the results in:

- `git status` in the working directory (uncommitted / staged / untracked files).
- Glance at any background tasks, running dev servers, or open plans still pending in the conversation.

Do not dump the raw output — only surface what belongs in the report.

## Output structure

Produce these sections in this exact order, in a single message. Favor bullets over prose. Aim for ≤ 6 bullets per section unless the session was genuinely dense.

### Timeline
Chronological turning points — not every tool call. Each bullet: one line, past tense. Pick: goals stated, plans accepted, blockers hit, approach changes, tasks completed.

### Achieved
Concrete outputs only — commits, edits with file paths, PRs, successfully run commands, questions answered with evidence. "Discussed" ≠ "achieved" (that goes in Open Items).

### Key Decisions
Choices that would surprise someone reading the diff cold. Each bullet: decision — one-phrase reason. Skip bike-shedding.

### Deferred / Explicitly Ignored
Things raised but consciously set aside, with the reason. Listing these prevents the next session from re-litigating the same trade-off.

### Risks & Gotchas
Be paranoid. Typical entries:
- Uncommitted / staged / untracked changes sitting locally (from the `git status` pre-step).
- Tests not run, or run with mocks only.
- Assumptions made without verification (env vars, API shapes, permissions).
- Partial refactors, dead code, or TODO markers left behind.
- Destructive ops performed (deletes, force pushes, migrations, large file moves).
- Background processes / dev servers still running.

### Open Items
Unfinished work. Each item actionable enough to pick up cold: what + where + next step.

### Carry-Forward Candidates
Items worth persisting beyond this session. Tag each with a category so the user knows how to file it:
- `user` — role / preferences / expertise details about the user.
- `feedback` — corrections or validated approaches to apply going forward.
- `project` — ongoing work context not derivable from git or the code.
- `reference` — pointers to external systems (Linear projects, dashboards, docs).

List only — do not persist anything yet. The user decides where it goes (a notes file, `AGENTS.md`, a tracker, etc.).

### Verdict
Exactly one of:
- **Safe to close** — no uncommitted work, no open risks, decisions captured.
- **Close with caveats** — safe but the user should eyeball Risks or Carry-Forward first.
- **Do not close yet** — uncommitted critical work, unverified destructive actions, or an active blocker.

Follow with a single sentence of justification tied to the sections above.

## Closing question

End the report with one short prompt, e.g.:

> Want me to expand a section, dig deeper on a specific risk, or draft a handoff note for any Carry-Forward items before you close?

Wait for the user's reply before doing anything further.

## Focus / scope knobs

If the user passes a focus hint with the invocation, narrow or emphasize the report:
- `risks` — only Risks & Gotchas + Verdict.
- `carry-forward` / `handoff` — only Carry-Forward Candidates.
- `open` / `punch list` — only Open Items.
- anything else — produce all sections but emphasize the named area.

## Quality bar

Good wrap-up:
- Reads cold in under 90 seconds.
- Distinguishes "done" from "discussed".
- Surfaces at least one risk if any real work happened.
- Verdict follows directly from the sections above it.

Bad wrap-up:
- Walls of prose.
- Timeline echoing every tool call.
- "Achieved" full of things that were only talked about.
- Verdict with no justification.
- Carry-Forward items missing a category tag.
- Suggests closing despite an unaddressed destructive action or uncommitted critical change.
