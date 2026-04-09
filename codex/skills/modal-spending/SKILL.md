---
name: modal-spending
description: Analyze Modal billing and spend. Use when the user wants per-environment costs, top spending apps, billing reports, or a spend breakdown for a requested time range.
---

# Modal Spending Analysis

Analyze Modal billing data grouped by environment.

## Parameters

Use the user-provided time range if present. If the user did not specify one, default to `"1 day ago"` (past 24 hours).

## Steps

1. Run the billing report:

```bash
RANGE="<requested time range or 1 day ago>"
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose modal billing report --start "$RANGE" --json
```

2. Parse the JSON output with Python in the same conda environment to produce:

   a. **Per-environment summary table** — environment name, total cost, sorted descending by cost.
   b. **Top 10 apps across all environments** — app name, environment, cost.
   c. **Grand total** across all environments.
   d. **Daily breakdown** if the range spans multiple days — show cost per environment per day.

3. Present results as a clean markdown table. Flag any environment spending over $500 in the period.

Note: `modal billing report` is GA since modal 1.3.3.

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

## Official Modal Docs for Agents

- **Billing guide**: https://modal.com/docs/guide/billing
- **Doc index**: https://modal.com/llms.txt — fetch to find any Modal doc page by topic.
