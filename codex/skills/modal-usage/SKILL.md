---
name: "modal-usage"
description: "Use when the user is running ML training workloads on Modal, managing Modal volumes, uploading datasets to Modal, debugging running Modal containers, or asking about Modal-specific patterns like checkpoint-resume, tar-upload-extract, or volume I/O performance; do not use for general cloud computing, AWS/GCP, or non-Modal deployment questions."
---

# Modal ML Training — Operational Knowledge

Generic patterns and pitfalls for running ML training on Modal.

## Data Upload Strategy

Pick the method based on file characteristics:

| Scenario | Method |
|---|---|
| Few large files (weights, archives, <1K entries) | `modal volume put` directly |
| Many small files (images, thousands+) | Tar-upload-extract (or `CloudBucketMount`) |
| Very large datasets (100+ GiB, 100K+ files) | `CloudBucketMount` from S3/GCS/R2 |
| Public URL (S3, HTTP) | Modal-side download in a container |

For datasets exceeding ~50 GiB or hundreds of thousands of files, consider `modal.CloudBucketMount` backed by object storage (S3, GCS, R2) as the primary path. Volume-based tar archives work well for moderate datasets (~5-50 GiB).

### `modal volume put` — simple but limited

```bash
modal volume put <volume> <local_path> <remote_path>/
```

Works for directories with few entries or large files. May fail or be unreliable on directories with many small files (thousands of images).

### Tar-upload-extract — reliable for image datasets

```bash
# 1. Tar locally
tar -cf /tmp/chunk.tar -C <dataset_root> <subdirectory>
# 2. Upload single tar (reliable at any size)
modal volume put <volume> /tmp/chunk.tar _staging/chunk.tar
# 3. Extract on Modal (run a function that untars + deletes staging file)
modal run <app>::extract_tar --tar-path _staging/chunk.tar --dest-path <dest>
# 4. Clean up local tar
rm /tmp/chunk.tar
```

Parallelizable — multiple tar-upload-extract streams work simultaneously on v2 volumes.

### Modal-side download — fastest for public URLs

Download directly inside a container. Avoids local upload entirely. Only works for publicly accessible URLs.

## Volume Management

### Volume v2

```bash
modal volume create <name> --version=2
```

- v1 has a **500K inode hard limit** — image datasets easily exceed this (`ENOSPC` errors)
- v2 removes the inode limit and supports concurrent writes from multiple containers for distinct files
- v2 is currently beta — Modal does not yet recommend treating it as no-data-loss storage. Always call `commit()` and design for checkpoint/resume

### `volume.reload()` semantics

A fresh container mounts the latest **committed** Volume state — it sees data committed before it started. `reload()` is needed by an **already-running** container to pick up commits made by other containers after it mounted the Volume.

### Cross-container visibility

Containers sharing a volume see their **own writes immediately** but may not see other containers' uncommitted writes. Don't rely on one container reading another's in-progress output in real time. Call `volume.reload()` when you need fresh reads of another container's data.

## Data I/O During Training

### Volume I/O is too slow for dataset reads

Modal volumes are network-attached storage. **Random reads of many small files** (images, labels) cause the training process to block on I/O — GPU sits idle while the CPU waits on network round-trips. Datasets that load in seconds from local SSD can be orders of magnitude slower on a volume.

**Pattern: keep a tar on the volume, extract to local `/tmp` per container.**

```python
@app.function(gpu="A100-40GB", volumes={"/data": data_vol, "/output": out_vol})
def train(config: dict):
    import subprocess, os

    # Extract dataset from volume tar to local storage (fast sequential read)
    local_data = "/tmp/dataset"
    if not os.path.exists(local_data):
        subprocess.run(["tar", "xf", "/data/dataset.tar", "-C", "/tmp/"], check=True)

    # Read from local storage during training
    model.train(dataset_dir=local_data, ...)
```

This means uploading the tar is a two-purpose operation: it's both the upload format AND the runtime cache. Keep the tar on the volume permanently — don't delete it after extraction.

**Also slow: `shutil.copytree` from volume.** Copying hundreds of thousands of files one-by-one from network storage is nearly as slow as reading them directly. Tar extraction does a single sequential read, which network storage handles well. This is consistent with Modal's own guidance to store compressed archives and do heavy transforms on `/tmp`.

### Volume I/O is fine for checkpoint writes

Checkpoint files are large (hundreds of MB) and written infrequently (once per epoch). Writing output directly to the volume path (`/output/...`) works well and has a critical advantage: **if the container is killed (timeout, OOM), checkpoints written to a v2 volume are more likely to survive than data on local `/tmp`.** Writing to local storage and copying at the end risks losing everything.

```python
# DO: write output to volume directly
model.train(output_dir="/output/experiment_name", ...)

# DON'T: write to /tmp and copy at the end — data lost if container dies
model.train(output_dir="/tmp/output/experiment_name", ...)  # lost on timeout
```

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
# List volume contents
modal volume ls <volume>
modal volume ls <volume> <subdir>/

# Download artifacts from volume
modal volume get <volume> <remote_path> <local_dir>/

# Delete volume contents
modal volume rm <volume> <path>/ -r

# Check app status
modal app list

# Stop a running app
modal app stop <app-id>
```

## References

- [Modal Volumes](https://modal.com/docs/guide/volumes)
- [Large dataset ingestion](https://modal.com/docs/guide/dataset-ingestion)
- [Storing model weights](https://modal.com/docs/guide/model-weights)
- [Timeouts](https://modal.com/docs/guide/timeouts)
- [Long resumable training](https://modal.com/docs/examples/long-training)
- [Developing and debugging](https://modal.com/docs/guide/developing-debugging)
- [Modal 1.0 migration](https://modal.com/docs/guide/modal-1-0-migration)
