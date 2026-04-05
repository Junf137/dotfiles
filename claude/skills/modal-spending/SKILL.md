---
name: modal-spending
description: Check and analyze Modal cloud spending by environment. Use when the user wants to see billing, costs, or spending breakdowns.
argument-hint: [time-range, e.g. "2 days ago", "last week", "last month" — defaults to 24hrs]
user-invocable: true
allowed-tools: Bash
---

# Modal Spending Analysis

Analyze Modal billing data grouped by environment.

## Parameters

- `$ARGUMENTS` — time range for the report start date. If empty, default to `"1 day ago"` (past 24 hours).

## Steps

1. Run the billing report:

```bash
RANGE="${ARGUMENTS:-1 day ago}"
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose modal billing report --start "$RANGE" --json
```

2. Parse the JSON output with Python (`conda run -n yolo_pose python3`) to produce:

   a. **Per-environment summary table** — environment name, total cost, sorted descending by cost.
   b. **Top 10 apps across all environments** — app name, environment, cost.
   c. **Grand total** across all environments.
   d. **Daily breakdown** if the range spans multiple days — show cost per environment per day.

3. Present results as a clean markdown table. Flag any environment spending over $500 in the period.

## Output Format

```
## Modal Spending: <time range>

| Environment | Total |
|---|---|
| ... | $X.XX |

**Grand Total: $X.XX**

### Top Apps
| App | Environment | Cost |
|---|---|---|
| ... | ... | $X.XX |
```
