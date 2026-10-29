# agent-sessions

Maps running Claude Code / Codex sessions to the tmux pane they occupy, and carries each
pane's session ids across a tmux-resurrect save and restore — so after a reboot the pane
tells you which sessions used to live there and how to resume them. `agent-resume` is
the one tool that acts on that record.

```
agent-sessions/
├── bin/
│   ├── agent-panes            # map every running session to session:window.pane
│   ├── agent-pane-register    # session-hook target: bind a pane to a session id
│   ├── agent-panes-resurrect  # tmux-resurrect save hook + sidecar + purge
│   ├── agent-resume           # resume this pane's session, if it has exactly one
│   ├── agent-scrollback-ids   # recover ids from exited agents' scrollback, by hand
│   └── claude-sessions        # running Claude sessions, in tmux or not, with CPU and memory
├── lib/
│   ├── agent_ids.py           # the resume-marker patterns, shared by two of the above
│   ├── agents.py              # agent processes, transcript files and their cwd
│   ├── claude_names.py        # session title -> uuid, from Claude's own transcripts
│   └── procinfo.py            # process facts: /proc on Linux, libproc+sysctl on macOS
├── tests/
│   └── test-agent-tools.py    # patterns, title and rollout index, marker render/strip/parse
├── check.sh                   # checks for this directory; also run by check-dotfiles.sh
└── README.md                  # this file
```

