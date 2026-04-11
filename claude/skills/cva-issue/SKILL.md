---
name: cva-issue
description: Create a Linear issue for the CVA (Computer Vision Annotation Platform) project on Atlas Capture team
argument-hint: [description of the issue]
disable-model-invocation: true
---

Create a Linear issue for the **Computer Vision Annotation Platform** project under the **Atlas Capture** team.

## Defaults
- **Project**: Computer Vision Annotation Platform
- **Team**: Atlas Capture
- **Assignee**: saurab@mecka.ai

## Before creating the issue

1. Read the user's description from: $ARGUMENTS
2. **Ask the user what priority** they want before creating:
   - 1 = Urgent
   - 2 = High
   - 3 = Normal
   - 4 = Low
3. Determine the appropriate label: `Bug`, `Feature`, `Improvement`

## Issue description format

Use this template for the issue description:

```
### Type
Bug / Feature Request / Improvement

### Description
What happened? What did you expect to happen instead?

### Steps to Reproduce (for bugs)
1. Go to ...
2. Click on ...
3. Observe ...
An ID of the video where the bug was discovered must be provided

### Screenshots
Crucial for CV. Attach screenshots of the UI or a quick Loom/recording of the behavior.

### Relevant URL
Paste the URL of the page or feature this relates to.

### Affected Area
Body / Hands / UMI / Other
An ID of the video where the bug was discovered should be provided

### Affected Tooling
Bounding Boxes / Polygons / Keypoints / Segmentation / Video Timeline / Interpolation / Other

### Who's Impacted?
Just me / My team / All labelers

### Urgency
Blocking work / Annoying but workaround exists / Nice to have
```

Fill in the template fields based on what the user provides. For fields with no info, use "N/A".

## Creating the issue

Use `mcp__claude_ai_Linear__save_issue` with:
- `team`: Atlas Capture
- `project`: Computer Vision Annotation Platform
- `assignee`: saurab@mecka.ai
- `labels`: the appropriate label
- `priority`: the priority the user selected
- `title`: a concise title derived from the user's description
- `description`: the filled-in template above

After creating, share the issue URL with the user.
