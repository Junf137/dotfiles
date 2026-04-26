---
name: cva-stats
description: Use when asked to inspect CVA or Escanor website data from the ml_data_ops repo, including listing available projects, getting project stats and per-status episode lists, or looking up CVA episode status by source episode ID or Escanor episode ID. Prefer the Python utilities in ml_data_ops.dataset.cva.website and avoid adding new CLI commands unless explicitly requested.
argument-hint: [optional request, e.g. "list projects", "stats for Hand Tracking Multicam - 2", or "lookup source episode 65b..."]
user-invocable: true
allowed-tools: Bash
---

# Cva Stats

## Overview

Use this skill for ad hoc CVA website queries against the live MongoDB data behind the `ml_data_ops` repo.

Keep the workflow lightweight:
- Run one-off Python with `conda run -n yolo_pose`
- Set `PYTHONPATH=/home/junf/Mecka` so this checkout wins over other editable installs
- Use `ml_data_ops.dataset.cva.website` for project discovery and episode lookup
- Do not add new CLI commands unless the user explicitly asks for them

## Default Behavior

If the user invokes `/cva-stats` without a concrete request, reply with a concise option list instead of running a query.

Use this shape:

```text
Available cva-stats options:
1. List available CVA projects
2. Show summary stats for one project
3. Export all episodes in a project grouped by status to a JSON file
4. Look up one episode by source episode ID
5. Look up one episode by Escanor episode ID
6. Convert source episode IDs and Escanor episode IDs
```

Keep it short. Do not dump implementation details unless the user asks for one of the options.

## Setup

Work from `/home/junf/Mecka/ml_data_ops`.

Use this boilerplate for most queries:

```bash
PYTHONPATH=/home/junf/Mecka \
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose python - <<'PY'
from ml_data_ops.dataset.cva.export import _ensure_mongodb_env
from ml_data_ops.cloud.backends.mongodb import MongoDBBackend

_ensure_mongodb_env()
with MongoDBBackend() as mongodb:
    db = mongodb.client["mecka-ai"]
    # add query code here
PY
```

`_ensure_mongodb_env()` bridges `DATABASE_URL` into `MONGODB_URI` when needed.

## 1. List Available Projects

Use `list_available_projects()` for project discovery.

```bash
PYTHONPATH=/home/junf/Mecka \
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose python - <<'PY'
from ml_data_ops.dataset.cva.export import _ensure_mongodb_env
from ml_data_ops.cloud.backends.mongodb import MongoDBBackend
from ml_data_ops.dataset.cva.website import list_available_projects

_ensure_mongodb_env()
with MongoDBBackend() as mongodb:
    db = mongodb.client["mecka-ai"]
    projects = list_available_projects(
        db,
        include_episode_stats=True,
        include_annotation_types=False,
    )

    for project in projects:
        stats = project.get("episodeStats", {})
        print(
            f"{project['projectId']}\t{project['name']}\t"
            f"episodes={stats.get('total', 0)}"
        )
PY
```

If annotation types matter, rerun with `include_annotation_types=True`.

## 2. Project Stats And Episodes By Status

### Project detail stats

Use `get_project_info()` when you need one project's counts and metadata.

```bash
PYTHONPATH=/home/junf/Mecka \
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose python - <<'PY'
from pprint import pprint

from ml_data_ops.dataset.cva.export import _ensure_mongodb_env
from ml_data_ops.cloud.backends.mongodb import MongoDBBackend
from ml_data_ops.dataset.cva.website import ProjectInfoQuery, get_project_info

_ensure_mongodb_env()
with MongoDBBackend() as mongodb:
    db = mongodb.client["mecka-ai"]
    info = get_project_info(
        db,
        project_name="Hand Tracking Multicam - 2",
        query=ProjectInfoQuery(
            include_annotation_config=True,
            include_status_counts=True,
            include_current_stage_counts=True,
            include_scene_ids=True,
            include_annotation_types=True,
            sample_episode_limit=5,
        ),
    )

    pprint(info["project"])
    pprint(info["episodeStats"])
    pprint(info.get("statusCounts", {}))
    pprint(info.get("currentStageCounts", {}))
PY
```

