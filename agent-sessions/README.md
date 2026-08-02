# agent-sessions

Maps running Claude Code / Codex sessions to the tmux pane they occupy, and carries each
pane's session id across a tmux-resurrect save and restore — so after a reboot the pane
tells you which session used to live there and how to resume it.

```
agent-sessions/
├── bin/
│   ├── agent-panes            # map every running session to session:window.pane
│   ├── agent-pane-register    # session-hook target: bind a pane to a session id
│   ├── agent-panes-resurrect  # tmux-resurrect save hook + sidecar + purge
│   ├── agent-scrollback-ids   # recover ids from exited agents' scrollback, by hand
│   └── claude-sessions        # list running Claude Code sessions with details
├── lib/
│   ├── agent_ids.py           # the resume-marker patterns, shared by two of the above
│   └── claude_names.py        # session title -> uuid, from Claude's own transcripts
├── tests/
│   └── test-agent-tools.py    # resume-marker patterns + marker render/strip/parse
├── check.sh                   # checks for this directory; also run by check-dotfiles.sh
└── README.md                  # this file
```

Neither file in `lib/` is a tool. Both read something another program produced —
`agent_ids.py` the patterns matching Claude's and Codex's terminal output,
`claude_names.py` the records Claude writes into its own transcripts — and both
rot silently the next time either changes. So there is exactly one copy of each
for `tests/` to cover: `agent-scrollback-ids` sweeps live panes, and
`agent-panes-resurrect` sweeps the archived captures, with the same code.

The two callers ask `claude_names.name_index()` for different things.
`agent-scrollback-ids` is interactive, prints what it could not map, and takes the
broadest index there is: both `custom-title` and `agent-name`, plus the live
registry, with recency breaking a tie. The save hook passes `unique=True` and gets
a much narrower one — `custom-title` only, which is the sole field Claude's banner
can print, no registry, and nothing that names more than one session. It writes a
`--resume` into a pane replayed unattended after a reboot, where a wrong id reads
exactly like a right one, and titles are free text: of 128 distinct titles here 5
are ambiguous, and one of them (`rm`) names 38 different sessions.

**A refusal is permanent, and that is the point.** Ambiguity is evidence that
expires — Claude prunes `~/.claude/projects` at 30 days, while a pane's scrollback
and the replayed archive have no such bound — so the same lookup a month later
answers confidently where this one would not, and `rm` silently becomes whichever
of the 38 happened to survive. Refused titles are written into the sidecar under
`refused_titles` and never looked up again. That is also what stops the sweep
re-running on every save for a title that will never resolve: nothing else
remembers a lookup that came back empty.

`bin/` is on `PATH` via `shell_common.sh`. Nothing here is symlinked by `bootstrap.sh`;
the wiring is four files outside this directory, listed under *Wiring* below.

## Install

Nothing to install beyond the repo itself. The pieces activate independently, and every
one of them degrades to a silent no-op rather than breaking its host:

1. **PATH** — `add_path "$DOT_FILES/agent-sessions/bin"` in `shell_common.sh`.
2. **Agent hooks** — `claude/settings.json` and `codex/hooks.json` call
   `agent-pane-register`. Codex hooks need one-time trust; see *Codex hook gotchas*.
3. **tmux hook** — `@resurrect-hook-post-save-all` in `tmux.conf`. After editing it,
   `tmux source-file ~/.tmux.conf` — the running server keeps the old value otherwise,
   and nothing warns.

Run `./scripts/check-dotfiles.sh` after touching any of it.

### Requirements

- **Linux.** `agent-panes` reads `/proc/uptime` at import and exits non-zero on a
  kernel without `/proc`. On macOS the whole family is inert; it is not gated by a
  `Darwin` check because there is nothing to fall back to.
- **Python ≥ 3.9.** The only version-sensitive call, `extractall(filter=)`, falls back
  when the kwarg is unsupported (it arrived in 3.12, backported to 3.11.4 / 3.10.12 /
  3.9.17), so an older interpreter loses nothing.
