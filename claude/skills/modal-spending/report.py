"""Modal billing report aggregator.

Reads `modal billing report --json` output (from stdin or by running modal
itself) and prints a markdown summary: per-environment totals, top-N apps,
grand total, and a daily breakdown when the range spans >1 day.
"""

import argparse
import json
import os
import subprocess
import sys
from collections import defaultdict


CONDA = f"{os.environ['HOME']}/.local/share/miniconda3/bin/conda"
FLAG_THRESHOLD = 500.0


def fetch(start: str, env_name: str) -> list[dict]:
    out = subprocess.check_output(
        [CONDA, "run", "-n", env_name, "modal", "billing", "report",
         "--start", start, "--json"],
        text=True,
    )
    lo, hi = out.find("["), out.rfind("]")
    if lo == -1 or hi == -1:
        sys.exit(f"could not find JSON array in modal output:\n{out}")
    return json.loads(out[lo:hi + 1])


def aggregate(rows: list[dict]):
    env_totals: dict[str, float] = defaultdict(float)
    app_env_totals: dict[tuple[str, str], float] = defaultdict(float)
    daily_env: dict[str, dict[str, float]] = defaultdict(lambda: defaultdict(float))
    dates: set[str] = set()
    for row in rows:
        env = row["Environment"]
        app = row["Description"]
        cost = float(row["Cost"])
        day = row["Interval Start"][:10]
        env_totals[env] += cost
        app_env_totals[(app, env)] += cost
        daily_env[day][env] += cost
        dates.add(day)
    return env_totals, app_env_totals, daily_env, sorted(dates)


def render(start: str, env_totals, app_env_totals, daily_env, dates, top_n: int):
    grand = sum(env_totals.values())
    print(f"## Modal Spending: since {start}")
    print()
    print("| Environment | Total |")
    print("|---|---|")
    flagged = []
    for env, tot in sorted(env_totals.items(), key=lambda x: -x[1]):
        marker = " :warning:" if tot > FLAG_THRESHOLD else ""
        print(f"| {env} | ${tot:,.2f}{marker} |")
        if tot > FLAG_THRESHOLD:
            flagged.append((env, tot))
    print()
    print(f"**Grand Total: ${grand:,.2f}**")
    print()

    print(f"### Top {top_n} Apps")
    print()
    print("| App | Environment | Cost |")
    print("|---|---|---|")
    for (app, env), cost in sorted(app_env_totals.items(), key=lambda x: -x[1])[:top_n]:
        print(f"| {app} | {env} | ${cost:,.2f} |")
    print()

    if len(dates) > 1:
        print("### Daily Breakdown")
        print()
        envs = sorted(env_totals.keys())
        print("| Day | " + " | ".join(envs) + " | Day Total |")
        print("|" + "---|" * (len(envs) + 2))
        for day in dates:
            day_total = sum(daily_env[day].values())
            cells = [f"${daily_env[day].get(e, 0):,.2f}" for e in envs]
            print(f"| {day} | " + " | ".join(cells) + f" | ${day_total:,.2f} |")
        print()

    if flagged:
        names = ", ".join(f"{e} (${t:,.2f})" for e, t in flagged)
        print(f"> :warning: Environments over ${FLAG_THRESHOLD:,.0f}: {names}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--start", default="1 day ago",
                   help='Start of the billing range (e.g. "1 day ago", "last week").')
    p.add_argument("--env", default="yolo_pose",
                   help="Conda env that has the modal CLI installed.")
    p.add_argument("--top", type=int, default=10, help="How many top apps to show.")
    p.add_argument("--stdin", action="store_true",
                   help="Read billing JSON from stdin instead of invoking modal.")
    args = p.parse_args()

    rows = json.load(sys.stdin) if args.stdin else fetch(args.start, args.env)
    env_totals, app_env_totals, daily_env, dates = aggregate(rows)
    render(args.start, env_totals, app_env_totals, daily_env, dates, args.top)


if __name__ == "__main__":
    main()
