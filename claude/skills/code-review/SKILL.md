---
name: code-review
description: Perform a code review and write the findings to `code_review.md`. Use when the user asks for a code review, diff review, or audit of specific files or the whole repo.
argument-hint: [optional scope — e.g. a file path, directory, feature name, or refactor description]
user-invocable: true
disable-model-invocation: true
---

# Code Review

Produce a written code review and save it to `code_review.md` at the repo root.

## 1. Determine scope

- **No scope given** → review the entire repo.
- **Scope given** (a file, directory, feature, refactor description, or diff range) → limit the review to that scope only.

State the resolved scope at the top of the review.

## 2. Lead with understanding, not findings

Before any issues, open the review with a short **Scope & Understanding** section:

- What the changes (or the code under review) appear to be doing.
- The apparent intent or direction — the "why", as you read it.
- Any assumptions you are making about context.

Purpose: the author can immediately tell whether you actually understood the code and can flag any context mismatch before reading the critique. If you misread the intent, the rest of the review is likely off-target.

## 3. Review body

After Scope & Understanding, list findings. For each:

- **Location** — `path:line` or symbol.
- **Severity** — blocker / major / minor / nit.
- **Observation** — what you see.
- **Suggestion** — concrete change or question.

Group by severity or by file, whichever reads cleaner. Skip bike-shedding.

## 4. Output file

- Always write to `code_review.md` at the repo root.
- If `code_review.md` already exists, write to a non-conflicting name instead (e.g. `code_review.2.md`, or `code_review-<short-scope>.md`). Never overwrite an existing review file.
- End the file with a short **Summary** line: overall verdict (approve / request changes / needs discussion) and top 1–3 priorities.

## Quality bar

Good review:
- Opens with scope + understanding the author can sanity-check in 30 seconds.
- Findings cite exact locations and propose concrete changes.
- Severity labels match reality — not every nit is a blocker.

Bad review:
- Dives into nits before showing you understood the change.
- Vague complaints with no file/line.
- Rewrites the author's design under the guise of "review".
