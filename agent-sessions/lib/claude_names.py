# __author__ == Junfeng Lei

"""Claude session titles, read back out of Claude's own on-disk records.

Claude prints `claude --resume "<title>"` rather than a uuid whenever the
session carries a custom title, so for those sessions a title is the only handle
its exit banner leaves behind. Resolving one means reading another program's
private record format -- the same reason lib/agent_ids.py exists, and with the
same consequence: it rots silently the next time Claude changes the format, and
a second copy is a copy the tests do not cover.

Two callers want different things from it, which is what `unique` selects:

- `agent-scrollback-ids` is interactive, prints what it could not map, and its
  output is read by someone who can tell a wrong row from a right one. It takes
  the broadest index available and lets recency break ties.
- `agent-panes-resurrect` writes a resume command into a pane that is replayed
  after a reboot, unattended, where a wrong id is indistinguishable from a right
  one. It takes `unique=True` and gets nothing rather than a guess -- titles are
  free text a person or an agent chose, and short ones (`rm`, `review`) really
  do name dozens of different sessions.

Only `custom-title` feeds the strict index. That is the field Claude's own
banner prints (its resume-hint writer reads the session's custom title and falls
back to the bare uuid), so it is the only one a banner can have come from;
`agent-name` names something else and is included only for the broad index.
"""

import glob
import json
import os
import re

CLAUDE_PROJECTS = os.path.expanduser("~/.claude/projects")
CLAUDE_SESSIONS = os.path.expanduser("~/.claude/sessions")

UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")

# Claude records a rename inside the transcript, as a one-line object.
NAME_FIELDS = {"custom-title": "customTitle", "agent-name": "agentName"}
STRICT_FIELDS = {"custom-title": "customTitle"}

# Name records are ~120 bytes. Anything larger is a message that merely mentions
# the marker -- skipping those keeps the sweep cheap and stops a conversation
# *about* renaming from being read as a rename.
MAX_NAME_RECORD = 4096


def name_index(unique=False, projects=CLAUDE_PROJECTS, sessions=CLAUDE_SESSIONS):
    """Claude session title -> uuid.

    Claude records a rename inside the transcript itself, so the whole project
    tree has to be swept; ~1 GB of jsonl takes about 0.17 s warm.

    With `unique`, a title that names more than one session is left out
    entirely rather than resolved to the most recent of them. There is no
    tie-break that can be right: the banner says only what the title was, and
    the caller that asks for this is writing a `--resume` somebody will run
    without checking.
    """
    fields = STRICT_FIELDS if unique else NAME_FIELDS
    # name -> {sid: newest stamp seen for it}
    seen = {}

    def offer(name, sid, stamp):
        if not name or not sid or not isinstance(name, str) or not isinstance(sid, str):
            return
        if not UUID_RE.fullmatch(sid):
            return
        by_sid = seen.setdefault(name, {})
        if stamp > by_sid.get(sid, -1):
            by_sid[sid] = stamp

    for path in glob.glob(os.path.join(projects, "*", "*.jsonl")):
        try:
            stamp = os.path.getmtime(path)
            with open(path, "rb") as fh:
                for line in fh:
                    if len(line) > MAX_NAME_RECORD:
                        continue
                    if not any(key.encode() in line for key in fields):
                        continue
                    try:
                        record = json.loads(line)
                    except ValueError:
                        continue
                    if not isinstance(record, dict):
                        continue
                    field = fields.get(record.get("type"))
                    if field:
                        offer(record.get(field), record.get("sessionId"), stamp)
        except OSError:
            continue

    # Live sessions also carry a name in Claude's own registry, but it is a
    # different field. A user or hook rename is written through as a
    # `custom-title` record, which the sweep above already has; everything else
    # that lands in the registry `name` -- an AI job title, a slug derived from
    # the cwd -- never becomes the title the banner prints. Measured: of 12 live
    # registry entries here, 7 are names no banner can ever produce, and the
    # other 5 are already in the transcript index under the same id.
    #
    # So this is a broad-index source only: a name a reader can judge, not one a
    # `--resume` may be built from.
    if not unique:
        for path in glob.glob(os.path.join(sessions, "*.json")):
            try:
                with open(path) as fh:
                    record = json.load(fh)
                # Inside the try: these are per-pid files that Claude removes as
                # sessions exit, and a stat racing that removal used to raise
                # out of here -- through the save hook's blanket handler, which
                # reads any exception as "no harvest" and skips the injection
                # for every pane in that save.
                stamp = os.path.getmtime(path)
            except (OSError, ValueError):
                continue
            if isinstance(record, dict):
                offer(record.get("name"), record.get("sessionId"), stamp)

    index = {}
    for name, by_sid in seen.items():
        if unique and len(by_sid) > 1:
            continue
        index[name] = max(by_sid.items(), key=lambda item: item[1])[0]
    return index
