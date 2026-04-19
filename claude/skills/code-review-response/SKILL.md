---
name: code-review-response
description: Respond to a code review by verifying each point against the actual code, then either fixing the issue or defending the implementation with reasoning. Use when the user hands you a review (file, paste, or PR comments) and wants it addressed.
argument-hint: [path to the review file, or inline review text]
user-invocable: true
disable-model-invocation: true
---

# Code Review Response

Work through a code review point-by-point, verifying each against the current code before acting.

## Inputs

- A review in an editable file (e.g. `code_review.md`), pasted text, or PR comments.
- If the review came from the `code-review` skill, it will be at `code_review.md` (or a `code_review*.md` variant). Confirm with the user which file if ambiguous.

## Per-point workflow

For every reviewer point:

1. **Locate** the code the point refers to (`path:line` or symbol).
2. **Verify** the claim against the actual implementation — read the file, run the test, check the type, etc. Do not take the review at face value.
3. **Decide**:
   - **Valid** → make the fix. Keep it minimal and scoped to what the point actually calls for.
   - **Invalid or partially wrong** → do not change the code. Write a defense: why the current implementation is correct, what the reviewer may have missed, or what constraint drove the choice.
   - **Needs clarification** → call it out instead of guessing.
4. **Record** the response (see output rules).

## Output rules

- **If the review is in an editable file**: append the response and action result directly under (or next to) each point in that file. Do not rewrite the reviewer's original text — add yours beneath it, clearly marked (e.g. `**Response:**` or `> response:`).
- **If the review was pasted or came from comments**: produce a response block in the chat, structured point-by-point, that the user can copy back into the review tool.

Each response entry should include:
- Verdict: **Fixed** / **Defended** / **Needs clarification**.
- For Fixed: the file(s) and a one-line description of the change.
- For Defended: the reasoning, tied to code or constraints.
- For Needs clarification: the specific question back to the reviewer.

## Closing summary

After working through all points, end with a short tally:
- N fixed, N defended, N awaiting clarification.
- List of files touched.
- Any follow-up the user should decide on (e.g. tests to run, adjacent cleanup intentionally skipped).

## Quality bar

Good response:
- Every point verified against real code, not just the review text.
- Fixes are minimal and match the point's intent.
- Defenses cite something concrete (code, constraint, prior decision) — not just "I think it's fine".

Bad response:
- Blanket-applying every suggestion without verification.
- Silent disagreement (ignoring a point without a defense).
- Bundling unrelated refactors into the fix.
