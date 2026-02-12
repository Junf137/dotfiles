# Global Python Execution Policy (Conda Required)
## Non-negotiables
- Always run Python inside a conda environment (never system python, never bare venv).
- Conda is installed at: /home/junf/.local/share/miniconda3
- Never install packages globally; install only inside the activated conda env.
- Prefer `python -m pip` over `pip`.

## Choosing the conda environment
- If the env name is unknown, ask which conda env to use.

## Default command pattern (use this first)
Use `conda run` (works best for non-interactive shells and automation):
```bash
/home/junf/.local/share/miniconda3/bin/conda run -n <ENV_NAME> python -V
/home/junf/.local/share/miniconda3/bin/conda run -n <ENV_NAME> python -c "import sys; print(sys.executable)"
/home/junf/.local/share/miniconda3/bin/conda run -n <ENV_NAME> python -m pip install -r requirements.txt
/home/junf/.local/share/miniconda3/bin/conda run -n <ENV_NAME> pytest -q
```

## Interactive shells (ok to activate)
If an interactive shell is appropriate, activate like this:
```bash
source /home/junf/.local/share/miniconda3/etc/profile.d/conda.sh
conda activate <ENV_NAME>
python -V
python -c "import sys; print(sys.executable)"
python -m pip install -r requirements.txt
pytest -q
```

# Coding conventions
- Keep changes small and incremental; add or update tests for behavior changes.
- When uncertain: ask before large refactors or dependency/tooling changes.
