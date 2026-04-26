---
name: cva-issue
description: Create a well-contextualized Linear issue for the CVA (Computer Vision Annotation Platform) project on Atlas Capture team. Actively prompts the user for any missing fields the dev needs.
---

# CVA Issue

Create a Linear issue for the **Computer Vision Annotation Platform** project on the **Atlas Capture** team, assigned to **saurab@mecka.ai**. Goal: give the dev (Saurab) enough context to act without follow-up. Every field below must have a real answer or an explicit `N/A` — but `N/A` is only valid after you actually asked.

## Fields

| Field | Options / format | How to fill |
|---|---|---|
| Type | Bug / Feature Request / Improvement | Infer if obvious, else ask |
| Description | what happened + what was expected | From the user's issue description, tightened |
| Steps to Reproduce | numbered list (bugs only) | **Ask if bug** |
| Video ID | string | **Ask if bug** (template requires it) |
| Screenshots | URL / Loom link | Ask — visual context is king for CV |
| Relevant URL | url | Ask |
| Affected Area | Body / Hands / UMI / Other | Ask |
| Affected Tooling | Bounding Boxes / Polygons / Keypoints / Segmentation / Video Timeline / Interpolation / Other | Infer if obvious, else ask |
| Who's Impacted | Just me / My team / All labelers | Ask |
| Urgency | Blocking work / Annoying but workaround exists / Nice to have | Ask |
| Priority (Linear) | 1 Urgent / 2 High / 3 Normal / 4 Low | **Always ask** (separate from Urgency) |

Label mapping: Bug → `Bug`, Feature Request → `Feature`, Improvement → `Improvement`.

## Before drafting

Parse the user's issue description for any fields already answered. Then ask the user for the rest, batched where possible:

- **Bundle A — classification**: Type, Affected Area, Affected Tooling
- **Bundle B — impact & priority**: Who's Impacted, Urgency, Priority
- **Bundle C — context artifacts** (free text, bugs-first): Video ID, Steps to Reproduce, Relevant URL, Screenshots

Use multi-choice options for categorical fields; free text for IDs, URLs, and steps. Skip anything already given.

## Description template (fill, real newlines, no `\n`)

```
### Type
<value>

### Description
<what happened + what was expected>

### Steps to Reproduce (for bugs)
1. ...
2. ...
Video ID: <id>

### Screenshots
<url or N/A>

### Relevant URL
<url or N/A>

### Affected Area
<value>
Video ID: <id or N/A>

### Affected Tooling
<value>

### Who's Impacted?
<value>

### Urgency
<value>
```

## Create

Show the drafted title + description and ask: "Create this issue as drafted?" Wait for confirmation before creating anything. On confirm, use the available Linear connector/tool to create the issue with:

- `team`: Atlas Capture
- `project`: Computer Vision Annotation Platform
- `assignee`: saurab@mecka.ai
- `labels`: `[<Bug|Feature|Improvement>]`
- `priority`: numeric
- `title`: specific and action-oriented (e.g. "Polygon tool crashes when zooming on Hands videos")
- `description`: filled template, real newlines

Reply with the issue URL. If no Linear connector/tool is available, stop after the draft and tell the user what still needs to be created manually.

## Don't ship

Bugs without Video ID + Steps. Descriptions that just echo the one-liner. All-`N/A` bodies (means you didn't ask). Generic titles. If you catch one, go back and ask more.