Nothing in `lib/` is a tool. `procinfo.py` is the platform layer: the only Python file
that knows whether this is Linux or macOS. (Two others carry platform knowledge of their
own: `claude-sessions` is bash and probes for itself, `/proc` when present and
`ps`/`lsof` otherwise, and `agent-panes-resurrect` knows about bsdtar's AppleDouble
members, which macOS's own `tar t` does not list.) The other three each read something
another program produced — `agent_ids.py` Claude's and Codex's terminal output,
`claude_names.py` the records Claude writes into its transcripts, `agents.py` what an
agent process looks like and where its transcripts live — and each rots silently when
that program changes. So there is exactly one copy of each, for `tests/` to cover:
`agent-scrollback-ids` sweeps live panes and `agent-panes-resurrect` the archived
captures with the same code, so a change to one changes both. `agents.py` exists because
that rule was not followed at first: its contents had been written out up to four times,
and the copies disagreed with each other and with Codex (see *Rollout files*).

**Title lookups are broad by hand and narrow in the hook.** `claude_names.name_index()`
serves two callers. `agent-scrollback-ids` is interactive and takes the broadest index:
`custom-title` and `agent-name`, plus the live registry, with recency breaking ties. The
save hook passes `unique=True` and gets `custom-title` only (the one field Claude's
banner can print), no registry, and nothing that names more than one session: it writes
a `--resume` into a pane replayed unattended, where a wrong id reads exactly like a
right one. Titles are free text — of 128 distinct titles here 5 are ambiguous, and `rm`
names 38 sessions.

**A refusal is permanent, and that is the point.** Ambiguity is evidence that expires:
Claude prunes `~/.claude/projects` at 30 days while scrollback and the archive do not,
so the same lookup a month later answers confidently and `rm` silently becomes whichever
of the 38 survived. Refused titles are written into the sidecar under `refused_titles`
and never looked up again, which is also what stops the sweep re-running on every save
for a title that will never resolve.

## Install and wiring

Nothing to install beyond the repo. Each piece activates independently and degrades to a
silent no-op rather than breaking its host. Run `./scripts/check-dotfiles.sh` after
touching any of it.

| File | Line | What |
|---|---|---|
| `shell_common.sh` | `add_path` | puts `bin/` on `PATH` (nothing here is symlinked by `bootstrap.sh`) |
| `claude/settings.json` | `SessionStart` / `SessionEnd` | runs `agent-pane-register claude` |
| `codex/hooks.json` | `SessionStart` / `SessionEnd` | runs `agent-pane-register codex`; needs one-time trust |
| `tmux.conf` | `@resurrect-hook-post-save-all` | runs `agent-panes-resurrect save` |

- The last three name `$HOME/Documents/dotfiles/...`. tmux, Claude and Codex all expand
  `$HOME` (measured for Codex; see *Codex hook gotchas*), but none can derive the repo's
  location, so a clone elsewhere needs them updated. `check_tmux_hook_wiring`
  hard-fails when the tmux hook target does not exist and only warns when it points at
  another checkout, so the check stays usable from a worktree.
- After editing the tmux hook, `tmux source-file ~/.tmux.conf`: the running server keeps
  the old value otherwise, and nothing warns.
- **Editing `codex/hooks.json` revokes Codex's hook trust.** `[hooks.state]` in
  `codex/config.toml` stores a content hash of each handler that covers its `command`,
  so any change flips it back to untrusted until re-approved in the TUI. Nothing warns;
  sessions just fall back to the inferred `meta~Ns` tier.

**Uninstall:** `agent-panes-resurrect purge` strips every block out of the archive and
removes the sidecar, log and lock. Removing the tmux hook alone does **not** — blocks
already inside `pane_contents.tar.gz` keep replaying on every restore.

### Requirements

- **Linux or macOS.** Every process fact goes through `lib/procinfo.py`: `/proc` on
  Linux, libproc + `sysctl` on macOS. macOS is not a degraded mode — all seven resolver
  tiers work — but two facts there are not obvious:
  - `KERN_PROCARGS2` returns a process's exec path, `argv` **and** `environ` in one
    read, which is what makes `TMUX_PANE` (the anchor everything rests on) readable at
    all. It works for the user's own processes with no privileges; another user's is
    unreadable, exactly as `/proc` hides it.
  - Claude's live registry writes `procStart` in each kernel's own terms: clock ticks
    since boot on Linux, and on macOS the start time formatted `%a %b %e %H:%M:%S %Y`
    **in UTC**. `procinfo.claude_proc_start_matches` compares parsed instants rather
    than text, because the guard failing closed would silently cost the exact
    `sessions` tier.

  `comm` is truncated to 15 characters, and an installed Claude on macOS — like a Linux
  background session — reads as its version (`2.1.223`), because it is exec'd straight
  out of `~/.local/share/claude/versions/`. So the executable path, not `comm`, is what
  identifies an agent.
- **Python ≥ 3.9.** `extractall(filter=)` falls back when the kwarg is unsupported (it
  arrived in 3.12, backported to 3.11.4 / 3.10.12 / 3.9.17), so an older interpreter
  loses nothing there. Reading a compressed Codex rollout needs `compression.zstd`,
  which is 3.14+. Without it — macOS's stock `python3` is 3.9 — such a session is still
  indexed and resumable but its directory is unknown, so `agent-resume` resumes it from
  the pane's own directory, as it does for any row whose directory is unknown or gone.
- **tmux-resurrect**, installed by TPM. Verified against `cff343cf`.

## Session mapping

- **Anchor**: `TMUX_PANE` in the agent's environment holds tmux's stable `%N` pane id.
  `#{pane_pid}` is the pane's *shell*, not the agent, which is a descendant of it — so
  `claude-sessions` matches by tty instead.
- **Claude ids** come from Claude's own live registry, `~/.claude/sessions/<pid>.json`,
  whose `procStart` records the process's kernel start time and so survives PID reuse
  (its format is per platform; see *Requirements*). Exact, needs no hooks, and works for
  resumed and `/clear`ed sessions.
- **Codex ids** come from `codex resume <uuid>` in argv when present, otherwise from a
  rollout's `session_meta` header matched on `cwd` plus start time. Codex has no live
  per-PID registry and its hooks cannot supply one (see *Codex hook gotchas*). The
  `session_meta` match keys on the process's **start**, so a process that goes on to
  hold a second session (a `/new`) keeps being reported as its first. That mislabels
  which session was live at a save but loses neither: the second one's exit banner and
  this tool's block both record it.
- **Rollout files** are `~/.codex/sessions/YYYY/MM/DD/rollout-<stamp>-<uuid>.jsonl`, and
  every reader goes through `lib/agents.py` for four variations:
  - From 0.158 a second uuid may follow the first (`…-<thread>_<other>.jsonl`). The
    thread is the *first* — the file's own `session_meta` id, and the only one
    `state_5.sqlite` has a row for.
  - One thread can span several rollouts (92 here have 2 to 7); the newest counts. That
    is the greatest file *name*, which sorts by start stamp — not the greatest path.
  - A rollout idle for about a week is compressed to `.jsonl.zst` — for 1698 of 1805
    threads here, on codex-cli 0.165, the newest rollout is one — while Codex's thread
    table goes on naming the `.jsonl`. It is still resumable, so it still counts; before
    this was handled, `agent-resume` called ~95% of Codex sessions gone. Resuming one
    was checked end to end on 0.165; Codex replaces the newest `.zst` with a `.jsonl`.
  - Archiving a thread moves its rollouts into the flat `~/.codex/archived_sessions/`
    (757 of 1805 threads here). `codex resume <id>` still opens one, after asking
    whether to unarchive it, so it counts too; before, `agent-resume` called every one
    gone. That flat directory sorts before every dated one, and a thread can leave an
    empty rollout behind in `sessions/`, which is why the newest is picked by name.

  The `session_meta` header is line 1 and carries the whole system prompt, ~52 KB,
  which is why the per-line read cap is 256 KiB.
- **Looked at and not used.** Claude's live registry now also records `tmux`
  (`<session>:@<window>.%<pane>`) and `name`, but only while the process is alive, and a
  killed agent is the case that matters. Codex's `state_5.sqlite` `threads` table and
  its `thread-writer-locks/` belong to the `app-server` daemon, which runs outside tmux,
  so neither names a pane. Checked against Claude Code 2.1.312 and codex-cli 0.165.
- **Do not rely on open file descriptors**: both agents open → append → close their
  transcript per turn. Only the Codex app-server keeps rollout files open (the `fd`
  tier).
- **The hook cache.** Hooks call `agent-pane-register`, which writes
  `~/.cache/agent-panes/<pane>.json` with the agent PID and its kernel start time, so a
  session that died without firing its end hook is detected as stale instead of being
  attributed to the next agent in that pane. **Hooks only affect newly started
  sessions.** The cache is live-only — `end` deletes the record and prunes any whose
  process is gone — so it is not, and cannot be, a source of history. That is what the
  sidecar is for.
- **Claude `SessionEnd` needs an explicit `timeout`**: without one it gets only a
  ~1.5 s shutdown budget and may be killed mid-write.

### Codex hook gotchas

Verified against codex-cli 0.146 via `hooks/list`, which reports *discovery*, never
execution.

- The config file is `~/.codex/hooks.json`; one at `~/.codex/hooks/hooks.json` is
  silently ignored, even if malformed. Event keys are PascalCase. The timeout key is
  `timeout`, in seconds, and unknown keys inside a handler are dropped without warning,
  so a typo just yields the default.
  `SessionEnd` is clamped to 3 s (1 s if omitted). A failing Codex hook is invisible.
- **`$HOME` in a hook command does expand.** Measured on 0.146.1 with two handlers on
  one `SessionStart`, one naming `$HOME/...` and one a literal absolute path: under
  `codex exec` both ran and both saw `TMUX_PANE`. So `codex/hooks.json` uses `$HOME`,
  like `claude/settings.json`.
- **Hooks need trust on first run.** They are discovered as `untrusted` and do not run
  until approved in the TUI ("Hooks need review" → "Trust all and continue"), which
  writes `[hooks.state]` into `~/.codex/config.toml` — a symlink into this repo, where
  Codex already writes its `[projects]` trust levels.
- **Trust is not sufficient: the interactive TUI cannot bind a pane.** Measured on
  0.146.0: an interactive session hands its hooks to the shared `app-server` daemon,
  which is started once at login *outside* tmux, so the hook inherits neither
  `TMUX_PANE` nor `TMUX` and `agent-pane-register` returns at its first check, writing
  nothing. `codex exec` runs its session in-process, so the hook works there — the only
  reason that code path is not dead. The payload (`session_id`, `transcript_path`,
  `cwd`, `hook_event_name`, `model`, `permission_mode`, `source`) and the environment
  (`CODEX_HOME`, `CODEX_REMOTE_PAYLOAD`, the `SSH_*` pair) name no terminal, tty or
  originating process, and one daemon serves every session. `SessionStart` also fires
  on the **first prompt**, not at launch. Claude is unaffected: it runs its hooks
  in-process, inside the pane.
- **What that costs is precision, not ids.** 0 of 122 codex records here are
  `hook`-sourced (102 `scrollback`, 12 `meta~0s`, 8 `cmdline`), and every id was still
  carried across two restarts; a live codex session is just only as good as the
  start-time match.

## Resurrect carry-over

`agent-panes-resurrect save` runs on `@resurrect-hook-post-save-all`, the first point at
which tmux-resurrect's archive exists. It appends a short block (three lines, or one
when the id is unresolved) to the *archived* copy of each annotatable pane, so the
restored pane prints the session id and a resume command right after replaying its
contents. Nothing is restarted and there is no restore-side code: the plugin recreates
every pane as `cat '<content file>'; exec $SHELL`, so the block is simply part of what
is replayed. (`@resurrect-hook-post-restore-all` runs `utils/tmux-refit-windows`, which
shares only the hook namespace and the silence requirement with this.)

