# Platform Standards

Checked against these official docs on 2026-04-26. Use the docs as the source of truth when this file gets stale:

- Open Agent Skills specification: https://agentskills.io/specification
- Codex skills: https://developers.openai.com/codex/skills
- Claude Code skills: https://code.claude.com/docs/en/skills

## Open Agent Skills Baseline

- A skill is a directory containing a required `SKILL.md` file.
- `SKILL.md` contains YAML frontmatter followed by Markdown instructions.
- Required standard fields are `name` and `description`.
- `name` should be lowercase letters, numbers, and hyphens only, 1-64 characters, and should match the parent directory.
- `description` should be non-empty, concise, and include both what the skill does and when to use it.
- Optional standard fields include `license`, `compatibility`, `metadata`, and experimental `allowed-tools`.
- Optional directories include `scripts/`, `references/`, and `assets/`.
- Use progressive disclosure: keep `SKILL.md` focused, reference supporting files with relative paths, and avoid deeply nested reference chains.

## Codex

- Official doc: https://developers.openai.com/codex/skills
- Codex builds on the Open Agent Skills standard.
- A Codex skill is a directory with required `SKILL.md` plus optional `scripts/`, `references/`, `assets/`, and `agents/openai.yaml`.
- Codex `SKILL.md` must include `name` and `description`; this repo keeps Codex frontmatter to those fields unless a portable Open Agent Skills standard field such as `license`, `compatibility`, or `metadata` is intentionally needed.
- Codex supports explicit invocation with `$skill-name` or `/skills`, and implicit invocation when the prompt matches `description`.
- Front-load the key trigger words in `description` because Codex may shorten descriptions in large skill lists.
- Codex reads skills from repository, user, admin, and system locations.
- Repository skills are discovered from `.agents/skills` in the current working directory and parent directories up to the repository root. This dotfiles repo exposes `codex/skills` there via bootstrap symlink.
- User skills live in `$HOME/.agents/skills`; admin skills can live in `/etc/codex/skills`; system skills are bundled by OpenAI.
- Codex supports symlinked skill folders and follows the symlink target.
- If duplicate skill names are found, Codex does not merge them; both can appear in selectors.
- `agents/openai.yaml` is optional. Use it for Codex app UI metadata, default prompt text, `policy.allow_implicit_invocation`, and tool dependencies.
- `policy.allow_implicit_invocation` defaults to `true`; set it to `false` for explicit-only skills. Explicit `$skill-name` invocation still works.
- Do not put Claude-only frontmatter or placeholders in Codex skills.

## Claude Code

- Official doc: https://code.claude.com/docs/en/skills
- Claude Code follows the Open Agent Skills standard and extends it with invocation control, subagent execution, and dynamic context injection.
- Claude Code skills can be invoked directly with `/skill-name` or loaded automatically when relevant.
- Project skills live under `.claude/skills/<skill-name>/SKILL.md`. This dotfiles repo exposes `claude/skills` there via bootstrap symlink.
- Personal skills live under `~/.claude/skills`; plugin skills live under `<plugin>/skills`; enterprise skills can be managed centrally.
- Claude Code also discovers nested `.claude/skills` directories when working in subdirectories, and skills from `.claude/skills` inside paths added with `--add-dir`.
- Claude Code detects edits to existing watched skill directories during the current session; creating a top-level skills directory may require restart.
- Claude Code treats frontmatter fields as optional, but this repo always sets `name` and `description` to stay aligned with Codex.
- `description` and `when_to_use` drive automatic discovery; their combined text may be truncated in listings, so front-load the important trigger terms.
- Claude-specific frontmatter can include `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`, `effort`, `context`, `agent`, `hooks`, `paths`, and `shell`.
- Use `disable-model-invocation: true` for explicit-only workflows with side effects; it removes the skill from Claude's automatic discovery context.
- Use `user-invocable: false` for background/reference skills that Claude may use automatically but users should not see as slash commands.
- `allowed-tools` pre-approves listed tools while the skill is active; it does not restrict other tools. Use Claude permission deny rules to restrict tools.
- Claude substitutions include `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N` shorthand such as `$0`, named `$argument` placeholders declared by `arguments`, `${CLAUDE_SESSION_ID}`, and `${CLAUDE_SKILL_DIR}`.
- Claude dynamic context injection uses inline `!` command blocks before the skill content is sent to Claude. Do not copy this syntax to Codex.
- `context: fork` runs the skill as a subagent task; `agent` selects the subagent type.
- Keep `SKILL.md` under roughly 500 lines and move detailed material into supporting files.

## Cross-Agent Sync Rules

- Match the instructional body and bundled resources across both trees unless platform-native invocation syntax requires a small difference.
- Keep the trigger intent aligned by using the same `name` and a materially equivalent `description`.
- Keep directory names and `name` fields aligned.
- Translate metadata instead of copying it verbatim between platforms.
- Keep Claude-only frontmatter, placeholders, shell injection, and slash-command assumptions out of Codex skills.
- Keep Codex-only `agents/openai.yaml` out of Claude skills.
- For explicit-only skills, pair Claude `disable-model-invocation: true` with Codex `policy.allow_implicit_invocation: false`.
- If a skill needs tool or MCP dependencies in Codex, declare them under `agents/openai.yaml` `dependencies.tools` rather than inventing SKILL.md frontmatter.
