---
name: download-multicam
description: Download 6-camera multicam episode videos and calibration files. Use when the user wants to fetch episode data by episode ID, download multicam recordings from cloud storage, or retrieve calibration JSON for specific episodes.
---

# Download Multicam Episode Data

Download 6-camera multicam videos and calibration for episodes from MongoDB/cloud storage.

## Script Location

`scripts/download_multicam_episode.py` in the `ml_data_ops` repo (`~/Mecka/ml_data_ops`).

## Usage

```bash
# Single episode
python scripts/download_multicam_episode.py <episode_id> --print-summary

# Multiple episodes
python scripts/download_multicam_episode.py <id1> <id2> <id3> --print-summary

# Custom output directory (default: ./output/multicam_episodes)
python scripts/download_multicam_episode.py <episode_id> --print-summary --output ./downloads
```

Output structure: `{output}/{episode_id}/` containing 7 files:
- `recording_left_cam.mp4` (cam0, 1920x1200)
- `recording_right_cam.mp4` (cam1, 1920x1200)
- `recording_secondary_cam_2.mp4` (cam2, 640x480)
- `recording_secondary_cam_3.mp4` (cam3, 640x480)
- `recording_secondary_cam_4.mp4` (cam4, 640x480)
- `recording_secondary_cam_5.mp4` (cam5, 640x480)
- `calibration.json`

## Download Logic

The script reads Mongo to get the six `split_results.*_video_key` URLs and the `calibration_key`, then hands each URL/key to `mecka_cloud.storage.StorageClient.download()` for the actual transfer. `StorageClient` handles backend resolution and fallback — the script no longer needs per-URL backend-detection logic.

**Videos:**
1. Try batch rclone download of `split_results.video_dir_key` (R2 only; fast, 4 parallel transfers).
2. If the batch path is missing or fails: download each of the 6 videos individually via `StorageClient.download(url)`.

**Calibration:**
- Single call to `StorageClient.download(cal_url)`; StorageClient picks the backend.

**StorageClient fallback chain** (applied when a value is a bare key with no `r2://`/`do://` prefix):
1. R2 with configured `R2_BUCKET` (e.g. `data`)
2. R2 with legacy `atlas` bucket
3. DO Spaces

If `StorageClient` raises (e.g. credentials missing for one of the backends), the script falls back to repo-native downloaders: `rclone copyto` on the R2 remote, then a boto3 atlas client, then `S3Client` for DO Spaces. Explicit `r2://bucket/key` or `do://bucket/key` URIs always go straight to the named backend.

## Post-Download

`--print-summary` makes the script print a `| File | Backend | Source Key |` markdown table per episode at the end of its run. Surface that block to the user verbatim — no extra Mongo lookup needed. The flag is opt-in (default off) so library callers of `download_episode_to_dir` are unaffected.

## Conda Environment

Run with the `yolo_pose` conda environment:
```bash
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose python scripts/download_multicam_episode.py <episode_id> --print-summary
```