Every tmux-resurrect internal this leans on is undocumented, and TPM updates the plugin
via `prefix + U` with no review, which is why `check_resurrect_plugin_contract` asserts
all six of them.

### Where the ids come from

Three sources feed one record per session, folded by `(pane id, agent, session id)`:

| Source | Covers | Tier |
|---|---|---|
| `agent-panes`, the live process scan | whatever is running at the moment of the save | `hook`, `sessions`, `env`, `cmdline`, `fd`, or an inferred `meta~Ns` / `btime~Ns` |
| the agent's own exit banner in the archived capture | every session either agent exited *gracefully* out of and the pane's scrollback still holds, including ones that started and ended between two saves | `scrollback` |
| this script's own block, parsed back out of the capture | everything a previous save wrote down — the only source for a session that was killed or lost to a reboot | whatever the block recorded |

The harvest reads `pane_contents.tar.gz`, not `tmux capture-pane`: the hook already
opens it, it holds each pane's *whole* history with wrapped lines rejoined
(`capture-pane -epJ -S -<history_size>`), and the hook runs inline with the save and
freezes the client that triggered it, so a subprocess per pane is the one thing it must
not do. On a 78-pane server: 14 ms to unpack in memory, 115 ms to scan 5.6 MB, 0.35 s
for the whole hook.

