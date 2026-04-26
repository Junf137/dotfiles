---
name: llm-wiki-maintainer
description: Maintain an Obsidian LLM wiki backed by repo-local AGENTS.md. Use when asked to add, remove, archive, update, ingest, query, lint, run graph hygiene, audit source readiness, perform full-source review, or refresh indexes and logs in an LLM-centered markdown wiki.
---

# LLM Wiki Maintainer

Use this skill to operate a markdown/Obsidian vault as an LLM-maintained wiki. Treat the repo-local `AGENTS.md` as the source of truth for architecture, page types, source boundaries, git policy, and current vault conventions.

## Startup

1. Read `AGENTS.md`.
2. Read `index.md` as the curated content map.
3. Read recent `log.md` entries for context.
4. Use `rg` before answering, creating pages, or changing existing content.
5. Check `git status --short --untracked-files=all` before any git operation. Do not commit unless the user explicitly asks.

## Choose The Workflow

- **Add or ingest source:** create/update the source note, extract durable concepts, update relationships/projects/hubs, update indexes, append `log.md`.
- **Update existing content:** inspect inbound/outbound links with `rg`, preserve provenance, update nearby hubs, append `log.md` for meaningful changes.
- **Remove/archive content:** find inbound links first, decide delete vs merge vs `status: archived`, repair navigation, update indexes/log.
- **Query:** read relevant pages, answer with note links, and save durable answers only when useful or requested.
- **Lint/maintenance:** check unresolved links, orphan/low-inbound notes, missing hubs, stale source-readiness status, duplicate concepts, and missing frontmatter.
- **Full-source review:** read the full source, verify method/results/limitations, update durable synthesis, then mark `read complete` and `methodology complete` only when actually reviewed.

## Layer Rules

- `000 Primary Text📃/`: provenance-preserving source notes.
- `001 Ideas 💭/`: durable concepts and reusable synthesis.
- `002 Relationships🌐/`: cross-topic relationships where the relationship is the main object.
- `004 Software🧑‍💻/`: reusable technical/software knowledge.
- `005 Projects📋/`: project-specific working knowledge.
- `008 Obsidian/`: templates, attachments, and vault infrastructure.
- `index.md`: concise high-level map, not a full catalog.
- `log.md`: append-only activity record.

## Source Boundary

Allowed source-note edits:

- metadata/status fields
- backlinks
- local attachment references
- short provenance-preserving annotations and TODOs

Avoid source-note edits that turn the source into the main synthesis layer. Put durable cross-source synthesis in ideas, relationships, or project pages.

## Index And Log Discipline

- Update area indexes when adding/removing important pages in that area.
- Update `index.md` only when high-level navigation, queues, or major clusters change.
- Append `log.md` entries for ingests, durable synthesis, lint passes, refactors, source-readiness changes, and meaningful archive/delete operations.
- Use headings like `## [YYYY-MM-DD] action | Title`.

## Removal/Archive Checklist

1. Run `rg` for inbound wikilinks, embeds, aliases, and index references.
2. Preserve provenance when content has evidentiary value.
3. Prefer merge/archive over deletion unless the user explicitly wants deletion or the content is clearly out of scope.
4. Repair or redirect inbound links before removing files.
5. Update affected hubs and logs.

## Verification

Run checks proportional to the change:

- `git diff --check`
- unresolved non-asset wikilink scan
- graph-island/zero-inbound scan after navigation work
- source-readiness table check after primary-text work

State any checks that were not run.