- **tmux-resurrect**, installed by TPM. Verified against `cff343cf`.

### Uninstall

`agent-panes-resurrect purge` strips every block out of the archive and removes the
sidecar, log and lock. Removing the tmux hook alone does **not** do this — blocks
already inside `pane_contents.tar.gz` keep replaying on every restore.

## Wiring

| File | Line | What |
|---|---|---|
| `tmux.conf` | `@resurrect-hook-post-save-all` | runs `agent-panes-resurrect save` |
| `claude/settings.json` | `SessionStart` / `SessionEnd` | runs `agent-pane-register claude` |
| `codex/hooks.json` | `SessionStart` / `SessionEnd` | runs `agent-pane-register codex` |
| `shell_common.sh` | `add_path` | puts `bin/` on `PATH` |

The first three are absolute paths — tmux and Codex cannot derive one — so a clone
anywhere other than `~/Documents/dotfiles` needs them updated; only `shell_common.sh`
derives its path from `$DOT_FILES`. `check_tmux_hook_wiring` hard-fails when the tmux
hook target does not exist, and warns (rather than fails) when it points at a different
checkout, so the check stays usable from a worktree.

**Editing `codex/hooks.json` revokes Codex's hook trust.** `[hooks.state]` in
`codex/config.toml` stores a content hash of each handler that covers the `command`
string, so any change to it flips the handlers back to untrusted and they stop running
until re-approved in the TUI. Nothing warns; the session just falls back to the inferred
`meta~Ns` tier.

## Session mapping

- **Anchor**: `TMUX_PANE` in `/proc/<pid>/environ` holds tmux's stable `%N` pane ID.
  Note that `#{pane_pid}` is the pane's *shell*, not the agent — the agent is a
  descendant of it, which is why `claude-sessions` matches via tty instead.
- **Claude session IDs** come from Claude's own live registry,
  `~/.claude/sessions/<pid>.json`, whose `procStart` field equals `/proc/<pid>/stat`
  field 22 and so survives PID reuse. This is exact, needs no hooks, and works for
  resumed and `/clear`ed sessions.
- **Codex session IDs** come from `codex resume <uuid>` in `/proc/<pid>/cmdline` when
  present, otherwise from matching a rollout's `session_meta` header (`cwd` plus start
  time) under `~/.codex/sessions/`. Codex has no live per-PID registry, so hooks are
  what make it exact.
- **Hooks** call `agent-pane-register`, which writes `~/.cache/agent-panes/<pane>.json`.
  Records carry the agent PID and its kernel start time so a session that died without
  firing its end hook is detected as stale instead of being attributed to the next agent
  in that pane. **Hooks only affect newly started sessions.**
- **The hook cache is live-only.** `agent-pane-register end` deletes the record and
  prunes any whose process is gone. It is not, and cannot be, a source of history —
  that is what the resurrect sidecar is for.
- **Codex hook gotchas**, all verified against codex-cli 0.146 via `hooks/list`:
  the config file is `~/.codex/hooks.json` — a file at `~/.codex/hooks/hooks.json` is
  silently ignored, with no warning even if malformed. Event keys are PascalCase
  (`SessionStart`/`SessionEnd`). The timeout key is `timeout`, in seconds; unknown keys
  inside a handler are dropped without warning, so a typo just yields the default.
  `SessionEnd` is clamped to a 3 s maximum (1 s if omitted). Hook commands use an
  absolute path rather than `$HOME`: whether Codex runs them through a shell is
  unverified, and a failing Codex hook is invisible — the session just falls back to
  the inferred `meta~Ns` tier.
