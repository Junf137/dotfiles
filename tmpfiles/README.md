# Handoff cleanup (`~/hf`)

> **Linux only.** On macOS, `lib/link_manifest.sh` links `launchd/com.junf.prune-handoffs.plist`
> instead. It applies the same policy through a launchd agent, and its header has the one-time
> `launchctl bootstrap` step.

## What it is for

The `handoff` agent skill (`agent-skills/{claude,codex}/handoff/SKILL.md`) writes documents with:

```bash
mkdir -p ~/hf && f=$(mktemp ~/hf/handoff-XXXXXX) && mv "$f" "$f.md" && echo "$f.md"
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
  atime and buys another 10 days (`relatime` still updates an atime that is a day stale).
- The timer runs daily, so effective lifetime is 10–11 days, not exactly 10.
- Subdirectories are cleaned recursively and removed once empty. `~/hf` itself is never removed.
- Moving or renaming a file updates its ctime and resets the clock.

At boot, `systemd-tmpfiles --user --create --remove --boot` runs, but `--remove` only acts on
`r`, `R` and `D` lines. This rule is type `d`, so boot only *creates* the directory — nothing is
deleted at boot. Only the daily `--clean` deletes.

## Operating it

```bash
systemctl --user enable --now systemd-tmpfiles-clean.timer   # once per machine; bootstrap.sh only links the rule

# status and next run
systemctl --user list-timers systemd-tmpfiles-clean.timer

# preview what would be deleted, then run the purge now
systemd-tmpfiles --user --clean --dry-run
systemctl --user start systemd-tmpfiles-clean.service

# confirm the rule is actually loaded
systemd-tmpfiles --user --cat-config | grep hf

# off until next login / off for good
systemctl --user stop systemd-tmpfiles-clean.timer
systemctl --user disable --now systemd-tmpfiles-clean.timer
```

The timer serves every user tmpfiles rule. To stop pruning only `~/hf`, change the age `10d` to
`-` in `handoffs.conf`; the directory is still created.

## Removing it completely

1. Unload it from the live config. On Linux:

   ```bash
   systemctl --user disable --now systemd-tmpfiles-clean.timer
   rm ~/.config/user-tmpfiles.d/handoffs.conf
   rmdir ~/.config/user-tmpfiles.d
   ```

   On macOS (`bootout` is harmless if the agent is not loaded):

   ```bash
   launchctl bootout gui/$(id -u)/com.junf.prune-handoffs
   rm ~/Library/LaunchAgents/com.junf.prune-handoffs.plist
   ```

2. In this repo, delete `tmpfiles/`, `launchd/` and the handoff block in `lib/link_manifest.sh`,
   and drop the handoff-pruning lines from `AGENTS.md` and `README.md`.
3. `~/hf` itself is left alone. The handoff skill in `agent-skills` still writes there and says
   files are pruned automatically, so change it there too.
