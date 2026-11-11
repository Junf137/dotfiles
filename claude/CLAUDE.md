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
- Run `git status` before any command that changes the index, history or working tree, and again after staging.
- Stage explicit paths only, never `git add -A` or `git add .`. Stage what the task changed, and read `git diff -- <path>` for each file first: changes that were already there belong to other work.
- Commit files whole. If one file mixes concerns, put them in one commit or ask. Use `git add -p` only when asked.
- Never discard work with reset, restore, checkout, stash, clean or an overwrite unless asked for exactly that.
- Leave scratch files alone (`plan.md`, `notes.md`, `review.md`, `code_review*.md` and the like): do not commit or delete them unless asked.
- Write commit messages as `type(scope): summary`, imperative and lowercase, unless `git log` shows the repo uses another style.
- Ask before going on when unrelated or already staged changes are in the way, when generated files changed unexpectedly, or when "commit everything" would include scratch files.

# Standardized Workflow
## Feature and pipeline cleanup
- After completing a new feature or pipeline, or reaching a reasonably complete version, check for prior smoke-test and intermediate outputs. Recommend cleanup by default, but ask the user for confirmation before deleting them.

## Responding to code reviews
- Use the `/code-review` skill when addressing review feedback.

# Response formatting (readability)
- Put the answer or conclusion in the first line, with details after it.
- Keep paragraphs to 2–3 sentences. Prefer short, one-line bullets.
