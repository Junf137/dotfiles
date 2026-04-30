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
- Use the `/git-workflow` skill for git status, staging, commits, stash, reset, checkout, switch, merge, rebase, or commit-message work.

# Standardized Workflow
## Responding to code reviews
- Use the `/code-review-response` skill when addressing review feedback.
