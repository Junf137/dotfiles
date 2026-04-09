# Platform Standards

## Codex

- Official doc: https://developers.openai.com/codex/skills
- A skill is a directory with a required `SKILL.md` plus optional `scripts/`, `references/`, `assets/`, and `agents/openai.yaml`.
- Codex `SKILL.md` frontmatter should contain only `name` and `description`.
- Repository skills are discovered from `.agents/skills`. This dotfiles repo exposes `codex/skills` there via bootstrap symlink.
- `agents/openai.yaml` is optional. Use it for UI metadata, default prompt text, and `policy.allow_implicit_invocation`.

## Claude Code

- Official doc: https://code.claude.com/docs/en/skills
- Project skills live under `.claude/skills`. This dotfiles repo exposes `claude/skills` there via bootstrap symlink.
- Claude `SKILL.md` also requires `name` and `description`, but it may additionally use fields such as `allowed-tools`, `argument-hint`, `user-invocable`, `disable-model-invocation`, `agent`, and `context`.
- Claude supports argument and path placeholders such as `$ARGUMENTS`, `$0`, and `${CLAUDE_SKILL_DIR}`.
- Keep `SKILL.md` under roughly 500 lines and move detailed material into supporting files.

## Cross-Agent Sync Rules

- Match the instructional body and bundled resources across both trees.
- Keep the trigger intent aligned by using the same `name` and a materially equivalent `description`.
- Translate metadata instead of copying it verbatim between platforms.
- For explicit-only skills, pair Claude `disable-model-invocation: true` with Codex `policy.allow_implicit_invocation: false`.
