# Global Python Execution Policy (Conda Required)
## Non-negotiables
- Always run Python inside a conda environment (never use system python or bare venv, unless specially asked to).
- Conda is installed at: $HOME/.local/share/miniconda3
- Never install packages globally; install only inside the activated conda environment.
- Prefer `python -m pip` over `pip`.

## Choosing the conda environment
- If the environment name is unknown, list available conda environment names and ask the user which one to use.

## Default command pattern (use this first)
Use `conda run` (works best for non-interactive shells and automation):
```bash
$HOME/.local/share/miniconda3/bin/conda run -n <ENV_NAME> python -V
$HOME/.local/share/miniconda3/bin/conda run -n <ENV_NAME> python -c "import sys; print(sys.executable)"
$HOME/.local/share/miniconda3/bin/conda run -n <ENV_NAME> python -m pip install -r requirements.txt
$HOME/.local/share/miniconda3/bin/conda run -n <ENV_NAME> pytest -q
```

## Interactive shells (ok to activate)
If an interactive shell is appropriate, activate like this:
```bash
source $HOME/.local/share/miniconda3/etc/profile.d/conda.sh
conda activate <ENV_NAME>
python -V
python -c "import sys; print(sys.executable)"
python -m pip install -r requirements.txt
pytest -q
```

# Coding conventions
- Keep changes small and incremental; add or update tests for behavior changes.
- When uncertain: ask before large refactors or dependency/tooling changes.

# Git
- Never commit `plan.md`, `code_review.md`, or similar planning/review files, but do not automatically delete them either.
- Before writing a commit message, check `git log` for recent commits and follow the same format, prefix conventions, and tone.

## Git Safety: Always Check Before Acting
- **Run `git status` before every git operation** (commit, add, stash, reset, checkout, etc.) to understand the current repo state.
- **Never blindly `git add -A` or `git add .`**. Only stage the files relevant to the current task. Pre-existing staged or unstaged changes may be unrelated—adding everything risks committing someone else's or earlier unfinished work.
- **Operate at the file level**. Do not split or partially stage changes within a single file (`git add -p`). File-level adds/commits keep operations simple and reduce the risk of broken or incomplete commits.
- **Purpose**: Prevent accidental overwrites, unintended commits, and tangled histories.

# Standardized Workflow
## Responding to code reviews
- Read the code review content carefully and cross-check each point against the actual codebase.
- Either correct the code if the review is valid, or defend the implementation with reasoning if the review is incorrect.
- If the code review is provided in an editable file, append the response and action result to that file.
