---
name: modal-data
description: Manage Modal data workflows. Use when uploading datasets to Modal, managing volumes, downloading artifacts, migrating data, or troubleshooting volume I/O performance. Do not use for launching apps, debugging live containers, or general runtime issues.
---

# Modal Data Management

## Defaults

- **Environment**: `junfeng` — do not use `main` unless explicitly asked.
- **CLI**: Prefer subcommand-level environment flags such as `modal run --env junfeng ...` or `modal volume get --env junfeng ...`. `MODAL_ENVIRONMENT=junfeng` still works as a fallback, but `--env junfeng` is the current preferred form.
- **Python SDK**: `modal.App(...)` does not take `environment_name` in the current SDK. Set environments on resource lookups and deploy/runtime entrypoints that support it, for example `modal.Volume.from_name("my-vol", environment_name="junfeng")`.

## Data Upload Strategy

Pick the method based on file characteristics:

| Scenario | Method |
|---|---|
| Few large files (weights, archives, <1K entries) | `modal volume put` directly |
| Many small files (images, thousands+) | Tar-upload-extract (or `CloudBucketMount`) |
| Very large datasets (100+ GiB, 100K+ files) | `CloudBucketMount` from R2/S3/GCS (prefer R2 — no egress fees) |
| Public URL (S3, HTTP) | Modal-side download in a container |

For datasets exceeding ~50 GiB or hundreds of thousands of files, consider `modal.CloudBucketMount` backed by object storage as the primary path — **prefer Cloudflare R2** over S3/GCS to avoid egress charges. Volume-based tar archives work well for moderate datasets (~5-50 GiB).

For functions processing large datasets, increase `ephemeral_disk` (default is small) when downloading/transforming hundreds of GiBs in `/tmp/`.

### `modal volume put` — simple but limited

```bash
modal volume put --env junfeng <volume> <local_path> <remote_path>/
```

Works for directories with few entries or large files. May fail or be unreliable on directories with many small files (thousands of images).

### Tar-upload-extract — reliable for image datasets

```bash
# 1. Tar locally
tar -cf /tmp/chunk.tar -C <dataset_root> <subdirectory>
# 2. Upload single tar (reliable at any size)
modal volume put --env junfeng <volume> /tmp/chunk.tar _staging/chunk.tar
# 3. Extract on Modal (run a function that untars + deletes staging file)
modal run --env junfeng <app>::extract_tar --tar-path _staging/chunk.tar --dest-path <dest>
# 4. Clean up local tar
rm /tmp/chunk.tar
```

Parallelizable — multiple tar-upload-extract streams work simultaneously on v2 volumes.

### Migration rules for large raw datasets

- For large raw image trees, prefer local `tar -> modal volume put -> remote extract` over volume-to-volume raw-tree copy.
- Chunk by natural dataset unit such as subject, sequence, split, or capture. Do not migrate a whole dataset as one job.
- After extracting a chunk, write `_MANIFEST/<slug>.json` with bytes/files/dirs and source metadata so verification and repair can be incremental.
- Before deleting old volumes, grep and patch runtime code for old volume names and legacy mounts. Verify code cutover before storage cleanup.

### `batch_upload` — programmatic upload from any Python client

```python
vol = modal.Volume.from_name("my-vol", environment_name="junfeng")
with vol.batch_upload() as batch:
    batch.put_file("local/path/file.bin", "/remote/path/file.bin")
    batch.put_directory("local/dir", "/remote/dir")
```

Works from any machine with the `modal` SDK. Use for automated pipelines pushing data to Modal from external systems.

### Modal-side download — fastest for public URLs

Download directly inside a container to `/tmp/` first, then move to the volume or process in-place. Avoids local upload entirely. Only works for publicly accessible URLs.

## Volume Management

### Volume v2

```bash
modal volume create --env junfeng <name> --version=2
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

### Useful commands

```bash
# List volume contents
modal volume ls --env junfeng <volume>
modal volume ls --env junfeng <volume> <subdir>/

# Download artifacts from volume
modal volume get --env junfeng <volume> <remote_path> <local_dir>/

# Delete volume contents
modal volume rm --env junfeng <volume> <path>/ -r

# Open volume in Modal dashboard
modal volume dashboard --env junfeng <volume>
```

## References

- [Modal Volumes](https://modal.com/docs/guide/volumes)
- [Large dataset ingestion](https://modal.com/docs/guide/dataset-ingestion)
- [Storing model weights](https://modal.com/docs/guide/model-weights)
- [Cloud bucket mounts](https://modal.com/docs/guide/cloud-bucket-mounts)
- [Passing local data](https://modal.com/docs/guide/local-data)

## Official Modal Docs for Agents

When you encounter a Modal data/volume topic not covered above, look it up:

- **Doc index**: https://modal.com/llms.txt — structured table of contents with links to every guide, example, and API reference page. Fetch this to find the right URL.
- **Full docs** (large): https://modal.com/llms-full.txt — all Modal documentation in one file. Only fetch if you need broad context.
- **API reference**: https://modal.com/docs/reference/modal.Volume.md, https://modal.com/docs/reference/modal.CloudBucketMount.md
