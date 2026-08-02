# __author__ == Junfeng Lei

"""Resume-marker patterns: the session ids Claude Code and Codex print on exit.

Shared by agent-sessions/bin/agent-scrollback-ids, which sweeps live panes by hand,
and by agent-sessions/bin/agent-panes-resurrect, which sweeps the captures
tmux-resurrect just archived. It lives here rather than in either of them because
these patterns match *another program's terminal output*: they rot silently the
next time Claude or Codex changes its wording, and a second copy is a copy the
tests do not cover. agent-sessions/tests/test-agent-tools.py is what catches that,
and it can only catch what there is one of.

What a match means is deliberately weak. A resume command sitting in a comment, a
ripgrep hit or a line of documentation is indistinguishable from a real exit
banner, so callers must treat a hit as evidence about *text*, not about a session
that ran there.
"""

import re

UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
UUID_RE = re.compile(UUID)

# Claude prints `claude [--worktree <name> ]--resume <arg>`, where <arg> is the
# session uuid, bare, unless the session carries a user-set title -- in which case
# it is that title, always double quoted, with \ and " backslash-escaped.
#
# The gap between `claude` and the flag is a run of `-flag [value]` pairs rather
# than `.{0,120}?`, so prose that merely mentions claude ahead of an unrelated
# --resume on the same line cannot bridge the two.
_NOT_FLAG = r"(?!--resume\b|-r\b)"
GAP = r"(?:[ \t]+" + _NOT_FLAG + r"-[^\s]*(?:[ \t]+" + _NOT_FLAG + r"[^\s]+)?){0,4}"
RESUME_FLAG = r"[ \t]+(?:--resume|-r)(?:[ \t]*=[ \t]*|[ \t]+)"
# `claude --resume "<name>"` in prose (docs, help text) is a placeholder, not a session.
NOT_PLACEHOLDER = r'(?!["\']?<)'

# A name is captured as group 'name'/'name2', a uuid as group 'sid'. Every pattern
# stays on one line: tmux capture-pane -J already rejoins wrapped lines for us.
PATTERNS = [
    # codex resume, then select <name> (<uuid>)
    ("codex", re.compile(r"codex resume,\s*then select\s+(?P<name>.+?)\s+\((?P<sid>" + UUID + r")\)", re.I)),
    # codex resume <uuid>
    ("codex", re.compile(r"codex resume\s+(?P<sid>" + UUID + r")", re.I)),
    # claude [--worktree <name>] --resume <uuid>
    ("claude", re.compile(r"\bclaude\b" + GAP + RESUME_FLAG + r"(?P<sid>" + UUID + r")\b", re.I)),
    # claude [--worktree <name>] --resume "<title>"   (single quotes only ever hand-typed)
    (
        "claude",
        re.compile(
            r"\bclaude\b" + GAP + RESUME_FLAG + NOT_PLACEHOLDER
            + r"(?:\"(?P<name>(?:[^\"\\\n]|\\.){1,200})\"|'(?P<name2>[^'\n]{1,200})')",
            re.I,
        ),
    ),
]

# Claude escapes the title as \\ then \" ; one left-to-right pass undoes both.
_UNESCAPE = re.compile(r"\\(.)")


def is_junk_name(name):
    """Whether a captured name is plainly not a session title.

    Placeholders (`<name>`), shell variables and brace expansions all come from
    prose or an un-run command line. They matter because a junk name is looked up
    in the name index, where colliding with a real title would report that
    session in the wrong pane.
    """
    return not name or name[0] in "<$" or "{" in name or "}" in name


def extract(text):
    """(agent, session id, name) triples in one pane's scrollback."""
    # Cheap reject before running four regexes over a 20k-line capture. Every
    # pattern needs one of these two literals -- `resume` for the codex forms and
    # the long claude flag, `claude` for the `-r` short flag, which spells out
    # neither. Lowered because the patterns themselves are case-insensitive.
    low = text.lower()
    if "resume" not in low and "claude" not in low:
        return []
    hits = []
    for agent, rx in PATTERNS:
        for m in rx.finditer(text):
            groups = m.groupdict()
            name = groups.get("name")
            if name is not None:
                name = _UNESCAPE.sub(r"\1", name)
            name = name or groups.get("name2") or ""
            sid = groups.get("sid")
            # A uuid is printed bare, so a quoted one was hand-typed and lands in
            # the title pattern. It is still an id, not a name to look up.
            if not sid and UUID_RE.fullmatch(name):
                sid, name = name, ""
            if not sid and is_junk_name(name):
                continue
            hits.append((agent, sid, name))
    return hits
