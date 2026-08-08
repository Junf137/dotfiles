# Handoff cleanup (`~/hf`)

Context for `handoffs.conf`, the only file in this directory.

> **Linux only.** systemd-tmpfiles does not exist on macOS, so everything below applies
> to the Linux box alone. `lib/link_manifest.sh` gates this file to `uname -s = Linux`
> and links `launchd/com.junf.prune-handoffs.plist` instead on a Mac — same policy
> (create `~/hf`, prune entries untouched for 10 days), run by a launchd user agent
> rather than a systemd timer. That plist documents its own one-time
> `launchctl bootstrap` step in a comment at the top.
>
> Note also that the `mktemp` line quoted below does not work on macOS: BSD `mktemp`
> only substitutes *trailing* `X`s, so `handoff-XXXXXX.md` is taken literally and the
> second `/handoff` fails with `File exists`. That command lives in the `agent-skills`
> submodule and has to be fixed there.

## What it is for

The `handoff` agent skill (`agent-skills/{claude,codex}/handoff/SKILL.md`) writes documents with:

```bash
mkdir -p ~/hf && mktemp -p ~/hf handoff-XXXXXX.md
```

`~/hf` is used instead of `/tmp` so handoffs survive reboots. This tmpfiles rule is what keeps
that directory from growing forever:

```
d %h/hf 0755 - - 10d -
```

Create `~/hf` if missing; prune entries older than 10 days. Linked to
`~/.config/user-tmpfiles.d/handoffs.conf` by `lib/link_manifest.sh`.

## How it triggers

```
login  →  systemd --user  →  timers.target
                                  ↓  (enable symlink in ~/.config/systemd/user/timers.target.wants/)
                    systemd-tmpfiles-clean.timer     OnStartupSec=5min, then every 1d
                                  ↓
                    systemd-tmpfiles-clean.service   ExecStart=systemd-tmpfiles --user --clean
                                  ↓
                    reads ~/.config/user-tmpfiles.d/*.conf  →  prunes ~/hf
```

- Runs in the **per-user** systemd instance (`systemd --user`). No root, no system units.
- Both `.timer` and `.service` ship with the systemd package in `/usr/lib/systemd/user/` and are
  never modified here. On Arch the timer is disabled by default; enabling it only creates a
  symlink under `~/.config/systemd/user/timers.target.wants/`.
- `handoffs.conf` is a drop-in: `--clean` globs `~/.config/user-tmpfiles.d/*.conf` on every run,
  so edits take effect at the next run with no `daemon-reload`.
- With `Linger=no` the user manager only runs while logged in (SSH counts). Missed runs catch up
  5 minutes after the next login.

## What "10 days old" means

Per `tmpfiles.d(5)`:

- Age is compared against **mtime, atime and ctime** (ctime not for directories). An entry is
  deleted only when *all* of them are older than the age — so reading a handoff refreshes its
  atime and buys another 10 days. `/home` is mounted `relatime`, which still updates atime once
  it is a day stale.
- The timer runs daily, so effective lifetime is 10–11 days, not exactly 10.
- Subdirectories are cleaned recursively and removed once empty. `~/hf` itself is never removed.
- Moving or renaming a file updates its ctime and resets the clock.

At boot, `systemd-tmpfiles --user --create --remove --boot` runs, but `--remove` only acts on
`r`, `R` and `D` lines. This rule is type `d`, so boot only *creates* the directory — nothing is
deleted at boot. Only the daily `--clean` deletes.

## Enabling on a new machine

`bootstrap.sh` links `handoffs.conf` into place but cannot enable the timer, because the enable
symlink lives in `~/.config/systemd/user/`, outside this repo. Once per machine:

```bash
systemctl --user enable --now systemd-tmpfiles-clean.timer
```

## Operating it

```bash
# status and next run
systemctl --user list-timers systemd-tmpfiles-clean.timer

# preview what would be deleted, then run the purge now
systemd-tmpfiles --user --clean --dry-run
systemctl --user start systemd-tmpfiles-clean.service

# confirm the rule is actually loaded
systemd-tmpfiles --user --cat-config | grep hf

# off until next login / off for good / back on
systemctl --user stop systemd-tmpfiles-clean.timer
systemctl --user disable --now systemd-tmpfiles-clean.timer
systemctl --user enable --now systemd-tmpfiles-clean.timer
```

To stop pruning `~/hf` while leaving the timer alone, change the age field `10d` to `-` in
`handoffs.conf`. `-` means no automatic cleanup, and the directory is still created.

Disabling the timer affects every user tmpfiles rule, not just this one. As of writing, the only
other user rules on this machine are the stock `20-systemd-varlink.conf` varlink entries, which
carry no age field and are therefore untouched by `--clean`.

## Removing it completely

```bash
# 1. unregister the timer
systemctl --user disable --now systemd-tmpfiles-clean.timer

# 2. drop the rule from live config
rm ~/.config/user-tmpfiles.d/handoffs.conf
rmdir ~/.config/user-tmpfiles.d

# 3. remove it from this repo
cd "${DOT_FILES:-$HOME/Documents/dotfiles}" && rm -r tmpfiles
```

Then delete the `_link_manifest_add ... "handoff cleanup rules"` line from `lib/link_manifest.sh`
and the two `tmpfiles/` rows in `CLAUDE.md`.

Nothing else is left behind: no system-level changes, no cron entries, no shell-config hooks, no
root-owned files. `~/hf` and its contents are untouched by removal — handoffs simply accumulate
again. To retire the directory as well, revert the skill's `mktemp -p ~/hf` to `mktemp -t` and
`rm -rf ~/hf`.