- **Claude's banner may name a title instead of a uuid.** Its conversation draws on the
  alternate screen and leaves nothing, but a graceful exit writes `Resume this session
  with: claude --resume <arg>` to the main screen, where scrollback keeps it. `<arg>` is
  the bare uuid, or the custom title double-quoted when the session has one (36.8% of
  408 transcripts here; read out of the `2.1.220` bundle and reproduced). A title is
  resolved through `lib/claude_names.py`, and only ever to an unambiguous uuid. The
  sweep costs ~0.15 s warm over ~1 GB of transcripts, so it runs at most once per save
  and only when a pane holds a title neither recorded nor refused. Both halves of that
  gate are load-bearing: the strip never removes Claude's banner, so the title would
  otherwise be looked up every 15 minutes for as long as it stays in the history.
- **A session that did not exit gracefully leaves no banner** — killed, or lost to a
  reboot. Reading our own block back is what covers those, and it is not an
  optimisation: a pane is stripped whenever it is annotated, so the block is their only
  carrier.
- **A text match is evidence about text.** A `codex resume <uuid>` in a document, a
  ripgrep hit or a `cat`ed handoff is indistinguishable from a real banner, so those
  rows are recorded as `scrollback` and printed as `(recovered)`.

### What gets annotated

- **Live and exited sessions alike**, an exited one dated by when it was last seen
  rather than by the save. An exited pane is the one that most needs the block: Claude
  leaves nothing in scrollback to replay.
- **The block is printed even when the agent printed its own banner**, so such a pane
  says it twice, on purpose. Suppressing it would mean parsing another tool's output to
  decide whether our own record is worth printing, and the block carries more: the `cd`
  into the project directory that `claude --resume` requires, the save time and the
  pane binding.
- **Every session the pane has held**, newest first, live outranking exited, up to
  `MAX_STANZAS` (6, `AGENT_SESSIONS_MAX_STANZAS`). The rest get a counted overflow line
  and stay in the sidecar, where they age out `KEEP_DAYS` after they stop being printed,
  since being printed is what keeps their evidence alive. Raise the cap rather than lose
  them if a pane routinely holds more.
