# __author__ == Junfeng Lei

"""What Claude Code and Codex look like on this machine: their processes, the
files their sessions live in, and the directory each session was opened in.

One copy for every tool, for the reason lib/agent_ids.py gives: this encodes
another program's private layout, it rots silently when that program changes,
and the tests can only cover one copy. Before it existed the transcript globs
were written out four times and the agent test twice, and the copies had drifted
apart and away from Codex: agent-pane-register matched any path containing
`/codex` (codex's own `bin/codex-code-mode-host` among them), and no copy found a
rollout Codex had compressed or read the right uuid out of a suffixed name.

The index is by file name only. A file is opened by the caller, for the one
session it actually needs, through transcript_cwd().
"""

import glob
import json
import os
import re

import procinfo
from agent_ids import UUID
from claude_names import CLAUDE_PROJECTS

try:
    from compression import zstd  # Python 3.14+
except ImportError:
    zstd = None

# A truncated or corrupt `.zst` raises EOFError or ZstdError, neither an OSError.
# Either would escape the save hook's harvest and cost every pane its block.
READ_ERRORS = (OSError, EOFError) + ((zstd.ZstdError,) if zstd else ())

AGENTS = ("claude", "codex")

CODEX_SESSIONS = os.path.expanduser("~/.codex/sessions")
CODEX_INDEX = os.path.expanduser("~/.codex/session_index.jsonl")

# The session id is the first uuid after the timestamp. Codex (seen from 0.158
# on) may append a second one, as in `rollout-<stamp>-<thread>_<other>.jsonl`,
# and that second uuid names no thread at all: the file's own session_meta `id`
# is the first, and state_5.sqlite has no thread row for the second. Anchoring
# on the uuid nearest `.jsonl`, as every earlier copy did, picks the wrong one
# for exactly those files.
#
# Codex also compresses a rollout to `.jsonl.zst` once it has sat idle for about
# a week -- 1035 of 1092 here, 2026-10-28 -- while its own thread table goes on
# naming the `.jsonl`. Such a session is still resumable, so it still counts.
#
# The filename stamp is local time.
ROLLOUT_RE = re.compile(
    r"rollout-(\d{4}-\d\d-\d\d)T(\d\d)-(\d\d)-(\d\d)-(" + UUID + r")(?:_" + UUID + r")?\.jsonl(?:\.zst)?$"
)

# How far into a transcript to look for the directory it was opened in. Codex
# puts it in the session_meta header on line 1; Claude's first records are
# mode/permission/bridge entries and the cwd shows up around line 5. Ten is well
# clear of both. The per-line cap has to clear Codex's header, which carries the
# whole system prompt: ~52 KB as of 0.165, against what used to be a 64 KiB cap.
TRANSCRIPT_HEAD_LINES = 10
TRANSCRIPT_LINE_BYTES = 256 * 1024


def agent_kind(pid, comm):
    """Which agent a process is, if any.

    comm is not always the agent's own name: background sessions exec the
    versioned binary directly, so comm reads as e.g. '2.1.220' -- which is what
    an installed Claude reads as on macOS as a matter of course, since it is
    exec'd straight out of ~/.local/share/claude/versions/. The executable path
    is the reliable signal -- matched on a whole path segment or the basename,
    since a bare substring also catches siblings that merely share the prefix,
    such as codex's `bin/codex-code-mode-host`.
    """
    if comm in AGENTS:
        return comm
    exe = procinfo.exe(pid)
    if not exe:
        return ""
    base = os.path.basename(exe)
    return next((name for name in AGENTS if base == name or f"/{name}/" in exe), "")


def rollout_id(path):
    """The session id a Codex rollout path belongs to, or None if it is not one."""
    match = ROLLOUT_RE.search(path)
    return match.group(5) if match else None


def transcript_index():
    """agent -> session id -> transcript path.

    Both agents answer `--resume` out of these files, so this is what decides
    whether a session can still be resumed (agent-resume) and when it was last
    used (the save hook). One function, so those two can never disagree.
    """
    index = {"claude": {}, "codex": {}}
    for path in glob.glob(f"{CLAUDE_PROJECTS}/*/*.jsonl"):
        index["claude"][os.path.basename(path)[:-6]] = path
    for path in glob.glob(f"{CODEX_SESSIONS}/*/*/*/rollout-*.jsonl*"):
        sid = rollout_id(path)
        if sid:
            index["codex"][sid] = path
    return index


def transcript_cwd(path):
    """The directory a session was opened in, read from its own transcript.

    This is the part of the resume line that the agents' exit banners leave out
    and that `claude --resume` cannot do without -- it resolves the id inside the
    project directory of the current cwd, so a recovered row with no `cd` in
    front of it produces a command that quietly fails wherever it is pasted.

    A compressed rollout needs compression.zstd, which is Python 3.14+. Without
    it -- macOS's stock python3 is 3.9 -- such a session is still resumable, it
    just comes back with no cwd, the same as any transcript that cannot be read.
    """
    try:
        if not path.endswith(".zst"):
            fh = open(path, errors="ignore")
        elif zstd:
            fh = zstd.open(path, "rt", errors="ignore")
        else:
            return ""
        with fh:
            for _ in range(TRANSCRIPT_HEAD_LINES):
                line = fh.readline(TRANSCRIPT_LINE_BYTES)
                if not line:
                    break
                try:
                    record = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(record, dict):
                    continue
                payload = record.get("payload")
                # Codex nests it under session_meta's payload, Claude has it at
                # the top level of most records.
                for cwd in (record.get("cwd"), (payload or {}).get("cwd") if isinstance(payload, dict) else None):
                    if isinstance(cwd, str) and cwd:
                        return cwd
    except READ_ERRORS:
        pass
    return ""


def codex_titles():
    """session id -> thread name, from the index Codex keeps for its own picker."""
    titles = {}
    try:
        with open(CODEX_INDEX, errors="ignore") as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if rec.get("id"):
                    titles[rec["id"]] = rec.get("thread_name") or ""
    except OSError:
        pass
    return titles