- **Codex hooks require trust on first run.** They are discovered as `untrusted` and do
  not execute until approved in the TUI ("Hooks need review" → "Trust all and
  continue"). Approving writes a `[hooks.state]` table into `~/.codex/config.toml`,
  which is a symlink into this repo — the same way Codex already writes `[projects]`
  trust levels there.
- **Claude `SessionEnd` needs an explicit `timeout`**: without one it gets only a ~1.5 s
  shutdown budget and may be killed mid-write.
- **Do not** rely on open file descriptors: both agents open→append→close their
  transcript per turn. Only the Codex app-server keeps rollout files open.

## Resurrect carry-over

`agent-panes-resurrect save` is wired to `@resurrect-hook-post-save-all`, the first point
at which tmux-resurrect's archive exists. It appends a short block (three lines, or one
when the id could not be resolved) to the *archived* copy of each annotatable pane, so
the restored pane prints that session's id and a resume command right after replaying its
contents.

Nothing is restarted, and there is no restore-side code *for this feature*: the plugin
recreates every pane as `cat '<content file>'; exec $SHELL`, so the block is simply part
of what is replayed. `@resurrect-hook-post-restore-all` is wired, but to
`utils/tmux-refit-windows`, which belongs to no feature here — it repairs windows whose
replayed layout is a different size from the window, and knows nothing about agents. It
is mentioned because the two hooks share a namespace and a silence requirement, not
because they share anything else.
Verified against tmux-resurrect `cff343cf`; every internal it leans on is undocumented,
and TPM updates the plugin via `prefix + U` with no review — which is why
`check_resurrect_plugin_contract` asserts all six of them.

### Where the ids come from

Three sources feed one record per session, folded by `(pane id, agent, session id)`:

| Source | Covers | Tier |
|---|---|---|
| `agent-panes`, the live `/proc` scan | whatever is running at the moment of the save | `hook`, `sessions`, `env`, `cmdline`, `fd`, or an inferred `meta~Ns` / `btime~Ns` |
| the agent's own exit banner in the archived capture | every session either agent exited *gracefully* out of and the pane's scrollback still holds, including ones that started and ended between two saves | `scrollback` |
| this script's own block, parsed back out of the capture | everything a previous save wrote down — the only source for a session that was killed or lost to a reboot | whatever the block recorded |

The harvest reads `pane_contents.tar.gz`, not `tmux capture-pane`. The archive is a
file the hook already opens, it holds each pane's *whole* history with wrapped lines
rejoined (`capture-pane -epJ -S -<history_size>`), and the hook runs inline with the
save and freezes the client that triggered it — a subprocess per pane is the one thing
it must not do. Measured on a 78-pane server: 14 ms to decompress and unpack in memory,
115 ms to scan 5.6 MB, against a whole-hook time of 0.35 s.

**Claude leaves a banner too, and a third of them name a title rather than a uuid.** Its
*conversation* leaves nothing — it draws on the alternate screen — but a graceful exit
leaves that screen and then writes `Resume this session with: claude --resume <arg>` to
the main one, where the scrollback keeps it. `<arg>` is the bare uuid unless the session
carries a custom title, in which case it is that title, double-quoted; 36.8% of this
machine's 408 transcripts carry one. Read out of the shipped bundle (`2.1.220`) and
reproduced in a throwaway server.

A title is resolved back to a uuid through `lib/claude_names.py`, and only ever to an
unambiguous one. The sweep is ~0.15 s warm over ~1 GB of transcripts, so it is built at
most once per save, and only when a pane holds a title that has neither been recorded nor
refused. Both halves of that gate are load-bearing: the banner is Claude's output, not
ours, so the strip never removes it, and the title would otherwise be looked up again
every 15 minutes for as long as it stays in the pane's history.

**What leaves no banner is a session that did not exit gracefully** — killed, or lost to
a reboot. Reading our own block back is what covers those, and it is not an optimisation:
a pane is stripped whenever it is annotated, so for them the block is the only carrier
there is.

**A text match is evidence about text.** A `codex resume <uuid>` in a document, a
ripgrep hit or a `cat`ed handoff is indistinguishable from a real banner, so those rows
are recorded as `scrollback` and printed as `(recovered)`. Genuine matches are capped
per pane (`MAX_HARVEST_PER_PANE`) so one `cat` of a session dump cannot flood the file.