- **Placement is by `%N` plus the server that issued it, never by location.**
  `renumber-windows on` reassigns `session:window.pane` the moment a window closes. `%N`
  alone is not enough either: it is a per-server counter that restarts at 0, while the
  sidecar outlives the server by `KEEP_DAYS`. Without the server stamp the first save
  after a reboot would place old records onto whichever restored panes inherited those
  numbers — permanently, since a pane is only stripped when it is also annotated. A
  record from another server generation, or with no stamp, is dropped; its block is
  already in that pane's scrollback from the previous restore, and the capture carries
  it forward.
- **The archive itself is still filed by location.** Blocks are written to
  `pane-<location>`, names the plugin fixed from its own earlier pane list, so a window
  closing between the capture and this hook can still misfile one. Closing that needs a
  hook before the capture, and `post-save-layout`, the only candidate, fires before the
  archive exists.
- **Coverage gap**, stated exactly: a session is lost only when it left no banner
  (killed, or lost to a reboot) *and* was never running at any save. Continuum saves
  every 15 min while a client is attached, so in practice that is a short session while
  nothing was attached. Everything else is covered by the sidecar, a banner, or the
  title lookup — unless the title names more than one session. `agent-scrollback-ids`
  is the by-hand tool for what is left; its index is the broad one, so it can offer a
  best guess where the hook refuses to.

### The block is read as well as written

The harvest parses the block back. That is what carries ids across a tmux server
restart — a new server reissues `%N` to unrelated panes, but the restored pane replays
its capture, block included, so the evidence travels with the pane's contents. It is
also what makes the strip safe: without it the strip would delete the only record of
every Claude session that ever ran in the pane.

- **Harvest before strip, and write the sidecar before touching the archive.** A crash
  in between costs a block the next save rewrites, never an id.
- **The parse is layered.** Only the `resume:` line is required; the head and tail lines
  add the name, source and dates. Anything the structured pass cannot read falls through
  to the ordinary resume-marker patterns, which also recovers blocks written by the
  pre-`#` renderer. A wording change in the renderer can cost a name, never a session
  id. `render → parse → render` convergence is tested for exact, inferred and recovered
  tiers alike.
- **A stanza names the pane and server it belongs to** (`bound to %13@545bbc4f`, the
  server id hashed to eight hex digits, since only equality is ever asked of it). One
  claiming *this* server but another pane is text that arrived here — a preview, a
  pasted stanza, a `cat` of another pane's capture — and is dropped whole, fallback
  included. One with no binding, or from another server generation, cannot be checked
  and is taken on trust: those are exactly the two carry-over cases. Intruding lines are
  stripped either way, so contamination cleans itself up.
- **A sentinel line away from column 0 is evidence about nothing** — an indented paste,
  a `cat` of another pane's capture, a quoted example — so it goes into neither pass.
  Falling through to the pattern scan would be worse than reading it as ours: its resume
  line still matches and would be filed against the pane at face value, and the strip
  never removes it off column 0, so it would re-seed itself on every save.
- **`save --dry-run` prints its preview at column 0, exactly as the hook would write
  it.** That is the safe form: in a pane's scrollback every stanza but the pane's own is
  refused by its binding, and the strip removes the preview on the way past. Indenting
  it would invert both.
- **The harvest is refused outright** when the pane list moved, when
  `@resurrect-capture-pane-contents` is off (the archive is then a stale one), when the
  archive is older than the state file this save wrote, when the shared imports failed,
  or when anything in it raises. Captures are named by location, so with
  `renumber-windows on` a window closing between the plugin's capture and this hook
  shifts every location after it; a location in the plugin's state file (`last`) that
  is no longer live means something moved. As a write a misfiled block lasts until the
  next save; as a *record* it would be permanent.
- **No harvest, no strip.** The strip is a delete, and for a Claude session the block
  may be the only place its id was ever written. So a save whose harvest was refused
  still writes its sidecar but leaves the archive exactly as it found it, as does one
  whose sidecar write failed — `cmd_save` enforces both — and
  `inject()` is handed the archive's identity from the harvest pass and refuses if it no
  longer holds.
