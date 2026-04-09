---
name: "download-multicam"
description: "Use when the user wants to download 6-camera multicam episode videos and calibration files by episode ID, fetch multicam recordings from cloud storage, or get calibration JSON for specific episodes."
---

# Download Multicam Episode Data

Download 6-camera multicam videos and calibration for episodes from MongoDB/cloud storage.

## Script Location

`scripts/download_multicam_episode.py` in the `ml_data_ops` repo (`~/Mecka/ml_data_ops`).

## Usage

```bash
# Single episode
python scripts/download_multicam_episode.py <episode_id>

# Multiple episodes
python scripts/download_multicam_episode.py <id1> <id2> <id3>

# Custom output directory (default: ./output/multicam_episodes)
python scripts/download_multicam_episode.py <episode_id> --output ./downloads
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

**Videos:**
1. Detect backend by parsing the first video key URL (`r2://...` = R2, raw path = DO Spaces)
2. If R2: try batch rclone download of the whole `video_dir_key` folder (fast, 4 parallel transfers)
3. If DO Spaces or batch fails: download each of the 6 videos individually

**Calibration:**
1. Download from whichever backend the `calibration_key` URL maps to (usually DO Spaces)
2. If DO Spaces fails: fallback to R2 (`r2://atlas/<same_key>`)

## Post-Download

After the download completes, show a summary table listing each downloaded file with its source backend and storage key. Example:

| File | Backend | Source Key |
|---|---|---|
| recording_left_cam.mp4 | DO Spaces | `episodes/<id>/hands_multicam/recording_left_cam.mp4` |
| recording_right_cam.mp4 | DO Spaces | `episodes/<id>/hands_multicam/recording_right_cam.mp4` |
| ... | ... | ... |
| calibration.json | R2 | `multicam-calibrations/ATLASHX282_20260212_005109.json` |

To get the source keys, query the episode from MongoDB and read `split_results.*_video_key` for videos and `calibration_key` for calibration. Use `parse_storage_url()` to determine the backend for each.

## Conda Environment

Run with the `yolo_pose` conda environment:
```bash
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose python scripts/download_multicam_episode.py <episode_id>
```