### What gets annotated

- **Live and exited sessions alike.** A pane whose agent has exited is the case that
  most needs the block: Claude draws on the alternate screen and leaves nothing in
  scrollback to replay. The block says which of the two it was, and dates an exited one
  by when it was last seen rather than by the save.
- **The block is printed even when the agent already printed its own.** Codex writes a
  resume banner on exit and the capture replays it, so such a pane says it twice, on
  purpose. Suppressing would mean parsing another tool's output to decide whether our
  own record is worth printing, and the block is not a restatement anyway: it carries
  the `cd` into the project directory that `claude --resume` requires, plus the save
  time and the pane binding.
- **Every session the pane has held**, newest first, live outranking exited, up to
  `MAX_STANZAS` (6, `AGENT_SESSIONS_MAX_STANZAS`). Past that the block prints a counted
  overflow line and the rest stay in the sidecar — where they age out `KEEP_DAYS` after
  they stop being printed, since being printed is what keeps their evidence alive. Raise
  the cap rather than lose them if a pane routinely holds more.
- **Placement is by `%N` *plus the server that issued it*, never by location.**
  `renumber-windows on` reassigns `session:window.pane` the moment a window closes, so a
  stored location is stale by however long the agent has been gone. But `%N` alone is not
  enough either: it is a per-server counter that restarts at 0, while the sidecar
  deliberately outlives the server for `KEEP_DAYS`. Without the server stamp, the first
  save after a reboot places pre-reboot records onto whichever restored panes inherited
  those numbers — and since a pane is only stripped when it is also annotated, that false
  claim would then be permanent. A record from another server generation, or with no
  stamp at all, is dropped. Its block is already in that pane's scrollback from the
  previous restore, and the capture carries it forward untouched.
- **This is not a guarantee about the archive.** Blocks are still written to
  `pane-<location>`, and the plugin fixed those filenames from its own earlier pane list,
  so a window closing between the capture and this hook can still misfile one. Closing
  that window needs a hook running before the capture, and `post-save-layout` — the only
  candidate — fires before the archive exists.
- **Coverage gap**, stated exactly. A session is lost only when it left no banner —
  killed, or lost to a reboot — *and* was never running at any save. Continuum saves
  every 15 min while a client is attached, so in practice that means a short session
  during a stretch when nothing was attached. Everything else is covered: live at a
  save → sidecar → printed from then on; exited gracefully → its own banner; titled →
  resolved, unless the title names more than one session. `agent-scrollback-ids` remains
  the by-hand tool for what is left, and its index is the broad one, so it can offer a
  best guess where the hook refuses to.

### The block is read as well as written

The block is this script's own output, and the harvest parses it back. That is what
carries a pane's ids across a tmux server restart — the sidecar stamps every record with
the server that issued its `%N`, and a new server reissues those numbers to unrelated
panes, but the restored pane replays the capture block and all, so the evidence travels
with the pane's contents. It is also what makes the strip safe: a pane is stripped
whenever it is annotated, so without this pass the strip would delete the only record
of every Claude session that ever ran there.

- **Harvest before strip, and write the sidecar before touching the archive.** A crash
  in between costs a block the next save rewrites, never an id.
- **The parse is layered.** Only the `resume:` line is required; the head and tail lines
  add the name, the source and the dates. Anything the structured pass cannot make sense
  of falls through to the ordinary resume-marker patterns, which also recovers blocks
  written by the pre-`#` renderer. A wording change in the renderer costs a name — it
  cannot cost a session id, and it cannot fail silently into deleting one. `render →
  parse → render` convergence is asserted in the tests, for exact, inferred and
  recovered tiers alike.