- **Both harvest passes are capped per pane, and a cap ranks — it never slices.**
  Genuine text at `MAX_HARVEST_PER_PANE`, so one `cat` of a session dump cannot flood
  the file; blocks at `MAX_STANZAS`, since a block this hook wrote never holds more
  stanzas than it prints. Uncapped, a `cat` of the archive into a pane after a restore
  would file every pane's stanzas there (the binding check waves them through: a
  previous server generation is precisely what it cannot judge) and evict the pane's
  real records, turning a display cap into a delete. What a cap drops is stripped in
  the same save, so its order chooses which ids to delete: stanzas the pane can prove
  are its own first — one bound to this server but another pane was already refused, so
  a current-tag binding can only be ours — then the most recently seen. Taking the tail
  instead kept the *oldest*, because the renderer writes newest-first and the undated
  fallback rows come after every structured one. For the same reason a resolved title
  is located in the capture by the title it was read from, not by a uuid that never
  appears there.
- **The shared imports are guarded.** They are the first fallible statements in the
  hook and run before there is anywhere to log, and tmux-resurrect discards both exit
  status and stderr, so an `ImportError` would kill the hook without a word. Losing the
  harvest is survivable; losing the hook silently is not, which is why `check.sh` fails
  when the fallback is what is actually in use.

### Constraints that must not be re-derived

- **Save order matters.** `post-save-layout` fires before the archive exists and
  `save/pane_contents/` is emptied before `post-save-all`, so the hook has to go through
  `pane_contents.tar.gz` itself. It gets no arguments and is not told the resurrect
  dir, so it re-derives it the way `helpers.sh` does — including the global `~`
  replacement, not a leading-only one.
- **The hook must be silent.** A manual `prefix + C-s` runs `save.sh` through
  `run-shell`, whose stdout is the job pipe: one printed line drops the active pane into
  view-mode and renames the window `[tmux]`. stderr is `/dev/null` on every trigger
  path, so `save` sends both to `<resurrect dir>/agent_sessions.log` whenever stdout is
  not a tty. That log is the only observability there is — tmux-resurrect discards the
  hook's exit status entirely, so **every** failure path must reach the log or it does
  not exist.
- **Never run `save` or `purge` without `$TMUX`.** Every `tmux` call would resolve
  against the *default* server, so `@resurrect-dir` falls back to the real one and a
  stray manual run rewrites a live session's archive. The script refuses; keep it that
  way.
- **Stripping is load-bearing, not tidiness.** A restored pane replays the block into
  its own scrollback, so the next capture contains it; without a strip pass one block
  accumulates per reboot. Matching runs on the ANSI-stripped line, because tmux re-emits
  its own idea of the cell attributes rather than the bytes written — `ESC[0m ESC[2m`
  comes back as `ESC[0;2m`. The pre-`#` sentinel is still recognised, so blocks written
  by older versions are removed rather than stacked.
- **One predicate decides what is ours.** `marker_line()` answers for both the strip and
  the harvest, and they must never drift: a line the strip removes but the harvest never
  read is a session id deleted without being written down, and a line the harvest reads
  but the strip leaves stacks a copy on every reboot.
- **The sentinel starts with `#`, at column 0.** Column 0 is what stops prose, ripgrep
  hits and indented code samples being stripped. The `#` makes every line of the block a
  shell comment: it lands in a pane about to hand control to an interactive shell, and
  pasting a line beginning with a bare `[agent-session]` made bash glob it.
- **Every injected line opens and closes with `ESC[0m`.** A live Claude pane's capture
  ends on an unclosed colour, and `cat` replays that state onto the block and the prompt
  after it.
- **Fields are sanitised** for C0, C1, DEL and the Unicode line separators. Session
  titles are free text an agent wrote, replayed into a terminal; an unfiltered `ESC[6n`
  makes the restored shell receive the reply as typed input.
- **A block outlives the agent that produced it, on purpose.** Once restored it is
  ordinary scrollback, so the id survives repeated reboots without the agent ever being
  restarted. It carries the time it was written, which marks it as history rather than
  a live claim.
- **The in-archive block is best effort; `agent_sessions.json` is the durable record.**
  tmux-resurrect writes `pane_contents.tar.gz` in place with no temp+rename and no lock,
  and a manual save bypasses continuum's lock entirely, so a concurrent save can still
  clobber an injected archive. The hook's own rewrite is atomic, refuses to republish an
  archive it found truncated, and aborts if the archive changed under it.
