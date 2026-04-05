---
name: "modal-run"
description: "Use when the user is launching Modal apps, debugging running containers, handling timeouts, building container images, managing parallel experiments, or stopping apps; do not use for data upload, volume management, or dataset migration."
---

# Modal Run Management

## Defaults

- **Environment**: `junfeng` — do not use `main` unless explicitly asked. CLI: `MODAL_ENVIRONMENT=junfeng modal ...`, Python: `modal.App("my-app", environment_name="junfeng")`.

## Training on Modal

### 24-hour hard timeout

Modal function attempts are capped at 24 hours (86,400s). Cannot be increased. For long training runs, implement a **checkpoint-resume loop**: an outer script that relaunches the Modal function, which detects and resumes from the latest checkpoint. See Modal's [long training example](https://modal.com/docs/examples/long-training).

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

## Debugging Running Containers

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

### Useful commands

```bash
# Check app status
modal app list

# Stop a running app
modal app stop <app-id>
```

### CRITICAL: Never stop apps you did not create

Before running `modal app stop`, **verify the full app name and confirm you launched it**. The `modal app list` output truncates descriptions (e.g., `mecka-temp…` could be `mecka-temporal-lite` or `mecka-temporary-xyz`). A wrong stop kills someone else's running job with no undo.

**Rules:**
1. Only stop apps whose full app ID you created in the current session
2. If the description is truncated and you are not 100% certain it's yours, do NOT stop it — ask the user first
3. Never bulk-stop apps. Stop one at a time after verifying each ID
4. When multiple apps share a similar name prefix, list containers (`modal container list`) to see which are actively running and what they're doing before stopping any

## References

- [Timeouts](https://modal.com/docs/guide/timeouts)
- [Long resumable training](https://modal.com/docs/examples/long-training)
- [Developing and debugging](https://modal.com/docs/guide/developing-debugging)
- [Modal 1.0 migration](https://modal.com/docs/guide/modal-1-0-migration)