- **A stanza names the pane and server it belongs to** (`bound to %13@545bbc4f`, the
  server id hashed to eight hex digits, since only equality is ever asked of it). A
  stanza claiming *this* server but a different pane is text that arrived here rather
  than history that happened here — a preview, a pasted stanza, a `cat` of another
  pane's capture — and is dropped whole, fallback included. A stanza with no binding, or
  one from another server generation, cannot be checked and is taken on trust: those are
  exactly the two carry-over cases. The intruding lines are stripped either way, so the
  contamination cleans itself up instead of accumulating.
- **A line carrying the sentinel away from column 0 is evidence about nothing.** It is a
  block that arrived as text — an indented paste, a `cat` of another pane's capture, a
  quoted example in a document — so it goes into neither pass. Letting it fall through to
  the pattern scan would be worse than reading it as ours: the resume line inside still
  matches, so the ids would be filed against that pane at face value, and off column 0
  the strip would never remove them, so it would re-seed itself on every save.
- **`save --dry-run` prints its preview at column 0, exactly as the hook would write
  it.** That is the safe form, not the risky one: run inside a pane it lands in that
  pane's scrollback, where every stanza is refused by its own binding except the pane's
  own, and where the strip removes it on the way past. Indenting it would invert both
  properties.
- **A refused harvest must also stop the injection**, and `cmd_save` is what enforces it.
  The strip is a delete — for a Claude session the block is the only place the id was
  ever written — so a save that has not read those blocks writes its sidecar and leaves
  the archive exactly as it found it. The same holds when the sidecar write itself fails.
- **The harvest is refused outright** when the pane list moved, when
  `@resurrect-capture-pane-contents` is off (the archive on disk is then a stale one from
  whenever it was last on), when the archive is older than the state file this save
  wrote, when the shared patterns did not import, or when anything in it raises. Captures
  are named by location, and with `renumber-windows on` a window closing between the
  plugin's capture and this hook shifts every location after it. The plugin's own state
  file (`last`) records the list it filed the captures under; a location in it that is no
  longer live means something moved. As a write a misfiled block lasts until the next
  save; as a *record* it would be permanent.
- **inject() will not rewrite an archive the harvest did not read.** It is handed the
  archive's identity from the harvest pass and refuses if it no longer holds, so the
  strip can never delete blocks out of a file nobody read first.
- **Both harvest passes are capped per pane.** Genuine text at `MAX_HARVEST_PER_PANE`,
  and blocks at `MAX_STANZAS` — a block this hook wrote can never hold more stanzas than
  it prints, so anything past that arrived as text. Uncapped, a `cat` of the archive into
  a pane after a restore would file every pane's stanzas there (the binding check waves
  those through: a previous server generation is precisely what it cannot judge) and they
  would evict the pane's real records from its own block, which is how a display cap
  turns into a delete.
- **A cap ranks; it never slices the file.** What the cap drops is stripped out of the
  archive in the same save, so the order it applies is a choice about which ids to
  delete. Stanzas the pane can prove are its own come first — one bound to this server
  but another pane was already refused whole, so a current-tag binding can only be
  ours — then the most recently seen. Taking the tail instead kept the *oldest*: the
  renderer writes newest-first, and the undated fallback rows are appended after every
  structured one, so they outranked all of them. A resolved title is located in the
  capture by the title it was read from, not by a uuid that never appears there, for the
  same reason.
- **The shared-pattern import is guarded.** It is the first fallible statement in a save
  hook, and it runs before there is anywhere to log — an `ImportError` would kill the
  hook without a word, since tmux-resurrect discards both the exit status and stderr.
  Losing the harvest is survivable; losing the hook silently is not, which is why
  `check.sh` fails when the fallback is what is actually in use.

### Constraints that must not be re-derived

- **Save order matters.** `post-save-layout` fires before the archive exists and
  `save/pane_contents/` is emptied before `post-save-all`, so the hook has to go
  through `pane_contents.tar.gz` itself. It gets no arguments and is not told the
  resurrect dir, so it re-derives it the way `helpers.sh` does — including the global
  `~` replacement, not a leading-only one.