- **Panes whose session name contains `/`, `:` or `'` are skipped.** tmux-resurrect
  already mishandles all three (a failed write, no content file, and a `cat '<file>'`
  that kills the pane). They still land in the sidecar.
- **Do not set `@resurrect-processes` to `':all:'`.** Restore currently does not respawn
  agent panes — `restore_pane_process` uses `send-keys`, and neither `node` nor `codex`
  is in the default list — which is why the block survives above whatever restore types.

## Resuming: `agent-resume`

Run in any pane: if exactly one agent session maps to it, it clears the screen and
resumes that session in the directory it was opened in —
`claude --dangerously-skip-permissions --resume <uuid>` or `codex resume <uuid> --yolo`.
It reads three sources and writes to none of them.

| Source | Covers what the others cannot |
|---|---|
| the sidecar, filtered to this server's own `%N` | every session a save saw running here |
| this pane's scrollback: our block, then the agents' own banners | the window between a restore and the first save after it, and a session that started and exited between two saves |
| the hook cache, `~/.cache/agent-panes/<pane>.json` | a **killed** agent, between the kill and the next save — the only place that id exists |

- **It starts a session only where the pane maps to one, and no flag names one.**
  Anything selecting a candidate would be a way to start a session the tool could not
  map by itself — a wrong id resumes somebody else's conversation and reads exactly like
  a right one. `--list` prints the command for each candidate instead, so choosing is a
  person's act. Exit status: `0` resumed, `1` nothing resumable here, `2` ambiguous,
  `3` refused to run at all.
- **A candidate whose transcript is gone is listed but never chosen**, and never makes a
  pane ambiguous. Both agents resolve `--resume` out of those files and Claude prunes its
  own at 30 days, so an id with nothing behind it is not a candidate at all. That is
  what makes "exactly one" answerable as often as it is: 53 of 66 panes here. An
  archived Codex thread is not gone — `codex resume` still opens it — so it is a
  candidate like any other, and can make a pane ambiguous.
- **The clear is `ESC[H ESC[2J` and deliberately not `ESC[3J`.** tmux answers the third
  by dropping the pane's history, which is a source this tool reads: for a session that
  started and exited between two saves, the banner there is the only record and nothing
  has folded it into the sidecar yet. `clear(1)` sends both on most terminfo entries.
- **It refuses to run from inside an agent's own shell tool**, detected by
  `agent-pane-register`'s ancestor walk. The pane mapping is right there and resuming is
  still wrong: it would start a second agent inside the first one's tool call, on a
  terminal that is not one. `--dry-run` prints the command instead; `--force` overrides.
- **The block parsing is borrowed, not copied.** `marker_line()`, `parse_stanzas()` and
  `split_capture()` come from `agent-panes-resurrect` by import, so the stanza binding
  rules apply identically. The per-pane caps are borrowed for the same reason: here they
  cost only a screenful, but the two tools disagreeing about what a pane holds would be
  worse than either bound. `check_borrowed_names` resolves every borrowed attribute,
  because a rename in the lender leaves `agent-resume` importing cleanly and raising
  `AttributeError` on the one path that starts a session.

## Commands

| Command | Purpose |
|---|---|
| `agent-panes [--json]` | map every running session in tmux to `session:window.pane` and its id |
| `agent-panes-resurrect save [--dry-run]` | the hook target; silent by design |
| `agent-panes-resurrect list [--json]` | read the sidecar |
| `agent-panes-resurrect purge [--dry-run]` | remove every block, sidecar, log |
| `agent-resume [-n] [-l] [--pane %N]` | resume this pane's session, if it has exactly one |
| `agent-scrollback-ids` | recover ids exited agents printed into scrollback |
| `claude-sessions [-n]` | running Claude sessions, in tmux or not, with uptime, CPU and memory |

`list`'s `LAST SEEN` is when the agent was last observed *running* there, and `-` where
the id was recovered from text, which carries no such time. It is never invented: a
recovered row is dated from the block it came from or its transcript's mtime, and
otherwise left blank rather than dated to the save that read it.

### The sidecar

`agent_sessions.json` (version 2) holds **every** session a pane has held, not just the
one running when a save fired; nothing is dropped for being superseded. Two timestamps,
and ageing keys on the second:

