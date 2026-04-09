---
name: modal-run
description: Manage Modal runtime workflows. Use when launching Modal apps, monitoring or debugging running containers, handling timeouts, building images, managing parallel experiments, or stopping apps. Do not use for data upload, volume management, or dataset migration.
---

# Modal Run Management

## Defaults

- **Environment**: `junfeng` — do not use `main` unless explicitly asked. CLI: `MODAL_ENVIRONMENT=junfeng modal ...`, Python: `modal.App("my-app", environment_name="junfeng")`.

## Training on Modal

### 24-hour hard timeout

Modal function attempts are capped at 24 hours (86,400s). Cannot be increased. Default is 300s (5 minutes). Each retry attempt gets its own fresh timeout window. For long training runs, implement a **checkpoint-resume loop**: an outer script that relaunches the Modal function, which detects and resumes from the latest checkpoint. See Modal's [long training example](https://modal.com/docs/examples/long-training).

### `startup_timeout` — separate from `timeout`

Since modal 1.1.4, `startup_timeout` controls how long container initialization can take (loading data, importing packages, model init). If not set, `timeout` controls both startup and execution. Set this when your container has heavy `@modal.enter()` work:

```python
@app.function(gpu="A100-40GB", timeout=86400, startup_timeout=600)
```

### Parallel experiments — resilient launcher

When spawning multiple experiments, wrap each `handle.get()` in try/except. Otherwise one failure (timeout, OOM) kills the launcher and tears down all remaining experiments.

```python
@app.local_entrypoint()
def main():
    handles = []
    for name, config in EXPERIMENTS.items():
        handle = train_fn.spawn(name, config)
        handles.append((name, handle))

    results = {}
    for name, handle in handles:
        try:
            handle.get()
            results[name] = "completed"
        except Exception as e:
            results[name] = f"failed: {e}"

    for name, status in results.items():
        print(f"  {name}: {status}")
```

### Container image — common missing packages

`debian_slim` lacks system libraries required by OpenCV (`cv2`), which many ML libraries (supervision, albumentations, etc.) import transitively:

```python
modal.Image.debian_slim(python_version="3.11")
    .apt_install("libgl1", "libglib2.0-0")   # required for cv2
    .pip_install(...)
```

Without these, you get: `ImportError: libGL.so.1: cannot open shared object file`

### Local source mounting (modal ≥1.0)

`modal.Mount` is removed. Use `Image.add_local_dir()`, `Image.add_local_file()`, or `Image.add_local_python_source()` to include local source code in the container:

```python
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(...)  # install dependencies only
    .add_local_dir("src", remote_path="/root/project-src")
)

# In the function, add to sys.path:
import sys
sys.path.insert(0, "/root/project-src")
```

See the [Modal 1.0 migration guide](https://modal.com/docs/guide/modal-1-0-migration) for details.

### Log streams and CLI behavior

`modal run` CLI may lose its log stream on long tasks. The remote container keeps running — only local stdout stops. Use W&B, check the volume directly, or use `modal container exec` for progress.

**Since 1.4.0**, `modal app logs` defaults to showing the most recent 100 entries (no longer streams). Use `--follow` to restore streaming behavior:

```bash
modal app logs <app-name> --follow              # stream live
modal app logs <app-name> --tail 1000           # last 1000 entries
modal app logs <app-name> --since 4h            # last 4 hours
modal app logs <app-name> --search "error"      # filter by keyword
modal app logs <app-name> --source stderr       # stdout/stderr/system
modal app logs <app-name> --function train_fn   # filter by function
```

### `modal serve` — hot-reload for development

`modal serve <app.py>` auto-updates the app when files change. Useful for iterating on web endpoints, cron schedules, or job queues without redeploying. Press Ctrl+C to stop.

### Deployment strategies

```bash
modal deploy app.py                        # rolling (default) — old containers drain gracefully
modal deploy app.py --strategy recreate    # immediately terminate old containers
```

## Debugging Running Containers

### `modal shell` — interactive debug shell

Launches a shell into a running container with pre-installed tools (vim, nano, ps, strace, curl, py-spy):

```bash
modal shell <container-id>                     # shell into running container
modal shell <app.py>::my_function              # shell with same image/secrets as function
modal shell <app.py>::my_function --cmd python # override default /bin/bash
```

Shell terminates when the container finishes. Use for live inspection, profiling with py-spy, or ad-hoc debugging.

### `modal container exec` — inspect live containers

The most reliable way to check training progress:

```bash
# List running containers for an app
modal container list | grep <app-id>

# Check GPU utilization
modal container exec <container-id> -- nvidia-smi

# Check training output files
modal container exec <container-id> -- ls /output/experiment_name/

# Run arbitrary Python to read TensorBoard events, check metrics, etc.
modal container exec <container-id> -- python3 -c "..."
```

**Environment selection:** `container exec` does not support `--env`. Use the `MODAL_ENVIRONMENT` env var instead:

```bash
# Wrong — will error
modal container exec --env junfeng <container-id> -- nvidia-smi

# Correct
MODAL_ENVIRONMENT=junfeng modal container exec <container-id> -- nvidia-smi
```

See [Developing and debugging](https://modal.com/docs/guide/developing-debugging) in Modal docs.

### Debug environment variables

- `MODAL_LOGLEVEL=DEBUG` — verbose client logs (set as Modal Secret for remote containers)
- `MODAL_TRACEBACK=1` — show full stack traces for client-side exceptions

### Useful commands

```bash
# Check app status
modal app list

# Filter containers by app
modal container list --app-id <app-id>

# Stop a running app
modal app stop <app-id>

# Open app in Modal dashboard
modal app dashboard <app-name>

# Check changelog for recent changes
modal changelog --since=1.3
```

### CRITICAL: Never stop apps you did not create

Before running `modal app stop`, **verify the full app name and confirm you launched it**. The `modal app list` output truncates descriptions (e.g., `mecka-temp…` could be `mecka-temporal-lite` or `mecka-temporary-xyz`). A wrong stop kills someone else's running job with no undo.

**Rules:**
1. Only stop apps whose full app ID you created in the current session
2. If the description is truncated and you are not 100% certain it's yours, do NOT stop it — ask the user first
3. Never bulk-stop apps. Stop one at a time after verifying each ID
4. When multiple apps share a similar name prefix, list containers (`modal container list`) to see which are actively running and what they're doing before stopping any

## Autoscaler Parameters (renamed in 1.0+)

| Old (removed) | New |
|---|---|
| `keep_warm` | `min_containers` |
| `concurrency_limit` | `max_containers` |
| `container_idle_timeout` | `scaledown_window` |
| `max_inputs` | `single_use_containers=True` (boolean, since 1.3.0) |

## References

- [Timeouts](https://modal.com/docs/guide/timeouts)
- [Long resumable training](https://modal.com/docs/examples/long-training)
- [Developing and debugging](https://modal.com/docs/guide/developing-debugging)
- [Modal 1.0 migration](https://modal.com/docs/guide/modal-1-0-migration)
- [GPU acceleration](https://modal.com/docs/guide/gpu)
- [Failures and retries](https://modal.com/docs/guide/retries)
- [Preemption](https://modal.com/docs/guide/preemption)

## Official Modal Docs for Agents

When you encounter a Modal topic not covered above, look it up:

- **Doc index**: https://modal.com/llms.txt — structured table of contents with links to every guide, example, and API reference page. Fetch this to find the right URL.
- **Full docs** (large): https://modal.com/llms-full.txt — all Modal documentation in one file. Only fetch if you need broad context.
- **Changelog**: https://modal.com/docs/reference/changelog — check for recent changes, new features, deprecations.