- **The hook must be silent.** A manual `prefix + C-s` runs `save.sh` through
  `run-shell`, whose stdout is the job pipe: one printed line drops the active pane
  into view-mode and renames the window `[tmux]`. stderr is `/dev/null` on every
  trigger path, so `save` redirects both to `<resurrect dir>/agent_sessions.log`
  whenever stdout is not a tty. That log is the only observability there is —
  tmux-resurrect discards the hook's exit status entirely, so **every** failure path
  must reach the log or it does not exist.
- **Never run `save` or `purge` without `$TMUX`.** Every `tmux` call would resolve
  against the *default* server, so `@resurrect-dir` falls back to the real one and a
  stray manual run rewrites a live session's archive. The script refuses; keep it that
  way.
- **Stripping is load-bearing, not tidiness.** A restored pane replays the block into
  its own scrollback, so the next capture contains it. Without a strip pass one block
  accumulates per reboot. Matching runs on the ANSI-stripped line because tmux
  re-emits its own idea of the cell attributes rather than the bytes written — an
  emitted `ESC[0m ESC[2m` comes back as `ESC[0;2m`. The pre-`#` sentinel is still
  recognised so blocks written by older versions are removed rather than stacked.
- **One predicate decides what is ours.** `marker_line()` is what both the strip and
  the harvest ask, and they must never drift: a line the strip removes but the harvest
  never read is a session id deleted without being written down, and a line the harvest
  reads but the strip leaves behind stacks a copy on every reboot.
- **The sentinel starts with `#`, at column 0.** Column 0 is what stops prose, ripgrep
  hits and indented code samples being stripped. The `#` makes every line of the block
  a shell comment: it lands in a pane that is about to hand control to an interactive
  shell, and pasting a line beginning with a bare `[agent-session]` made bash glob it.
- **Every injected line opens and closes with `ESC[0m`.** A live Claude pane's capture
  ends on an unclosed colour, and `cat` replays that state onto the block and the
  prompt after it.
- **Fields are sanitised** for C0, C1, DEL and the Unicode line separators. Session
  titles are free text an agent wrote and end up replayed into a terminal; an
  unfiltered `ESC[6n` makes the restored shell receive the reply as typed input.
- **A block outlives the agent that produced it, on purpose.** Once restored it is
  ordinary pane scrollback, so the id survives repeated reboots without the agent ever
  being restarted. It carries the time it was written with, which marks it as history
  rather than a live claim.
- **The in-archive block is best effort; `agent_sessions.json` is the durable record.**
  tmux-resurrect writes `pane_contents.tar.gz` in place with no temp+rename and no
  lock, and a manual save bypasses continuum's lock entirely, so a concurrent save can
  still clobber an injected archive. The hook's own rewrite is atomic, refuses to
  republish an archive it found truncated, and aborts if the archive changed under it.
- **Panes whose session name contains `/`, `:` or `'` are skipped.** tmux-resurrect
  already mishandles all three by itself (failed write, no content file, and a
  `cat '<file>'` that kills the pane, respectively). They still land in the sidecar.
- **Do not set `@resurrect-processes` to `':all:'`.** Restore currently does not respawn
  agent panes — `restore_pane_process` uses `send-keys`, and neither `node` nor `codex`
  is in the default list — which is why the block survives above whatever restore types.

## Commands

| Command | Purpose |
|---|---|
| `agent-panes [--json]` | map every running session to `session:window.pane` and its id |
| `agent-panes-resurrect save [--dry-run]` | the hook target; silent by design |
| `agent-panes-resurrect list [--json]` | read the sidecar |
| `agent-panes-resurrect purge [--dry-run]` | remove every block, sidecar, log |
| `agent-scrollback-ids` | recover ids exited agents printed into scrollback |
| `claude-sessions` | list running Claude Code sessions with details |