- `last_seen` — when the agent was observed running there.
- `recorded` — the last save that found *any* evidence of the record: a live process, a
  banner in the capture, or the block we wrote for it. Pruned `KEEP_DAYS` after this.

So a record lives as long as its evidence lives in the pane's scrollback — the pane's
`history-limit` is the real bound — plus 30 days of grace. Version 1 files have no
`recorded` and age from `last_seen`.

There is no way to delete a single record. `purge` is all or nothing, and exits non-zero
if it could not strip the archive, since a sidecar gone with the blocks left in place is
the worst of both. A `scrollback` row from a document that merely mentioned a resume
command keeps being re-found while that text is in the pane, hence `(recovered)`.

A sidecar that exists but is not a sidecar is moved to `agent_sessions.json.unreadable`
rather than written over: to the merge an empty read and a damaged file look identical,
and publishing a fresh record over it would take every id along. The test is "are these
bytes a sidecar", never "does it hold anything" — a well-formed file with empty `panes`
is what a machine with no agent panes writes, and treating that as damage renamed it
aside on every save. The scratch sweep leaves the kept file alone, since a promise to
keep it that expires after an hour is not one; `purge` removes it.

| Env | Effect |
|---|---|
| `AGENT_SESSIONS_KEEP_DAYS` | how long a record survives after the last save that found evidence of it (30) |
| `AGENT_SESSIONS_MAX_STANZAS` | most sessions printed in one pane's block (6); the rest stay in the sidecar |
| `NO_COLOR` | render the block without SGR |
| `SCROLLBACK_DEPTH` | how far back `agent-scrollback-ids` and `agent-resume` search. The defaults differ on purpose: `-20000` for the sweep, which pays it once per pane across a whole server, and the whole history (`-`) for the one pane `agent-resume` reads |

## Tests

```bash
./agent-sessions/check.sh                     # every check for this directory
./agent-sessions/tests/test-agent-tools.py    # just the unit tests
```

`check.sh` derives its own repo root and is dispatched from `./scripts/check-dotfiles.sh`
as one entry, so a failure here fails the repo checks. Two things stay in the parent:
resolving the hook `command` strings in `claude/settings.json` and `codex/hooks.json`
(jq-gated), and linting `claude-sessions` with the generic bash/shfmt/shellcheck lists.
**Re-run after upgrading Claude or Codex.** The resume-marker patterns, the title index
and the rollout index read those tools' output and records and rot silently when either
changes; the run also covers the marker rendering, stripping, parsing and placement,
`agent-resume`'s rule and commands, and the shared imports — which are guarded, so a
broken one degrades to "no harvest" and this is the only place it would be noticed.

- **The name-binding pass.** The syntax check runs a flat, deliberately
  scope-insensitive pass over every Python file here. It never reports a shadowing, but
  it catches a name a file uses and never binds — a dropped `import`, which turns the
  save hook into a silent no-op. That happened once (`NameError: name 'hashlib' is not
  defined`); `ast.parse` was blind to it, and the tests exercised 13 of 18 top-level
  imports.
- **The exec is out of reach.** `agent-resume`'s two commands are spelled out in the
  tests as well as the tool, so changing one alone fails. To exercise the clear, the
  `chdir` and the argv for real, put a script named `claude` or `codex` ahead on `PATH`
  that echoes its argv and `$PWD`, and run `agent-resume` in a pane on a throwaway
  server (`tmux -L test`, with `@resurrect-dir` pointed somewhere scratch).
- **So is whether a hook had any effect.** `check_hook_wiring` resolves each `command`
  to a real executable, and Codex's Hooks TUI reports the handler installed and active;
  neither says it did anything, and believing otherwise is exactly what hid the
  app-server finding above. The cache file is the only observable: after an upgrade,
  start a session in a pane and check that `~/.cache/agent-panes/<pane number>.json`
  appears within a second. Claude passes; the interactive Codex TUI is expected to fail
  until upstream runs hooks in the session's own process or puts a terminal in the
  payload.
- **`agent-panes-resurrect save --dry-run`** shows what a save would do. It reads the
  archive, so the harvest and every recovered id show up in the preview, and it writes
  nothing. Running it inside a pane is safe by construction — see the stanza binding
  above.