### Export episodes grouped by status to JSON

Use `build_project_episodes_status_export()` plus `write_project_episodes_status_export()`.

The JSON output is manifest-like and includes:
- top-level project metadata similar to the CVA label export `manifest.json`
- `projectId`, `projectName`, `annotationFps`, `annotationTypes`, `episodeDirectoryName`
- per-episode `videoFps`
- `statusCounts`, `currentStageCounts`, `videoFpsCounts`, flat `episodes`, and grouped `statusGroups`

For programmatic consumption, prefer the top-level `episodes` list as the canonical flat view.
`statusGroups` and `episodesByStatus` are convenience projections of the same episode records.

```bash
PYTHONPATH=/home/junf/Mecka \
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose python - <<'PY'
from pathlib import Path

from ml_data_ops.dataset.cva.export import _ensure_mongodb_env
from ml_data_ops.cloud.backends.mongodb import MongoDBBackend
from ml_data_ops.dataset.cva.website import (
    build_project_episodes_status_export,
    write_project_episodes_status_export,
)

_ensure_mongodb_env()
with MongoDBBackend() as mongodb:
    db = mongodb.client["mecka-ai"]
    export = build_project_episodes_status_export(
        db,
        project_name="Hand Tracking Multicam - 2",
        include_edited_annotation_types=False,
    )
    output_path = write_project_episodes_status_export(
        Path("output/cva_hand_tracking_multicam_2_status_export.json"),
        export,
    )
    print(output_path)
PY
```

## 3. Query One Episode By Escanor ID Or Source ID

Use `find_episode_id_mappings()` for CVA website status lookups. This returns `status` and `currentStage` directly from `escanor_episodes`.

### Lookup by source episode ID

```bash
PYTHONPATH=/home/junf/Mecka \
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose python - <<'PY'
from ml_data_ops.dataset.cva.export import _ensure_mongodb_env
from ml_data_ops.cloud.backends.mongodb import MongoDBBackend
from ml_data_ops.dataset.cva.website import find_episode_id_mappings

SOURCE_EPISODE_ID = "65b000000000000000000001"

_ensure_mongodb_env()
with MongoDBBackend() as mongodb:
    db = mongodb.client["mecka-ai"]
    rows = find_episode_id_mappings(db, source_episode_ids=[SOURCE_EPISODE_ID])

    if not rows:
        print("No CVA episode found for that source episode ID")
    for row in rows:
        print(row)
PY
```

### Lookup by Escanor episode ID

```bash
PYTHONPATH=/home/junf/Mecka \
$HOME/.local/share/miniconda3/bin/conda run -n yolo_pose python - <<'PY'
from ml_data_ops.dataset.cva.export import _ensure_mongodb_env
from ml_data_ops.cloud.backends.mongodb import MongoDBBackend
from ml_data_ops.dataset.cva.website import find_episode_id_mappings

ESCANOR_EPISODE_ID = "66c000000000000000000001"

_ensure_mongodb_env()
with MongoDBBackend() as mongodb:
    db = mongodb.client["mecka-ai"]
    rows = find_episode_id_mappings(db, escanor_episode_ids=[ESCANOR_EPISODE_ID])

    if not rows:
        print("No CVA episode found for that Escanor episode ID")
    for row in rows:
        print(row)
PY
```

If you only need conversion, use:

```python
from ml_data_ops.dataset.cva.website import (
    convert_escanor_episode_ids_to_source_episode_ids,
    convert_source_episode_ids_to_escanor_episode_ids,
)
```

## Notes

- `sourceEpisodeId` may be stored as either `ObjectId` or string in MongoDB. The website utility layer already handles that normalization.
- One source episode can map to multiple Escanor episodes across projects, so do not assume source ID lookups are one-to-one.
- Prefer the website utility module for reusable lookups. Drop to direct collection queries only for very custom one-off requests.