`list`'s `LAST SEEN` is when the agent was last observed *running* there, not now, and
`-` where the id was recovered from text, which carries no such time. It is never
invented: a recovered row is dated from the block it came from or from its own
transcript's mtime, and otherwise left blank rather than dated to the save that read it.

### The sidecar

`agent_sessions.json` (version 2) holds **every** session a pane has held, not just the
one running when a save fired. Nothing is dropped for being superseded — starting a new
session in a pane used to erase the previous one's id at the very next save, which
capped the file at one record per pane.

Two timestamps, and ageing keys on the second:

- `last_seen` — when the agent was observed running there.
- `recorded` — the last save that found *any* evidence of the record: a live process, a
  banner in the capture, or the block we wrote for it. Pruned at `KEEP_DAYS` past this.

So a record lives as long as its evidence lives in the pane's scrollback, plus 30 days
of grace once the scrollback loses it — the pane's own `history-limit` is the real bound.
Version 1 files have no `recorded` and age from `last_seen`, exactly as they used to.

There is no way to delete a single record; `purge` is all or nothing, and it now exits
non-zero if it could not strip the archive, since leaving the sidecar gone and the blocks
in place is the worst of both. An advisory `scrollback` row from a document that merely
mentioned a resume command will keep being re-found while that text is in the pane, and
is labelled `(recovered)` for that reason.

A sidecar that exists but is not a sidecar is moved to `agent_sessions.json.unreadable`
rather than written over: an empty read and a damaged file look identical to the merge,
which would otherwise publish a fresh record over it and take every id along. The
predicate is "are these bytes a sidecar", never "does it hold anything" — a well-formed
file whose `panes` are empty is what a machine with no agent panes writes, and diagnosing
that as damage renamed it aside on every save. The kept file is the one thing in that
namespace the scratch sweep leaves alone, since a promise to keep it that expires after
an hour is not one; `purge` is what removes it.

| Env | Effect |
|---|---|
| `AGENT_SESSIONS_KEEP_DAYS` | how long a record survives after the last save that found evidence of it (30) |
| `AGENT_SESSIONS_MAX_STANZAS` | most sessions printed in one pane's block (6); the rest stay in the sidecar |
| `NO_COLOR` | render the block without SGR |
| `SCROLLBACK_DEPTH` | how far back `agent-scrollback-ids` searches |

## Tests

```bash
./agent-sessions/check.sh                     # every check for this directory
./agent-sessions/tests/test-agent-tools.py    # just the unit tests
```

`check.sh` derives its own repo root and is dispatched from
`./scripts/check-dotfiles.sh` as one entry, so a failure here fails the repo checks. It
does not cover everything about this feature: resolving the hook `command` strings in
`claude/settings.json` and `codex/hooks.json` stays in the jq-gated parent, and
`claude-sessions` is linted by the parent's generic bash/shfmt/shellcheck lists. **Re-run after upgrading Claude or
Codex**: it covers the resume-marker patterns and the title index, which read those
tools' terminal output and on-disk records and rot silently when either changes, plus the
marker rendering, stripping, parsing and pane-placement in `agent-panes-resurrect`, and
the shared imports — which are guarded, so a broken one degrades to "no harvest" and this
is the only place it would be noticed.

The syntax check also runs a flat name-binding pass over every Python file here. It is
deliberately scope-insensitive, so it never reports a shadowing or a
use-before-assignment, but it does catch a name the file uses and never binds — which is
what a dropped `import` is, and what a save hook turns into a completely silent no-op.
That happened once (`03:31:44 failed: NameError: name 'hashlib' is not defined`);
`ast.parse` was blind to it, and of 18 top-level imports the tests exercise 13. The pass
catches all 18.

`agent-panes-resurrect save --dry-run` is the other way to see what a save would do. It
reads the archive, so the harvest and every recovered id show up in the preview, and it
writes nothing. Running it inside a pane is safe by construction rather than by
avoidance — see the stanza binding above.
