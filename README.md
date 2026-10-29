# dotfiles

Junfeng Lei's dotfiles for Arch Linux and macOS. `bootstrap.sh` symlinks them into
place from one manifest, `lib/link_manifest.sh`, and backs up whatever it replaces.
Coding agents: see [AGENTS.md](AGENTS.md).

## What is managed

- Shells: `zshrc` (Oh My Zsh, theme in `omz_themes/`) and `bashrc`, which share
  `shell_common.sh` for PATH, fzf and aliases; helper scripts in `utils/`
- Editors: `vimrc`, and Neovim from the `nvim/nvim-kickstart` submodule (a
  kickstart.nvim fork) with `nvim/markdownlint.jsonc`
- Terminals: WezTerm from the `wezterm/wezterm-config` submodule, and Alacritty
- tmux (`tmux.conf`, `tmux/`) with tmuxp layouts (`tmuxp/`), Yazi (`yazi/`), git, conda
- Claude Code and Codex: global instructions and settings (`claude/`, `codex/`), and
  skills from the private `agent-skills` submodule
- [`agent-sessions/`](agent-sessions/README.md): maps running Claude/Codex sessions to
  their tmux pane and carries them across a reboot, so a restored pane shows what ran
  there and how to resume it
- [`~/hf` handoff pruning](tmpfiles/README.md): systemd-tmpfiles on Linux, a launchd
  agent on macOS
- macOS: Homebrew packages (`Brewfile`) and system preferences (`macos-defaults.sh`)

## Install

Clone to `~/Documents/dotfiles`: the hooks in `tmux.conf`, `claude/settings.json` and
`codex/hooks.json` hard-code that path.

On a new machine, install these before the first bootstrap. Bootstrap creates
`~/.local/share/oh-my-zsh` for the theme link, and the Oh My Zsh installer refuses to
run once that directory exists.

- Oh My Zsh: run its installer with `ZSH=~/.local/share/oh-my-zsh`, then clone the
  custom plugins `zshrc` lists (`zsh-bat`, `you-should-use`, `zsh-autosuggestions`,
  `zsh-syntax-highlighting`) into its `custom/plugins/`.
- TPM: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`.

```bash
git clone --recurse-submodules git@github.com:Junf137/dotfiles.git ~/Documents/dotfiles
cd ~/Documents/dotfiles        # existing clone: git submodule update --init --recursive
brew bundle --file=Brewfile    # macOS only; provides ya, which bootstrap uses

./scripts/check-dotfiles.sh    # read-only repo checks
./bootstrap.sh --check         # validate sources, audit destinations
./bootstrap.sh --dry-run       # preview every action
./bootstrap.sh                 # link (backing up what it replaces), ya pkg install, backup report
./cleanup_backups.sh -f        # delete the redundant backups that report lists
./bootstrap.sh --restore       # undo: remove the managed links, restore the newest backups
```

`DOTFILES_SKIP_CLEANUP=1` skips the backup report and `DOTFILES_SKIP_YAZI=1` skips
`ya pkg install`. Create, dry-run and restore runs are logged to `logs/` (gitignored).

Then, once per machine:

- In tmux, press `prefix + I` (the prefix is `Alt+a`) to install the plugins.
- Linux: `systemctl --user enable --now systemd-tmpfiles-clean.timer`.
- macOS: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.junf.prune-handoffs.plist`,
  and optionally `./macos-defaults.sh`.
- Codex: approve its hooks when it asks ("Hooks need review"). Every edit to
  `codex/hooks.json` needs that approval again, on each machine.

## Codex shared defaults and local settings

`codex/config.toml` holds only portable defaults. Bootstrap links it to
`/etc/codex/config.toml` on both systems, using `sudo` for that one link, so run
bootstrap itself as your normal user; `--restore` removes the link again.

`~/.codex/config.toml` stays a regular, private file outside the repository. Codex
applies it on top of the system defaults, and it holds machine paths, project trust,
hook approvals, and plugin and app state. Never link it into the repository, and never
put local paths or generated state in `codex/config.toml`. A setting changed in the
Codex app can land in the user file and override the shared default until you delete
it there.

## Branch and commit conventions

- `main` contains shared changes suitable for all machines and follows
  `origin/main`. Push only this shared history to GitHub's `main`.
- Each machine keeps its own `local` branch directly on top of `main`. Its commits
  may be machine-specific or intentionally withheld from the shared repository. Do
  not push `local`, merge it wholesale into `main`, or merge `main` into it.
- Shared commits use `type(scope): summary`, with a lowercase, imperative summary
  and a type such as `feat`, `fix`, `docs`, `refactor`, `test`, or `chore`.
  Use `local(scope): summary` only for commits that stay on a machine's `local`
  branch. For example, a shared Codex config fix is `fix(codex)`; a machine's
  Conda initialization is `local(shell)`.

Prepare shared changes in a separate worktree based on the latest `origin/main`
so switching branches does not replace the live, symlinked dotfiles. To promote
an existing local commit, cherry-pick only that reviewed commit, correct its
message if necessary, test it, and push explicitly to `main`. Do not rewrite
already-published history to fix older message inconsistencies.

On each machine, fetch and fast-forward `main`, then rebase `local` onto it.
Check that the remaining commits are only the machine's local work; Git drops
patch-equivalent commits that have already been promoted, which is expected.
Preserve uncommitted work before rebasing and verify it afterward. Submodules have
independent histories and dirty files: a parent-repository stash does not protect
their work.
