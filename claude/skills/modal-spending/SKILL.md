---
name: modal-spending
description: Analyze Modal billing and spend. Use when the user wants per-environment costs, top spending apps, billing reports, or a spend breakdown for a requested time range.
argument-hint: [time-range, e.g. "2 days ago", "last week", "last month" — defaults to 24hrs]
user-invocable: true
allowed-tools: Bash
---

# Modal Spending Analysis

Analyze Modal billing data grouped by environment.

## Parameters

- `$ARGUMENTS` — time range for the report start date. If empty, default to `"1 day ago"` (past 24 hours).

## Steps

Run the bundled aggregator — it calls `modal billing report --json` and prints the markdown summary directly. Do NOT re-implement the parsing logic inline; edit `report.py` if the output needs changing.

```bash
RANGE="${ARGUMENTS:-1 day ago}"
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose python3 "$HOME/.claude/skills/modal-spending/report.py" --start "$RANGE"
```

The script produces:

- Per-environment summary table (sorted descending, flagged if > $500).
- Top 10 apps across all environments.
- Grand total.
- Daily breakdown when the range spans multiple days.

Useful flags: `--top N` to change the app count, `--env <conda-env>` if `yolo_pose` doesn't have the modal CLI, `--stdin` to pipe in pre-fetched JSON.

When using `--stdin` with piped JSON, add `--no-capture-output` to `conda run`; plain `conda run` does not forward stdin reliably:

```bash
modal billing report --start "$RANGE" --json \
  | $HOME/.local/share/miniconda3/bin/conda run --no-capture-output -n yolo_pose python3 "$HOME/.claude/skills/modal-spending/report.py" --stdin
```

Forward the script's output to the user verbatim — no extra re-formatting needed. Add a one- or two-line narrative observation (biggest driver, notable spike) after the tables if something stands out.

Note: `modal billing report` is GA since modal 1.3.3.

## Official Modal Docs for Agents

- **Billing guide**: https://modal.com/docs/guide/billing
- **Doc index**: https://modal.com/llms.txt — fetch to find any Modal doc page by topic.
