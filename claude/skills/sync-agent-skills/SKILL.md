---
name: sync-agent-skills
description: Audit and sync the parallel Claude Code and Codex skill trees in `~/Documents/dotfiles`. Use when a skill exists on only one side, shared skill content has drifted, or metadata needs to be translated to match each platform's official skill docs.
argument-hint: [repo-path, defaults to ~/Documents/dotfiles]
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash
---

# Sync Agent Skills

Keep `~/Documents/dotfiles/claude/skills` and `~/Documents/dotfiles/codex/skills` aligned without flattening away the platform-specific parts that Claude Code and Codex each expect.

Read [references/platform-standards.md](references/platform-standards.md) before editing metadata or creating new skill folders.

## Workflow

1. Audit both skill trees.
   - Default repo root to `~/Documents/dotfiles` unless the user specifies another clone.
   - List skill directories on both sides.
   - Identify missing counterparts.
   - Diff shared skills and separate real content drift from expected metadata differences.

2. Choose the source of truth skill-by-skill.
   - Prefer the newer or richer version, not whichever file happens to be on the Claude or Codex side.
   - Merge useful additions from both sides instead of blindly overwriting one with the other.

3. Sync shared skill content.
   - Keep the Markdown body of `SKILL.md` effectively the same for both agents.
   - Keep `scripts/`, `references/`, and `assets/` aligned across both sides when they exist.
   - Normalize `name` and `description` so the trigger intent matches across both agents.

4. Translate platform-specific wrappers instead of copying them verbatim.
   - Codex `SKILL.md` frontmatter should contain only `name` and `description`.
   - Put Codex UI or invocation policy metadata in `agents/openai.yaml` when needed.
   - Claude may use extra frontmatter such as `allowed-tools`, `argument-hint`, `user-invocable`, `disable-model-invocation`, `agent`, and `context`.
   - Do not copy Claude-specific placeholders such as `$ARGUMENTS`, `$0`, or `${CLAUDE_SKILL_DIR}` into Codex skills. Rewrite those instructions in plain language.

5. Create missing counterparts.
   - If a skill exists only under `claude/skills` or only under `codex/skills`, add the sibling directory for the other agent.
   - Copy shared resources, then adapt metadata and any platform-specific syntax.

6. Keep explicit-invocation behavior aligned for side-effecting skills.
   - Claude: set `disable-model-invocation: true` when the skill should never auto-run.
   - Codex: set `policy.allow_implicit_invocation: false` in `agents/openai.yaml` for the same skill.

7. Verify the result.
   - Diff the two skill trees after edits.
   - Remaining differences should be intentional platform-specific metadata or Codex-only files such as `agents/openai.yaml`.
   - If a skill grows too large, move detailed standards or examples into `references/` instead of bloating `SKILL.md`.

## Repo Layout

This repo bootstraps the skill trees as:

- `claude/skills` -> `~/.claude/skills`
- `codex/skills` -> `~/.agents/skills`

Edit the repo copies first. The symlinks expose those updates to Claude Code and Codex.
