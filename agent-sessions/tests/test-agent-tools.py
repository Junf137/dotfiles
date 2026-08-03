#!/usr/bin/env python3

# __author__ == Junfeng Lei

"""Self-tests for the pure logic in the agent-session utilities.

Two things are covered, both of which fail silently in production:

  * the resume-marker patterns in agent-sessions/bin/agent-scrollback-ids, which
    are matched against terminal output produced by Claude Code and Codex and so
    can rot when either agent changes its wording -- run these after upgrading an
    agent;
  * the marker rendering and stripping in agent-sessions/bin/agent-panes-resurrect,
    where a strip that stops matching means a block stacks up on every reboot, and
    an unsanitised field means a control sequence is replayed into a live terminal.

    ./agent-sessions/tests/test-agent-tools.py

The expected strings below are taken from the emitters themselves. Claude prints
`claude [--worktree <name> ]--resume <arg>`, where <arg> is the session uuid,
bare, unless the session carries a user-set title -- in which case it is that
title, always double quoted, with \\ and " backslash-escaped.
"""

import json
import os
import re
import sys
import tempfile
import time

BIN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin")
TOOL = os.path.join(BIN, "agent-scrollback-ids")
RESURRECT_TOOL = os.path.join(BIN, "agent-panes-resurrect")
RESUME_TOOL = os.path.join(BIN, "agent-resume")

UUID = "1a03df5b-6a91-49de-927c-6920a34539c2"
CODEX_UUID = "019f60f4-3809-76d1-a643-024fc3db3eec"

SHOULD_MATCH = [
    ("claude exit banner, named", 'Resume this session with:\nclaude --resume "cleanup-worktree-script"\n', ("claude", None, "cleanup-worktree-script")),
    ("claude exit banner, uuid", f"\nResume this session with:\nclaude --resume {UUID}\n", ("claude", UUID, "")),
    ("claude title with spaces", 'claude --resume "Condense Molmo label handoff report"\n', ("claude", None, "Condense Molmo label handoff report")),
    ("claude --worktree then uuid", f"claude --worktree keen-owl-x9 --resume {UUID}\n", ("claude", UUID, "")),
    ("claude --worktree then title", 'claude --worktree swift-fox-a1b2 --resume "my session name"\n', ("claude", None, "my session name")),
    ("claude escaped quote unescaped", 'claude --resume "say \\"hi\\" now"\n', ("claude", None, 'say "hi" now')),
    ("claude escaped backslash unescaped", 'claude --resume "back\\\\slash"\n', ("claude", None, "back\\slash")),
    ("claude --resume=<uuid>", f"claude --resume={UUID}\n", ("claude", UUID, "")),
    ("claude -r short flag", f"claude -r {UUID}\n", ("claude", UUID, "")),
    ("claude single-quoted, hand typed", "claude --resume 'single-quoted-name'\n", ("claude", None, "single-quoted-name")),
    ("claude backgrounded variant", f"Your conversation was backgrounded - resume it with: claude --resume {UUID}\n", ("claude", UUID, "")),
    ("claude wrong-directory variant", f"cd /home/junf/Mecka/p && claude --resume {UUID}\n", ("claude", UUID, "")),
    ("claude with trailing flags", f"claude --resume {UUID} --dangerously-skip-permissions\n", ("claude", UUID, "")),
    ("codex uuid", "To continue this session, run codex resume 019f85e8-b749-7101-9771-beee8b588342\n", ("codex", "019f85e8-b749-7101-9771-beee8b588342", "")),
    ("codex named select", f"To continue this session, run codex resume, then select [MC] Hand Pose build ({CODEX_UUID})\n", ("codex", CODEX_UUID, "[MC] Hand Pose build")),
    ("codex title containing parens", f"run codex resume, then select QC (phase 2) ({CODEX_UUID})\n", ("codex", CODEX_UUID, "QC (phase 2)")),
    # A uuid is printed bare, so a quoted one was hand-typed: still an id.
    ("claude quoted uuid is an id, not a name", f'claude --resume "{UUID}"\n', ("claude", UUID, "")),
    # The patterns are case-insensitive, so the cheap pre-filter must be too.
    ("claude capitalised flag survives the pre-filter", f"claude --Resume {UUID}\n", ("claude", UUID, "")),
]

SHOULD_REJECT = [
    ("prose placeholder", 'claude --resume "<name>"\n'),
    ("usage line", "Usage: claude -p --resume <session-id|title>\n"),
    ("argument-less startup tip", "Run claude --continue or claude --resume to resume a conversation\n"),
    ("error line without claude", 'Error: --resume "foo" matches 3 sessions.\n'),
    ("plain prose", "I will resume the analysis later today.\n"),
    ("flag on the next line", 'claude\n--resume "should-not-match"\n'),
    ("unrelated claude earlier in line", 'ask claude about it then run somethingelse --resume "nope"\n'),
    # An unexpanded name would be looked up in the name index, where colliding
    # with a real title would report that session in the wrong pane.
    ("shell variable as name", 'claude --resume "$SESSION"\n'),
    ("brace expansion as name", 'claude --resume "${SESSION_ID}"\n'),
]


def load_tool(path=TOOL):
    """Execute the tool's module body without running main().

    __file__ is supplied because the tools derive sibling paths from it.
    """
    with open(path) as handle:
        source = handle.read().split("if __name__ ==")[0]
    namespace = {"__file__": path}
    exec(compile(source, path, "exec"), namespace)  # noqa: S102 - the file under test
    return namespace


def matches(tool, text):
    """Drive the tool's own extract(), so the junk filter and the lowercased
    early-out are covered too -- not just the raw patterns."""
    return tool["extract"](text)


# ---* agent-sessions/bin/agent-panes-resurrect *---

STAMP = "2026-08-01 21:05"

CLAUDE_ROW = dict(
    agent="claude",
    pane="ai-labels:1.1",
    pane_id="%11",
    pid=761116,
    cwd="/home/junf/Documents/dotfiles",
    session_id="1a03df5b-6a91-49de-927c-6920a34539c2",
    name="cleanup-worktree-script",
    source="sessions",
    started="07-29 12:33",
    live=True,
)
CODEX_ROW = dict(
    agent="codex",
    pane="egoexo-hands:2.2",
    pane_id="%22",
    pid=1940427,
    cwd="/home/junf/tmp dir",
    session_id="019fb1f2-ce78-7af1-9dcc-886ddda58500",
    name="",
    source="meta~4s",
    started="07-30 03:35",
    live=True,
)
# The same session after its agent has gone, as the sidecar remembers it: no
# `live`, and a `last_seen` from the save that last saw it running.
EXITED_ROW = dict(CLAUDE_ROW, live=False, last_seen=1785600000.0)

# A real pane capture: colours left open by the agent's last redraw, invalid
# UTF-8, and a NUL -- all of which a naive text-mode strip destroys.
CAPTURE = (
    b"\x1b[38;5;246mrunning something\x1b[K\n"
    b"bad \xff\xfe utf8 and a \x00 nul\n"
    b"  [agent-session] quoted in a doc, indented\n"
    b"$ rg -n '[agent-session]' agent-sessions/\n"
)


def resurrect_cases(tool):
    """(label, ok) pairs for the marker rendering and stripping."""
    block = tool["marker_block"]([CLAUDE_ROW], STAMP)
    strip = tool["strip_markers"]
    text = block.decode()
    cases = []

    def add(label, ok):
        cases.append((label, bool(ok)))

    add("block renders one stanza", text.count("ran in this pane until") == 1)
    add("block carries the resume command", "claude --resume 1a03df5b-6a91-49de-927c-6920a34539c2" in text)
    add("cwd is shell-quoted into a cd", "cd '/home/junf/Documents/dotfiles' &&" in text)
    add("every line starts with a reset", all(l.startswith("\x1b[0m") for l in text.splitlines()))
    add("every line ends with a reset", all(l.endswith("\x1b[0m") for l in text.splitlines()))
    add("exact source is not flagged inferred", "inferred" not in text)

    codex = tool["marker_block"]([CODEX_ROW], STAMP).decode()
    add("codex uses its own resume verb", "codex resume 019fb1f2-ce78-7af1-9dcc-886ddda58500" in codex)
    add("inferred source is flagged", "id from meta~4s (inferred)" in codex)
    add("cwd with a space is quoted", "cd '/home/junf/tmp dir' &&" in codex)

    unknown = tool["marker_block"]([dict(CLAUDE_ROW, session_id=None)], STAMP).decode()
    add("unresolved id collapses to one line", len(unknown.splitlines()) == 1)

    # A pane holds one agent at a time but many over its life, and naming all of
    # them is the point: the record used to be capped at one per pane, so every
    # session the user had finished with lost its id.
    cap = tool["MAX_STANZAS"]
    several = tool["marker_block"](
        [dict(CLAUDE_ROW, started=f"08-0{i} 10:00", last_seen=float(i)) for i in range(1, 4)], STAMP
    ).decode()
    add("every session in a pane gets a stanza", several.count("ran in this pane until") == 3)
    add("the newest session is printed first", several.index("08-03 10:00") < several.index("08-01 10:00"))
    add("nothing is elided below the cap", "older session(s) here" not in several)

    # The cap is a stop against a pane in use for months growing an unbounded
    # block -- and the overflow has to be counted, or a truncated block reads
    # exactly like a complete one.
    over = tool["marker_block"](
        [dict(CLAUDE_ROW, started=f"08-{i:02d} 10:00", last_seen=float(i)) for i in range(1, cap + 3)],
        STAMP,
    ).decode()
    add("stanzas per pane are capped", over.count("ran in this pane until") == cap)
    add("the newest sessions survive the cap", f"08-{cap + 2:02d} 10:00" in over)
    add("the overflow is counted, not silently dropped", "and 2 older session(s) here" in over)
    add(
        "the overflow line carries the sentinel too",
        re.sub(r"\x1b\[[0-9;]*m", "", over.splitlines()[-1]).startswith("#[agent-session] "),
    )

    # A pane whose agent has exited is the case the feature exists for: Claude
    # draws on the alternate screen, so its id is recoverable from nothing else.
    gone = tool["marker_block"]([EXITED_ROW], STAMP).decode()
    add("an exited session is still rendered", "claude --resume 1a03df5b-6a91-49de-927c-6920a34539c2" in gone)
    add("an exited session is not claimed as current", "ran in this pane until tmux was saved" not in gone)
    add("an exited session says when it was last seen", "last seen 2026-08-01" in gone)
    add("an exited session is labelled exited", "· exited ·" in gone)
    add("a live session is labelled running", "still running at save" in text)

    # Every line is a shell comment: the block lands in a pane that is about to
    # hand control to an interactive shell, and the resume line exists to be
    # copied out of it.
    bare = [re.sub(r"\x1b\[[0-9;]*m", "", line) for line in gone.splitlines()]
    add("every rendered line is a shell comment", all(line.startswith("#") for line in bare))
    add("the resume line is labelled for copying", any(line.startswith("#[agent-session] resume: ") for line in bare))

    # A title an agent wrote is free text that ends up replayed into a terminal.
    nasty = dict(CLAUDE_ROW, name="t\x1b[6ni\x07t\x00l\x7fe")
    rendered = tool["marker_block"]([nasty], STAMP).decode()
    body = rendered.replace("\x1b[0m", "").replace("\x1b[90m", "").replace("\x1b[36m", "")
    add("control characters never reach the block", not any(c in body for c in "\x1b\x07\x00\x7f"))
    # The escape is what makes ESC[6n a device query; without it the leftover
    # `[6n` is inert text, and the rest of the title is still readable.
    add("the disarmed remains of the title are kept", "t[6nitle" in body)
    tame = tool["marker_block"]([dict(CLAUDE_ROW, name="ti\x1btl\x00e\x7f")], STAMP).decode()
    add("a title of only control noise sanitises to its text", "title" in tame)

    # A session id lands in a command the reader is invited to paste.
    evil = tool["marker_block"]([dict(CLAUDE_ROW, session_id="x; rm -rf ~")], STAMP).decode()
    add("a metacharacter-bearing id is quoted", "--resume 'x; rm -rf ~'" in evil)
    add("a plain uuid is left unquoted", "--resume 1a03df5b-6a91-49de-927c-6920a34539c2" in text)

    # A shortened path would emit a cd that silently lands somewhere else.
    deep = "/home/junf/" + "d" * 400
    add("a long cwd is not truncated", f"cd '{deep}' &&" in tool["marker_block"]([dict(CLAUDE_ROW, cwd=deep)], STAMP).decode())

    # agent-panes spells its inferred tiers with the tolerance it accepted.
    add("btime tier counts as inferred", "(inferred)" in tool["marker_block"]([dict(CLAUDE_ROW, source="btime~12s")], STAMP).decode())
    add("an unseen exact tier is not flagged", "(inferred)" not in tool["marker_block"]([dict(CLAUDE_ROW, source="registry")], STAMP).decode())

    add("render then strip is empty", strip(block) == b"")
    add("strip leaves a block-free capture byte-exact", strip(CAPTURE) == CAPTURE)
    add("strip removes an appended block", strip(CAPTURE + block) == CAPTURE)
    add("strip is idempotent", strip(strip(CAPTURE + block)) == strip(CAPTURE + block))

    # The only case that matters in practice: after a restore the block sits
    # mid-scrollback, with the shell prompt and whatever the user typed after it.
    midfile = CAPTURE + block + b"$ echo hi\nhi\n"
    add("strip removes a mid-file block", strip(midfile) == CAPTURE + b"$ echo hi\nhi\n")

    # tmux re-emits its own idea of the cell attributes rather than the bytes we
    # wrote, so the strip has to survive rewritten, merged and missing SGR.
    rewritten = b"".join(
        [
            b"\x1b[0;90m[agent-session]\x1b[0m rewritten and merged\n",
            b"\x1b[90m\x1b[39m[agent-session]\x1b[39m split differently\n",
            b"[agent-session] no sgr at all\n",
        ]
    )
    add("strip survives tmux-rewritten SGR", strip(CAPTURE + rewritten) == CAPTURE)

    add("an indented mention is not stripped", b"quoted in a doc" in strip(CAPTURE))
    add("a ripgrep hit is not stripped", b"rg -n" in strip(CAPTURE))

    # Blocks written before the sentinel gained its `#` are sitting in every
    # archive saved by the previous version. If the strip stopped recognising
    # them they would never be removed, and each reboot would replay them
    # alongside the new ones -- the exact stacking the strip exists to prevent.
    legacy = (
        b"[agent-session] \xe2\x94\x80 claude \xc2\xb7 old \xc2\xb7 ran in this pane\n"
        b"[agent-session]   cd '/tmp' && claude --resume old-id\n"
    )
    add("a pre-# block is still stripped", strip(CAPTURE + legacy) == CAPTURE)
    add("a pre-# block mixed with a new one goes too", strip(CAPTURE + legacy + block) == CAPTURE)
    add("an indented pre-# mention still survives", b"quoted in a doc" in strip(CAPTURE + legacy))

    # Placement is by %N, never by location: with renumber-windows on, a window
    # closing shifts every location after it between the plugin's capture and
    # this hook, and annotating by location moves a block onto another pane.
    SERVER = "/tmp/tmux-1000/default:7243:34779817"
    LIVE_KEY = ("%30", "claude", CLAUDE_ROW["session_id"])
    placed = tool["annotatable"](
        {
            "sess:1.0": [dict(EXITED_ROW, pane_id="%10", server=SERVER)],  # pane moved since
            "sess:2.0": [dict(EXITED_ROW, pane_id="%20", server=SERVER)],  # pane closed
            "sess:3.0": [dict(CLAUDE_ROW, pane_id="%30", server=SERVER)],  # agent still there
        },
        {"%10": "sess:9.9", "%30": "sess:3.0"},
        {LIVE_KEY},
        SERVER,
    )
    add("a record follows its pane to a new location", "sess:9.9" in placed)
    add("a record is not left on its stale location", "sess:1.0" not in placed)
    add("a record for a closed pane is dropped", "sess:2.0" not in placed)
    add("a live pane is still annotated", "sess:3.0" in placed)
    add("liveness is derived, not trusted from the record", placed["sess:9.9"][0]["live"] is False)
    add("a live pane id marks its record live", placed["sess:3.0"][0]["live"] is True)

    # A pane now carries every session it has held, and only one of them is
    # running. Marking them all live because the *pane* has an agent would date
    # every previous session to this save and print it as current.
    crowded = tool["annotatable"](
        {
            "sess:3.0": [
                dict(CLAUDE_ROW, pane_id="%30", server=SERVER),
                dict(CLAUDE_ROW, pane_id="%30", server=SERVER, session_id="older-one"),
            ]
        },
        {"%30": "sess:3.0"},
        {LIVE_KEY},
        SERVER,
    )["sess:3.0"]
    add("liveness is per session, not per pane", [r["live"] for r in crowded] == [True, False])

    # %N restarts at 0 with every tmux server, while the sidecar outlives the
    # server for KEEP_DAYS. Placing a pre-reboot record by its number alone puts
    # it on whichever restored pane inherited that number -- and since a pane is
    # only stripped when it is also annotated, the false claim becomes permanent.
    reboot = {"sess:1.0": [dict(EXITED_ROW, pane_id="%10", server="/tmp/tmux-1000/default:111:222")]}
    add(
        "a record from a previous server is never placed",
        tool["annotatable"](reboot, {"%10": "sess:1.0"}, set(), SERVER) == {},
    )
    add(
        "a record predating server stamping is never placed",
        tool["annotatable"](
            {"s:1.0": [dict(EXITED_ROW, pane_id="%10")]}, {"%10": "s:1.0"}, set(), SERVER
        )
        == {},
    )
    add(
        "nothing is placed when this server cannot be identified",
        tool["annotatable"](
            {"s:1.0": [dict(EXITED_ROW, pane_id="%10", server=SERVER)]}, {"%10": "s:1.0"}, set(), ""
        )
        == {},
    )
    add(
        "the sidecar stamps fresh records with the server",
        tool["merge_sidecar"]({}, {"p:0.0": [CLAUDE_ROW]}, 1.0, SERVER)["p:0.0"][0]["server"] == SERVER,
    )

    usable = tool["usable_pane_key"]
    add("plain pane key is usable", usable("hand-pipeline:7.1"))
    add("slash in the session name is refused", not usable("a/b:0.0"))
    add("quote in the session name is refused", not usable("has'quote:0.0"))
    add("colon in the session name is refused", not usable("has:colon:0.0"))
    add("a non-pane string is refused", not usable("../../etc/passwd"))

    merge, now = tool["merge_sidecar"], 1_800_000_000.0
    old = {
        "a:0.0": [dict(session_id="old", last_seen=now - 60)],
        "b:0.0": [dict(session_id="ancient", last_seen=now - 400 * 86400)],
    }
    merged = merge(old, {"c:0.0": [CLAUDE_ROW]}, now)
    add("a pane with no live agent keeps its record", merged["a:0.0"][0]["session_id"] == "old")
    add("an aged-out record is pruned", "b:0.0" not in merged)
    add("a live pane is recorded", merged["c:0.0"][0]["session_id"] == CLAUDE_ROW["session_id"])
    add("a live record is pinned to its process", merged["c:0.0"][0]["pid"] == 761116)
    # `list` prints these straight to a terminal, so they are cleaned on the way
    # in rather than trusting every future reader of the sidecar.
    dirty = merge({}, {"d:0.0": [dict(CLAUDE_ROW, name="a\x1b[6nb", cwd="/tmp/\x07x")]}, now)["d:0.0"][0]
    add("sidecar names are sanitised on the way in", "\x1b" not in dirty["name"])
    add("sidecar cwds are sanitised on the way in", "\x07" not in dirty["cwd"])
    add("a non-integer pid is dropped", merge({}, {"e:0.0": [dict(CLAUDE_ROW, pid="1;rm")]}, now)["e:0.0"][0]["pid"] is None)

    # The behaviour this whole change exists to reverse. Starting a new session
    # in a pane used to erase the previous one's id at the very next save, which
    # capped the file at one session per pane -- so every session the user had
    # finished with lost its id, silently, while they were still working.
    succession = merge(
        {"c:0.0": [dict(CLAUDE_ROW, pane_id="%11", session_id="finished-earlier", last_seen=now - 3600)]},
        {"c:0.0": [CLAUDE_ROW]},
        now,
    )["c:0.0"]
    ids = [r["session_id"] for r in succession]
    add("a new session does not erase the pane's previous one", "finished-earlier" in ids)
    add("both sessions are kept, not one", len(succession) == 2)
    add("the running session sorts first", ids[0] == CLAUDE_ROW["session_id"])

    # The same session arrives from up to three places in one save: the live
    # scan, its own exit banner in the capture, and the block written for it last
    # time. It must land in the file once.
    THREE = [
        dict(CLAUDE_ROW, source="scrollback", live=False, name="", cwd="", pid=None, started=""),
        dict(CLAUDE_ROW, source="sessions", live=False, pid=None, last_seen=now - 99),
        CLAUDE_ROW,
    ]
    once = merge({}, {"c:0.0": THREE}, now)["c:0.0"]
    add("one session seen three ways is recorded once", len(once) == 1)
    add("the better source wins the record", once[0]["source"] == "sessions")
    add("a field only the weaker row had is still kept", once[0]["cwd"] == CLAUDE_ROW["cwd"])
    add("the live sighting sets last seen", once[0]["last_seen"] == now)

    # An id recovered from text names a session that ran there, not a process
    # anybody watched. Dating it to this save would print history as current.
    recovered = merge({}, {"c:0.0": [dict(CLAUDE_ROW, source="scrollback", live=False, last_seen=None)]}, now)["c:0.0"][0]
    add("a recovered row is not dated to this save", recovered["last_seen"] is None)
    add("a recovered row is still recorded now", recovered["recorded"] == now)

    # Ageing is by `recorded`, the last save that found evidence -- not by when
    # the agent ran. A session from months ago is worth printing while its banner
    # is still in the scrollback, and stops being worth printing KEEP_DAYS after
    # the scrollback loses it.
    ancient_live = merge(
        {}, {"c:0.0": [dict(CLAUDE_ROW, live=False, last_seen=now - 400 * 86400)]}, now
    )
    add("an old session with fresh evidence is kept", "c:0.0" in ancient_live)
    stale_evidence = merge(
        {"c:0.0": [dict(CLAUDE_ROW, pane_id="%11", last_seen=now, recorded=now - 400 * 86400)]}, {}, now
    )
    add("a record whose evidence went stale ages out", "c:0.0" not in stale_evidence)
    # Files written before `recorded` existed date only from last_seen, and must
    # age out exactly as they would have -- not all at once, and not never.
    add(
        "a version 1 record ages from its last_seen",
        merge({"c:0.0": [dict(session_id="v1", last_seen=now - 400 * 86400)]}, {}, now) == {},
    )
    add(
        "a fresh version 1 record survives the upgrade",
        merge({"c:0.0": [dict(session_id="v1", last_seen=now - 60)]}, {}, now)["c:0.0"][0]["recorded"]
        == now - 60,
    )

    SERVER2 = "/tmp/tmux-1000/default:9999:1"
    # %N restarts at 0 with every tmux server, so a record from the previous
    # generation is unplaceable -- until the restored pane replays its own block
    # and the harvest sees that id on a pane id *this* server issued.
    carried = merge(
        {"c:0.0": [dict(CLAUDE_ROW, pane_id="%11", server="/tmp/tmux-1000/default:1:1", recorded=now - 60)]},
        {"c:0.0": [dict(CLAUDE_ROW, pane_id="%11", live=False, source="sessions")]},
        now,
        SERVER2,
    )["c:0.0"][0]
    add("re-observing a record restamps it with this server", carried["server"] == SERVER2)
    add("the carried record is still one record", len(merge(
        {"c:0.0": [dict(CLAUDE_ROW, pane_id="%11", server="/tmp/tmux-1000/default:1:1", recorded=now - 60)]},
        {"c:0.0": [dict(CLAUDE_ROW, pane_id="%11", live=False)]},
        now,
        SERVER2,
    )["c:0.0"]) == 1)

    # A pane that moved is written under its new location while the old key still
    # names the same %N, so a pane's sessions end up scattered across every
    # location it has ever occupied.
    moved = merge(
        {"old:1.0": [dict(CLAUDE_ROW, pane_id="%11", session_id="dupe", last_seen=now, server=SERVER2)]},
        {"new:2.0": [CLAUDE_ROW]},
        now,
        SERVER2,
        {"%11": "new:2.0"},
    )
    add("a moved pane leaves nothing behind at its old location", "old:1.0" not in moved)
    add("a moved pane's sessions are filed together", len(moved["new:2.0"]) == 2)
    add("the moved pane is recorded at its new location", moved["new:2.0"][0]["pane_id"] == "%11")
    add(
        "a record from another server is not re-filed by its number",
        "old:1.0"
        in merge(
            {"old:1.0": [dict(CLAUDE_ROW, pane_id="%11", session_id="dupe", last_seen=now, server="other")]},
            {},
            now,
            SERVER2,
            {"%11": "new:2.0"},
        ),
    )
    add(
        "an unrelated stale pane is still kept",
        "keep:3.0"
        in merge(
            {"keep:3.0": [dict(CLAUDE_ROW, pane_id="%99", last_seen=now)]}, {"new:2.0": [CLAUDE_ROW]}, now
        ),
    )

    cases.extend(harvest_cases(tool))
    return cases


# A genuine Codex exit banner, of the kind a pane really does keep in scrollback.
# Claude leaves one too: it draws on the alternate screen, so its conversation is
# gone, but on a graceful exit it leaves that screen and *then* writes its resume
# hint to the main one, where the capture keeps it. What neither leaves is a
# banner for a session that was killed or lost to a reboot -- which is why
# reading our own block back is the only way those ids survive a strip.
BANNER = b"To continue this session, run codex resume 019f85e8-b749-7101-9771-beee8b588342\n"
BANNER_UUID = "019f85e8-b749-7101-9771-beee8b588342"
# The uuid a stubbed title index resolves to, distinct from every other id here.
TITLE_UUID = "3fd0c1a7-2b44-4c19-9f6e-11d3a7e50c62"


def harvest_cases(tool):
    """The block read back as data, and the sessions a capture still remembers.

    This is the half that can rot silently and take data with it. A pane is
    stripped whenever it is annotated, so a parse that quietly stopped matching
    would delete the only record that ever existed of every Claude session that
    ran in that pane -- there is no second copy to fall back on.
    """
    block_of = tool["marker_block"]
    parse = lambda data: tool["parse_stanzas"](tool["split_capture"](data)[0])  # noqa: E731
    cases = []

    def add(label, ok):
        cases.append((label, bool(ok)))

    block = block_of([EXITED_ROW], STAMP)
    rows = parse(block)
    add("a rendered block parses back to one record", len(rows) == 1)
    row = rows[0] if rows else {}
    add("the session id round-trips", row.get("session_id") == EXITED_ROW["session_id"])
    add("the agent round-trips", row.get("agent") == "claude")
    add("the name round-trips", row.get("name") == EXITED_ROW["name"])
    add("the cwd round-trips", row.get("cwd") == EXITED_ROW["cwd"])
    # Kept rather than downgraded: this is the same observation travelling
    # forward on the pane's contents, not a weaker second-hand sighting of it.
    add("the source round-trips rather than degrading", row.get("source") == "sessions")
    add("the pid round-trips as an int", row.get("pid") == EXITED_ROW["pid"])
    add("the start time round-trips", row.get("started") == EXITED_ROW["started"])
    add(
        "the date round-trips to the minute",
        row.get("last_seen") is not None and abs(row["last_seen"] - EXITED_ROW["last_seen"]) < 60,
    )

    # Convergence. Every reboot re-renders whatever the last one wrote, so a
    # round trip that drifted would rewrite the block on every single save.
    add("an exited stanza survives a round trip byte-for-byte", block_of(rows, STAMP) == block)
    live_block = block_of([CLAUDE_ROW], STAMP)
    settled = block_of(parse(live_block), STAMP)
    add("a live stanza settles after one round trip", block_of(parse(settled), STAMP) == settled)
    add("a settled stanza no longer claims to be running", b"still running at save" not in settled)

    # Anything the harvest fails to read is about to be deleted by the strip, so
    # the two have to agree on exactly which lines are ours.
    mixed = CAPTURE + block + b"$ echo hi\nhi\n"
    marked, plain = tool["split_capture"](mixed)
    add(
        "the harvest reads exactly the lines the strip removes",
        len(marked) == len(mixed.splitlines()) - len(tool["strip_markers"](mixed).splitlines()),
    )
    add("our own block never reaches the genuine-text pass", EXITED_ROW["session_id"] not in plain)
    add("ordinary scrollback still reaches the genuine-text pass", "running something" in plain)
    # Not evidence about this pane either way, and off column 0 the strip would
    # never remove it -- so it must not reach the pattern pass, where its resume
    # line would be read at face value and re-seed itself on every save.
    add("a line mentioning the sentinel is evidence about nothing", "quoted in a doc" not in plain)
    add("a ripgrep hit for the sentinel likewise", "rg -n" not in plain)

    # Layered on purpose: only the resume line is required, so a wording change
    # in the head or the tail costs a name, never a session id.
    resume_only = b"".join(l + b"\n" for l in block.splitlines() if b"resume:" in l)
    bare = parse(resume_only)
    add("a stanza with no head or tail still yields its id", bare and bare[0]["session_id"] == EXITED_ROW["session_id"])
    add("... and still yields its cwd", bare and bare[0]["cwd"] == EXITED_ROW["cwd"])
    rotted = parse(block.replace(b"resume:", b"to resume, run"))
    add(
        "a renamed resume label still yields the id through the fallback",
        any(r["session_id"] == EXITED_ROW["session_id"] for r in rotted),
    )
    # Blocks written before the sentinel gained its `#`, and before `resume:`
    # existed, are sitting in every archive the previous version saved.
    legacy = (
        "[agent-session] ─ claude · old · ran in this pane\n"
        f"[agent-session]   cd '/tmp/old dir' && claude --resume {UUID}\n"
    ).encode()
    old_rows = parse(legacy)
    add("a pre-# block still yields its id", old_rows and old_rows[0]["session_id"] == UUID)
    add("a pre-# block still yields its cwd", old_rows and old_rows[0]["cwd"] == "/tmp/old dir")

    cap = tool["MAX_STANZAS"]
    over = block_of([dict(EXITED_ROW, started=f"08-{i:02d} 10:00") for i in range(1, cap + 3)], STAMP)
    add("the overflow line does not parse back as a session", len(parse(over)) == cap)

    # shell_quote may put ` && ` inside the quoted path, so the split cannot be a
    # regex: it would cut at the wrong one and emit a cd to somewhere else.
    split_cd = tool["split_cd"]
    add("a plain path splits off the command", split_cd("cd /tmp && claude -r x") == ("/tmp", "claude -r x"))
    add("a quoted path with a space survives", split_cd("cd '/home/junf/tmp dir' && codex resume x") == ("/home/junf/tmp dir", "codex resume x"))
    add("&& inside the path does not split it", split_cd("cd '/tmp/a && b' && codex resume x") == ("/tmp/a && b", "codex resume x"))
    add("an embedded quote is unescaped", split_cd(r"cd '/tmp/it'\''s' && codex resume x") == ("/tmp/it's", "codex resume x"))
    add("a line with no cd is left alone", split_cd("claude -r x") == ("", "claude -r x"))
    add("an unterminated quote is refused", split_cd("cd '/tmp && codex resume x") == ("", "cd '/tmp && codex resume x"))
    awkward = dict(EXITED_ROW, cwd="/tmp/it's && here", name="a · b")
    add("an awkward cwd and name still round-trip", block_of(parse(block_of([awkward], STAMP)), STAMP) == block_of([awkward], STAMP))

    # Placement, before anything is read out of a capture.
    add("the pane index inverts", tool["by_location"]({"%1": "a:0.0", "%2": "b:0.0"}) == {"a:0.0": "%1", "b:0.0": "%2"})
    add("a location two panes both claim is dropped", tool["by_location"]({"%1": "a:0.0", "%2": "a:0.0"}) == {})

    harvest = tool["harvest"]
    both = harvest({"s:1.0": CAPTURE + BANNER + block}, {"s:1.0": "%7"})
    add("a capture yields both a banner and our own block", len(both.get("s:1.0", [])) == 2)
    add("every harvested row is bound to the pane it came from", all(r["pane_id"] == "%7" for r in both.get("s:1.0", [])))
    add(
        "a banner is recorded as recovered, not as an observation",
        any(r["source"] == tool["SCROLLBACK_SOURCE"] for r in both.get("s:1.0", [])),
    )
    add("a capture for a pane this server does not have is skipped", harvest({"gone:9.9": BANNER}, {"s:1.0": "%7"}) == {})

    # The same id from the banner and from the block we wrote for it: one record,
    # and the block's -- which knows the cwd and the tier the id came from.
    codex_exited = dict(CODEX_ROW, live=False, last_seen=EXITED_ROW["last_seen"], session_id=BANNER_UUID)
    doubled = harvest({"s:1.0": BANNER + block_of([codex_exited], STAMP)}, {"s:1.0": "%7"}).get("s:1.0", [])
    add("one id in both the banner and our block is recorded once", len(doubled) == 1)
    add("the block's richer record wins over the bare banner", doubled and doubled[0]["source"] == "meta~4s")
    add("and keeps the cwd the banner never printed", doubled and doubled[0]["cwd"] == CODEX_ROW["cwd"])

    # A row recovered from text names a session that ran there, not a process
    # anyone watched -- so it must not print a pid it never had.
    recovered = tool["marker_block"](
        [dict(agent="codex", session_id=BANNER_UUID, cwd="/tmp", source=tool["SCROLLBACK_SOURCE"], live=False)],
        STAMP,
    ).decode()
    add("a recovered row prints no pid it never had", "pid" not in recovered)
    add("a recovered row is flagged as recovered", "id from scrollback (recovered)" in recovered)
    add("a recovered row still offers a resume command", f"codex resume {BANNER_UUID}" in recovered)
    # The suffix is a caveat about the source, not part of it. Round-tripping it
    # into the field would downgrade the record a tier on every reboot until the
    # string was truncated into something the merge could no longer rank.
    inferred = block_of([dict(CODEX_ROW, live=False, last_seen=EXITED_ROW["last_seen"])], STAMP)
    add("an inferred tier round-trips without its caveat", parse(inferred)[0]["source"] == "meta~4s")
    add("an inferred stanza converges", block_of(parse(inferred), STAMP) == inferred)

    # tmux re-emits its own idea of the cell attributes rather than the bytes we
    # wrote, so the parse has to survive rewritten, merged and missing SGR just
    # as the strip does -- and a parse that half-works keeps the id but loses the
    # cwd, which is the part `claude --resume` cannot do without.
    rewritten = b"\n".join(
        b"\x1b[0;90m" + tool["ANSI_RE"].sub(b"", line) for line in block.splitlines()
    ) + b"\n"
    reparsed = parse(rewritten)
    add("a re-coloured block still parses", len(reparsed) == 1)
    add("a re-coloured block keeps its cwd", reparsed and reparsed[0]["cwd"] == EXITED_ROW["cwd"])
    add("a re-coloured block keeps its source", reparsed and reparsed[0]["source"] == "sessions")

    # The block says which pane and which tmux server generation it belongs to,
    # so that reading it back can tell a pane's own history from text that merely
    # arrived there: a `--dry-run` preview printed into a pane, a stanza pasted
    # from another pane, a `cat` of somebody else's capture file.
    SERVER = "/tmp/tmux-1000/default:7243:34779817"
    tag = tool["server_tag"](SERVER)
    bound_row = dict(EXITED_ROW, server=SERVER)
    bound = block_of([bound_row], STAMP)
    at = lambda data, pane, t: tool["parse_stanzas"](tool["split_capture"](data)[0], pane, t)  # noqa: E731
    add("the block records the pane and server it belongs to", f"bound to %11@{tag}".encode() in bound)
    add("a stanza is read in the pane it was written for", len(at(bound, "%11", tag)) == 1)
    add("a stanza claiming another pane on this server is refused", at(bound, "%99", tag) == [])
    add("the refused stanza is not resurrected by the fallback", at(bound, "%99", tag) == [])
    # The two cases the carry-over depends on and cannot check: %N is reissued by
    # every new server, and blocks written before the field existed have none.
    add("a stanza from an older server generation is still read", len(at(bound, "%99", "deadbeef")) == 1)
    add("a stanza with no binding is read on trust", len(at(block, "%99", tag)) == 1)
    rebound = dict(at(bound, "%11", tag)[0], pane_id="%11", server=SERVER)
    add("a bound stanza converges once its record is rebound", block_of([rebound], STAMP) == bound)

    # A block that arrived as text rather than one this pane accumulated: an
    # indented paste, a `cat` of another pane's capture, a quoted example. Off
    # column 0 the strip will never remove it, so if it reached the genuine-text
    # pass its resume line would be filed against this pane and would re-seed
    # itself on every save for ever.
    indented = b"".join(b"  " + line + b"\n" for line in bound.splitlines())
    marked_i, plain_i = tool["split_capture"](indented)
    add("an indented block is not read as one of ours", marked_i == [])
    add("an indented block is not stripped either", tool["strip_markers"](indented) == indented)
    add("an indented block never reaches the genuine-text pass", EXITED_ROW["session_id"] not in plain_i)
    add("and so contributes no rows at all", tool["harvest"]({"s:1.0": indented}, {"s:1.0": "%7"}) == {})

    # The preview is printed at column 0 on purpose: there it is refused stanza
    # by stanza and stripped on the way past, instead of lodging permanently.
    preview = b"".join(
        block_of([dict(EXITED_ROW, pane_id=p, server=SERVER, session_id=f"{i}aaaaaaa-0000-4000-8000-000000000000")], STAMP)
        for i, p in enumerate(("%11", "%12", "%13"))
    )
    add(
        "a preview of other panes is refused in the pane it was run in",
        tool["harvest"]({"s:1.0": preview}, {"s:1.0": "%99"}, SERVER) == {},
    )
    add(
        "the pane's own stanza in that preview is still read",
        len(tool["harvest"]({"s:1.0": preview}, {"s:1.0": "%12"}, SERVER).get("s:1.0", [])) == 1,
    )

    # A block this hook wrote never holds more stanzas than it prints, so
    # anything past that arrived as text -- and the binding check cannot judge a
    # previous server generation, which is what a `cat` of the archive after a
    # restore looks like.
    flood_blocks = b"".join(
        block_of([dict(EXITED_ROW, session_id=f"{i:08x}-0000-4000-8000-000000000000")], STAMP)
        for i in range(tool["MAX_STANZAS"] + 25)
    )
    add(
        "unbound block stanzas are capped too",
        len(tool["harvest"]({"s:1.0": flood_blocks}, {"s:1.0": "%7"}, SERVER).get("s:1.0", []))
        == tool["MAX_STANZAS"],
    )

    # A `cat` of a session dump, or a ripgrep over a directory of handoff notes,
    # puts hundreds of resume commands into one pane, each indistinguishable from
    # an exit banner -- and the record is append-only.
    flood = b"".join(
        f"To continue this session, run codex resume 019f85e8-b749-7101-9771-{i:012d}\n".encode()
        for i in range(tool["MAX_HARVEST_PER_PANE"] + 20)
    )
    add(
        "genuine matches are capped per pane",
        len(tool["harvest"]({"s:1.0": flood}, {"s:1.0": "%7"}).get("s:1.0", []))
        == tool["MAX_HARVEST_PER_PANE"],
    )

    # Which stanzas the cap keeps is the whole question, because the ones it
    # drops are stripped out of the archive in the same save and a Claude id has
    # nowhere else to live. The block is rendered newest-first, so slicing the
    # file's tail keeps the oldest -- and a flood pasted in from another server
    # generation, which the binding check cannot judge, would evict the pane's
    # own records from its own block.
    mine = b"".join(
        block_of(
            [dict(EXITED_ROW, pane_id="%12", session_id=f"aaaa{i:04x}-0000-4000-8000-000000000000")],
            STAMP,
        )
        for i in range(2)
    )
    alien = b"".join(
        block_of(
            [dict(EXITED_ROW, pane_id="%77", session_id=f"bbbb{i:04x}-0000-4000-8000-000000000000")],
            STAMP,
        )
        for i in range(tool["MAX_STANZAS"] + 10)
    )
    survivors = {
        row["session_id"]
        for row in tool["harvest"]({"s:1.0": mine + alien}, {"s:1.0": "%12"}, SERVER).get("s:1.0", [])
    }
    add(
        "a flood of foreign stanzas cannot evict the pane's own",
        {"aaaa0000-0000-4000-8000-000000000000", "aaaa0001-0000-4000-8000-000000000000"} <= survivors,
    )
    add("and the cap still holds", len(survivors) == tool["MAX_STANZAS"])

    # Claude prints the session's custom title instead of its uuid when it has
    # one, so about a third of its exit banners carry no id at all. Resolving one
    # means reading Claude's own transcripts, which is why the index is stubbed
    # here: what is under test is the gating, not the sweep.
    builds = []

    def fake_index(unique=False, **_kwargs):
        builds.append(unique)
        return {"a-real-title": TITLE_UUID, "ambiguous": None}

    previous_index = tool["name_index"]
    try:
        tool["name_index"] = fake_index
        titled = b'\nResume this session with:\nclaude --resume "a-real-title"\n'
        rows = tool["harvest"]({"s:1.0": titled}, {"s:1.0": "%7"}, SERVER).get("s:1.0", [])
        add("a titled Claude banner is resolved to its uuid", len(rows) == 1 and rows[0]["session_id"] == TITLE_UUID)
        add("and keeps the title it was found by", rows and rows[0]["name"] == "a-real-title")
        add("the index is only ever asked for unambiguous titles", builds == [True])

        builds.clear()
        add(
            "a title that names no single session resolves to nothing",
            tool["harvest"]({"s:1.0": b'claude --resume "ambiguous"\n'}, {"s:1.0": "%7"}, SERVER) == {},
        )

        # The banner is Claude's output, not ours, so the strip never removes it
        # and it is re-read on every save for as long as it is in the pane's
        # history. Without a name-keyed gate the index would be rebuilt forever.
        builds.clear()
        add(
            "a title already recorded for the pane is not looked up again",
            tool["harvest"]({"s:1.0": titled}, {"s:1.0": "%7"}, SERVER, {"%7": {("claude", "a-real-title")}}) == {},
        )
        add("and the index is not built at all", builds == [])

        # One sweep per save, however many panes carry an unresolved title.
        builds.clear()
        many = {f"s:1.{i}": titled for i in range(5)}
        tool["harvest"](many, {loc: f"%{i}" for i, loc in enumerate(many)}, SERVER)
        add("the index is built at most once per save", len(builds) == 1)

        # A resolved uuid is nowhere in the capture -- the banner printed a title
        # -- so ordering the overflow by uuid position would sort it to the front
        # and make it the first thing discarded.
        builds.clear()
        crowd = flood + titled
        kept = {
            row["session_id"]
            for row in tool["harvest"]({"s:1.0": crowd}, {"s:1.0": "%7"}, SERVER).get("s:1.0", [])
        }
        add("a title resolved at the end of a flooded capture survives the cap", TITLE_UUID in kept)

        # A title that resolves to nothing is refused *permanently*. Claude
        # prunes transcripts at 30 days and a pane's scrollback does not, so a
        # lookup repeated later answers confidently where this one would not --
        # `rm` names 38 sessions today and would name one survivor eventually.
        refused = {}
        builds.clear()
        miss = b'claude --resume "ambiguous"\n'
        tool["harvest"]({"s:1.0": miss}, {"s:1.0": "%7"}, SERVER, None, refused)
        add("an unresolvable title is written down", "ambiguous" in refused)
        add("and the lookup was attempted once", len(builds) == 1)
        builds.clear()
        tool["harvest"]({"s:1.0": miss}, {"s:1.0": "%7"}, SERVER, None, refused)
        add("a refused title is never looked up again", builds == [])
        add(
            "and still resolves to nothing",
            tool["harvest"]({"s:1.0": miss}, {"s:1.0": "%7"}, SERVER, None, refused) == {},
        )
        # The refusal must outlive the generation that made it, so it cannot be
        # keyed on a pane or a server, and it must not age with the records.
        builds.clear()
        tool["harvest"]({"z:9.9": miss}, {"z:9.9": "%99"}, "another-server", None, refused)
        add("a refusal holds on a different pane and server", builds == [])
    finally:
        tool["name_index"] = previous_index

    # A block that reached one pane twice -- two --dry-run previews run there, a
    # `cat` of a capture that already held one -- used to put two rows per
    # session in front of the cap, so N duplicates evicted N distinct ids and
    # the strip then removed their only remaining evidence.
    six = b"".join(
        block_of(
            [dict(EXITED_ROW, pane_id="%12", session_id=f"cccc{i:04x}-0000-4000-8000-000000000000")],
            STAMP,
        )
        for i in range(tool["MAX_STANZAS"])
    )
    kept_ids = {
        row["session_id"]
        for row in tool["harvest"]({"s:1.0": six + six}, {"s:1.0": "%12"}, SERVER).get("s:1.0", [])
    }
    add("a doubled block still yields every distinct session", len(kept_ids) == tool["MAX_STANZAS"])

    # Refused titles ride in the sidecar document, not in a pane's records.
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "agent_sessions.json")
        tool["write_sidecar"](path, {"a:0.0": [dict(CLAUDE_ROW)]}, 1.0, {"rm": 123})
        add("refusals round-trip through the sidecar", tool["read_refused"](path) == {"rm": 123})
        add("and do not disturb the records", tool["read_sidecar"](path)["a:0.0"][0]["agent"] == "claude")
        add("it is still a sidecar", tool["sidecar_state"](path)[0] is True)
        tool["write_sidecar"](path, {}, 1.0)
        add("no refusals means no key at all", tool["read_refused"](path) == {})
    # The plugin's own state file names the pane list it filed the captures
    # under. If that has moved since, a location-named capture belongs to a
    # different pane now, and the record would be wrong permanently.
    with tempfile.TemporaryDirectory() as tmp:
        with open(os.path.join(tmp, "last"), "w") as fh:
            fh.write("pane\tai-labels\t1\t0\t:\t1\tzsh\t:/home\t1\tzsh\t:\n")
            fh.write("pane\tai-labels\t2\t0\t:\t3\tzsh\t:/home\t1\tzsh\t:\n")
            fh.write("window\tai-labels\t1\t:\t*\n")
        add(
            "the plugin's saved pane list is read back",
            tool["saved_locations"](tmp) == {"ai-labels:1.1", "ai-labels:2.3"},
        )
        add(
            "a vanished pane refuses the harvest",
            tool["recover"](tmp, {"%1": "ai-labels:9.9"}, "")[2].startswith("harvest skipped"),
        )
        # dump_panes skips grouped sessions while dump_pane_contents captures
        # them anyway, so the plugin's list is legitimately a subset of the live
        # one. An equality test there would disable the harvest for ever, and
        # silently, on any server with a grouped session.
        add(
            "a pane the plugin never listed does not refuse the harvest",
            tool["recover"](
                tmp, {"%1": "ai-labels:1.1", "%2": "ai-labels:2.3", "%3": "grouped:1.1"}, ""
            )[2]
            != "harvest skipped: 1 pane(s) moved since the capture",
        )
    add("a missing state file is not mistaken for an empty one", tool["saved_locations"]("/nonexistent") is None)

    # `claude --resume` resolves the id inside the project directory of the
    # current cwd, so a recovered row without a `cd` in front of it produces a
    # command that quietly fails wherever it is pasted. The banners do not print
    # it; the transcripts do, in two different shapes.
    cwd_of = tool["transcript_cwd"]
    with tempfile.TemporaryDirectory() as tmp:
        codex_roll = os.path.join(tmp, "codex.jsonl")
        with open(codex_roll, "w") as fh:
            fh.write('{"type":"session_meta","payload":{"id":"x","cwd":"/home/junf/proj"}}\n')
        add("a codex rollout's cwd is read from its header", cwd_of(codex_roll) == "/home/junf/proj")

        claude_tr = os.path.join(tmp, "claude.jsonl")
        with open(claude_tr, "w") as fh:
            fh.write('{"type":"mode"}\n{"type":"permission-mode"}\nnot json at all\n')
            fh.write('{"type":"bridge-session"}\n{"type":"user","cwd":"/home/junf/other"}\n')
        add("a claude transcript's cwd is found past its header records", cwd_of(claude_tr) == "/home/junf/other")

        empty = os.path.join(tmp, "none.jsonl")
        with open(empty, "w") as fh:
            fh.write('{"type":"mode"}\n' * 40)
        add("a transcript with no cwd yields nothing rather than guessing", cwd_of(empty) == "")
        add("a missing transcript is not an error", cwd_of(os.path.join(tmp, "gone.jsonl")) == "")
        deep = os.path.join(tmp, "deep.jsonl")
        with open(deep, "w") as fh:
            fh.write('{"type":"mode"}\n' * 50 + '{"cwd":"/too/late"}\n')
        add("the transcript read is bounded, not a full scan", cwd_of(deep) == "")

    cases.extend(archive_cases(tool))
    cases.extend(title_index_cases(tool))
    return cases


def title_index_cases(tool):
    """lib/claude_names.py, driven over a synthetic ~/.claude.

    It parses another program's private record format, which is the whole reason
    it sits in lib/ rather than in the one tool that used to own it. The strict
    index is the half that matters: what it returns is written into a pane as a
    runnable `--resume`, unattended, after a reboot.
    """
    cases = []

    def add(label, ok):
        cases.append((f"titles  {label}", ok))

    name_index = tool["name_index"]
    uid = "%s-0000-4000-8000-%012d"

    def record(kind, field, name, sid):
        return json.dumps({"type": kind, field: name, "sessionId": sid}) + "\n"

    with tempfile.TemporaryDirectory() as tmp:
        projects = os.path.join(tmp, "projects", "p")
        sessions = os.path.join(tmp, "sessions")
        os.makedirs(projects)
        os.makedirs(sessions)

        one, two, three = (uid % ("aaaaaaaa", 1), uid % ("bbbbbbbb", 2), uid % ("cccccccc", 3))
        with open(os.path.join(projects, f"{one}.jsonl"), "w") as fh:
            fh.write(record("custom-title", "customTitle", "solo", one))
        # The same title on two sessions: ambiguous, and the ambiguity is
        # perishable -- Claude prunes transcripts at 30 days -- so the strict
        # index must refuse rather than pick.
        for sid in (two, three):
            with open(os.path.join(projects, f"{sid}.jsonl"), "w") as fh:
                fh.write(record("custom-title", "customTitle", "shared", sid))
        with open(os.path.join(projects, "named.jsonl"), "w") as fh:
            fh.write(record("agent-name", "agentName", "by-agent-name", one))
        # A message that merely mentions the marker, and a rename record too
        # large to be one.
        with open(os.path.join(projects, "noise.jsonl"), "w") as fh:
            fh.write(json.dumps({"type": "user", "text": 'set "type":"custom-title" here'}) + "\n")
            fh.write(json.dumps({"type": "custom-title", "customTitle": "x" * 5000, "sessionId": one}) + "\n")
            fh.write("{ not json at all\n")
        with open(os.path.join(sessions, "4242.json"), "w") as fh:
            json.dump({"name": "from-the-registry", "sessionId": one}, fh)

        strict = name_index(unique=True, projects=os.path.join(tmp, "projects"), sessions=sessions)
        broad = name_index(unique=False, projects=os.path.join(tmp, "projects"), sessions=sessions)

        add("an unambiguous custom title resolves", strict.get("solo") == one)
        add("an ambiguous title resolves to nothing", "shared" not in strict)
        add("the broad index resolves it anyway", broad.get("shared") in (two, three))
        # `agent-name` is a different field from the one the banner prints, and
        # the registry `name` carries derived and AI titles that no banner can
        # produce. Either would be a wrong `--resume`.
        add("agent-name never reaches the strict index", "by-agent-name" not in strict)
        add("but does reach the broad one", broad.get("by-agent-name") == one)
        add("the live registry never reaches the strict index", "from-the-registry" not in strict)
        add("but does reach the broad one", broad.get("from-the-registry") == one)
        add("an oversized rename record is skipped", "x" * 5000 not in broad)
        add("a line that is not json is skipped", len(broad) == 4)
        add("prose mentioning the marker is not a rename", not any(t.startswith("set ") for t in broad))

        # A save hook must not raise out of here: recover()'s handler reads any
        # exception as "no harvest", which skips the injection for every pane.
        add("a missing tree is empty, not an error", name_index(projects=os.path.join(tmp, "nope"), sessions=os.path.join(tmp, "nope")) == {})
        with open(os.path.join(sessions, "bad.json"), "w") as fh:
            fh.write("{ not json")
        add("an unreadable registry file is skipped", name_index(unique=False, projects=os.path.join(tmp, "projects"), sessions=sessions).get("solo") == one)
        with open(os.path.join(projects, "badsid.jsonl"), "w") as fh:
            fh.write(record("custom-title", "customTitle", "not-a-uuid", "banana"))
        add("a non-uuid session id is refused", "not-a-uuid" not in name_index(unique=True, projects=os.path.join(tmp, "projects"), sessions=sessions))

    return cases


def resume_cases(tool):
    """agent-resume: the rule that decides whether a session may be started.

    Everything else in that tool reads something; this is the part that acts. It
    starts an agent with a `--dangerously-skip-permissions` / `--yolo` flag on it,
    in a directory it chose, from evidence that includes free text a pane merely
    happened to display -- so the interesting cases are all refusals.
    """
    cases = []

    def add(label, ok):
        cases.append((label, bool(ok)))

    def row(session_id, agent="codex", gone=False, **extra):
        return dict(agent=agent, session_id=session_id, gone=gone, **extra)

    live = row("019f85e8-b749-7101-9771-beee8b588342")
    other = row("019fb1f2-ce78-7af1-9dcc-886ddda58500")
    dead = row("019fc38b-75f6-7541-996a-8fb29cfc1375", gone=True)

    # The rule itself.
    add("one resumable candidate is chosen", tool["choose"]([live]) == (live, "one"))
    add("two resumable candidates refuse", tool["choose"]([live, other])[1] == "many")
    add("no candidates refuse", tool["choose"]([])[1] == "none")
    add("only unresumable candidates refuse", tool["choose"]([dead])[1] == "none")
    # A session Claude has already pruned cannot be resumed, so it must neither
    # win by being the last one left nor block the one that can.
    add("a gone candidate does not make a pane ambiguous", tool["choose"]([live, dead]) == (live, "one"))

    # What is allowed to be a candidate at all. Both agents name sessions by
    # uuid, so anything else came out of text that only looked like a resume line.
    add("a non-uuid id is not a candidate", tool["candidates"]([row("cleanup-worktree-script")]) == [])
    add("an unknown agent is not a candidate", tool["candidates"]([row(UUID, agent="aider")]) == [])
    add("an empty id is not a candidate", tool["candidates"]([row("")]) == [])
    add("a well-formed row is a candidate", len(tool["candidates"]([live])) == 1)

    # The commands, spelled out here as well as in the tool, so that changing
    # either one alone fails rather than silently resuming without the flag.
    add(
        "claude command",
        tool["argv_for"](dict(agent="claude", session_id=UUID))
        == ["claude", "--dangerously-skip-permissions", "--resume", UUID],
    )
    add(
        "codex command",
        tool["argv_for"](dict(agent="codex", session_id=CODEX_UUID))
        == ["codex", "resume", CODEX_UUID, "--yolo"],
    )

    # The cd is what `claude --resume` needs and no exit banner prints; the
    # quoting is what keeps a directory with a space in it from becoming two
    # arguments when the line is copied out of the pane and pasted.
    quoted = tool["command_line"](dict(agent="codex", session_id=CODEX_UUID, cwd="/home/junf/tmp dir"))
    add("cwd is prefixed as a cd", quoted.startswith("cd '/home/junf/tmp dir' && "))
    add("no cwd means no cd", not tool["command_line"](dict(agent="codex", session_id=CODEX_UUID, cwd="")).startswith("cd "))

    # tmux answers ESC[3J by dropping the pane's history, and for a session that
    # started and exited between two saves that history is the only record there
    # is. The clear must not reach it.
    add("the clear leaves scrollback alone", "\x1b[3J" not in tool["CLEAR"] and "\x1b[2J" in tool["CLEAR"])

    # No argument may name a session: anything that selects one is a way to start
    # a session the tool could not map by itself.
    add("a bare number is not an argument", tool["parse_args"](["1"])[1] != "")
    add("--pane normalises to %N", tool["parse_args"](["--pane", "7"])[0]["pane"] == "%7")
    add("--pane keeps an explicit %N", tool["parse_args"](["--pane=%13"])[0]["pane"] == "%13")
    add("an unknown flag is refused", tool["parse_args"](["--resume-anyway"])[1] != "")

    # The same session arrives from several sources; the merge has to keep the
    # best-attested version of each field rather than whichever arrived first.
    merged = tool["merge"](
        [
            dict(agent="codex", session_id=CODEX_UUID, source="scrollback", cwd="", name="", last_seen=None, origin="scrollback"),
            dict(agent="codex", session_id=CODEX_UUID, source="cmdline", cwd="/repo", name="build", last_seen=100.0, origin="sidecar"),
        ]
    )
    add("one row per session across sources", len(merged) == 1)
    add("the merge keeps the better source", merged[0]["source"] == "cmdline")
    add("the merge keeps the cwd", merged[0]["cwd"] == "/repo")
    add("the merge keeps the date", merged[0]["last_seen"] == 100.0)
    add("the merge records both origins", merged[0]["origins"] == {"scrollback", "sidecar"})

    # The hook cache is keyed by pane number with no server stamp, so a record
    # written before a reboot would otherwise be read against whichever restored
    # pane inherited that number.
    with tempfile.TemporaryDirectory() as tmp:
        register = tool["REGISTER"]
        previous = register.REG
        register.REG = tmp
        try:
            record = dict(
                agent="claude", pane_id="%3", session_id=UUID, name="", cwd="/repo",
                pid=1, proc_start=2, updated=1000.0,
            )
            with open(os.path.join(tmp, "3.json"), "w") as fh:
                json.dump(record, fh)
            add("a cache record from this server is read", len(tool["cache_row"]("%3", 900.0)) == 1)
            add("one predating the server is dropped", tool["cache_row"]("%3", 1100.0) == [])
            add("no server start time means no cache source", tool["cache_row"]("%3", None) == [])
            add("a record naming another pane is dropped", tool["cache_row"]("%4", 900.0) == [])
            with open(os.path.join(tmp, "3.json"), "w") as fh:
                json.dump(dict(record, session_id=""), fh)
            add("a record with no session id is dropped", tool["cache_row"]("%3", 900.0) == [])
        finally:
            register.REG = previous

    return cases


def archive_cases(tool):
    """inject() and the guards that decide whether it may run at all.

    inject() is the only thing here that destroys anything: it strips a pane's
    block before appending the new one, and for a Claude session that block is
    the only place its id was ever written. Everything below is about the
    conditions under which that strip is allowed to happen.
    """
    import gzip
    import io
    import tarfile

    cases = []

    def add(label, ok):
        cases.append((label, bool(ok)))

    def build(tmp, contents):
        """A resurrect dir holding an archive shaped like tmux-resurrect's."""
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode="w") as tar:
            root = tarfile.TarInfo("./pane_contents")
            root.type = tarfile.DIRTYPE
            root.mode = 0o755
            tar.addfile(root)
            for loc, data in contents.items():
                info = tarfile.TarInfo(f"./pane_contents/pane-{loc}")
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
        with open(os.path.join(tmp, "pane_contents.tar.gz"), "wb") as fh:
            fh.write(gzip.compress(buf.getvalue()))

    def pane_of(tmp, loc):
        raw = gzip.decompress(open(os.path.join(tmp, "pane_contents.tar.gz"), "rb").read())
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as tar:
            for member in tar.getmembers():
                if os.path.basename(member.name) == f"pane-{loc}":
                    return tar.extractfile(member).read()
        return None

    old_block = tool["marker_block"]([EXITED_ROW], STAMP)
    new_block = tool["marker_block"]([dict(EXITED_ROW, session_id="second-session")], STAMP)

    with tempfile.TemporaryDirectory() as tmp:
        # server_alive() reads $TMUX and refuses to publish without a live
        # server; an unparseable pid makes it fall back rather than refuse, which
        # is what lets inject() be exercised at all outside tmux.
        previous = os.environ.get("TMUX")
        os.environ["TMUX"] = f"{tmp},x"
        try:
            build(tmp, {"a:1.1": CAPTURE + old_block, "b:2.2": CAPTURE})
            captures, identity, why = tool["archive_captures"](tmp)
            add("the archive is read without unpacking it", why == "" and len(captures) == 2)
            add("a capture comes back byte-exact", captures["a:1.1"] == CAPTURE + old_block)

            written, reason = tool["inject"](tmp, {"a:1.1": new_block}, harvested_from=identity)
            add("injecting rewrites the pane it was given", written == 1)
            after = pane_of(tmp, "a:1.1")
            add("the old block is gone", old_block not in after)
            add("the new block is there", after.endswith(new_block))
            add("the pane's own scrollback is untouched", after.startswith(CAPTURE))
            add("an unlisted pane is left alone", pane_of(tmp, "b:2.2") == CAPTURE)

            # The identity is the whole point: rewriting an archive the harvest
            # never read would strip blocks nobody had a chance to record.
            stale = tool["inject"](tmp, {"a:1.1": new_block}, harvested_from=identity)
            add("a rewrite refuses an archive that changed since the harvest", stale == (0, "archive changed since the harvest"))
            add("and the refused rewrite left the archive alone", pane_of(tmp, "a:1.1") == after)

            build(tmp, {"a:1.1": CAPTURE + old_block})
            with open(os.path.join(tmp, "pane_contents.tar.gz"), "r+b") as fh:
                fh.truncate(64)
            captures, _, why = tool["archive_captures"](tmp)
            add("a truncated archive is refused, not half-read", captures == {} and why != "")
            add("the refusal reaches the caller as a reason", "archive" in why)
        finally:
            if previous is None:
                os.environ.pop("TMUX", None)
            else:
                os.environ["TMUX"] = previous

    # A save that cannot publish its record must not go on to strip the blocks
    # that record was read out of.
    with tempfile.TemporaryDirectory() as tmp:
        target = os.path.join(tmp, "nested", "agent_sessions.json")
        add("write_sidecar reports a failure rather than swallowing it", tool["write_sidecar"](target, {}, 1.0) is False)
        good = os.path.join(tmp, "agent_sessions.json")
        add("write_sidecar reports success", tool["write_sidecar"](good, {"a:0.0": [dict(CLAUDE_ROW)]}, 1.0) is True)
        add("what it wrote reads back", tool["read_sidecar"](good)["a:0.0"][0]["session_id"] == CLAUDE_ROW["session_id"])

        # The merge cannot tell "no file yet" from "this file is damaged", and
        # both look like an empty record to it -- which would then publish over
        # the damaged one and take every id in it along.
        with open(good, "w") as fh:
            fh.write("{ this is not json")
        tool["preserve_unreadable_sidecar"](good, tmp)
        kept = os.path.join(tmp, tool["UNREADABLE_PREFIX"])
        add("an unreadable sidecar is moved aside, not overwritten", os.path.exists(kept))
        add("and is gone from the path about to be written", not os.path.exists(good))

        # A second damage event must not delete what the first one preserved.
        with open(good, "w") as fh:
            fh.write("{ damaged again")
        tool["preserve_unreadable_sidecar"](good, tmp)
        others = [n for n in os.listdir(tmp) if n.startswith(tool["UNREADABLE_PREFIX"])]
        add("a second damaged sidecar does not overwrite the first", len(others) == 2)

        # The one file in this namespace that is evidence rather than a leftover.
        # Swept, the promise to keep it lasts an hour.
        os.utime(kept, (1.0, 1.0))
        tool["sweep_scratch"](tmp, time.time())
        add("the kept sidecar survives the scratch sweep", os.path.exists(kept))
        stale = os.path.join(tmp, tool["SIDECAR_NAME"] + ".tmp-leftover")
        with open(stale, "w") as fh:
            fh.write("x")
        os.utime(stale, (1.0, 1.0))
        tool["sweep_scratch"](tmp, time.time())
        add("an ordinary stale leftover is still swept", not os.path.exists(stale))

        # `purge` is the only thing that removes the kept file, so an uninstall
        # that skipped it would leave a file full of session ids behind.
        add(
            "purge names the kept sidecar",
            any(
                name.startswith(tool["UNREADABLE_PREFIX"])
                for name in os.listdir(tmp)
            ),
        )

        # A well-formed sidecar holding nothing is what a machine with no agent
        # panes writes. Diagnosed as damage it was renamed aside on every save,
        # overwriting whatever genuinely preserved file was already there.
        os.remove(kept)
        empty = os.path.join(tmp, "agent_sessions.json")
        tool["write_sidecar"](empty, {}, 1.0)
        tool["preserve_unreadable_sidecar"](empty, tmp)
        add("an empty but valid sidecar is left in place", os.path.exists(empty))
        add("and nothing is kept aside for it", not os.path.exists(kept))
        add("it still reads back as empty", tool["read_sidecar"](empty) == {})
        add("and is classified as a sidecar", tool["sidecar_state"](empty)[0] is True)
        for bad in ('{"panes": []}', "[]", "null"):
            with open(empty, "w") as fh:
                fh.write(bad)
            add(f"{bad} is not a sidecar", tool["sidecar_state"](empty)[0] is False)

    # Env parsing happens at import, where raising would kill the hook before
    # main()'s handler exists. Zero and negative are destructive here, not clever.
    previous = os.environ.get("AGENT_SESSIONS_MAX_STANZAS")
    try:
        for value, expected in (("3", 3), ("0", 1), ("-5", 1), ("banana", 6), ("", 6), ("1e3", 6)):
            os.environ["AGENT_SESSIONS_MAX_STANZAS"] = value
            add(f"AGENT_SESSIONS_MAX_STANZAS={value!r} yields {expected}", tool["_max_stanzas"]() == expected)
        os.environ.pop("AGENT_SESSIONS_MAX_STANZAS", None)
        add("the documented default is 6", tool["_max_stanzas"]() == 6)
    finally:
        if previous is None:
            os.environ.pop("AGENT_SESSIONS_MAX_STANZAS", None)
        else:
            os.environ["AGENT_SESSIONS_MAX_STANZAS"] = previous
    return cases


def main():
    tool = load_tool()
    failures = 0

    for label, text, expected in SHOULD_MATCH:
        found = matches(tool, text)
        if expected in found:
            print(f"PASS  match   {label}")
        else:
            failures += 1
            print(f"FAIL  match   {label}\n      expected {expected}\n      found    {found}")

    for label, text in SHOULD_REJECT:
        found = matches(tool, text)
        if not found:
            print(f"PASS  reject  {label}")
        else:
            failures += 1
            print(f"FAIL  reject  {label}\n      found    {found}")

    marker_total = len(SHOULD_MATCH) + len(SHOULD_REJECT)
    print(f"\n{marker_total - failures}/{marker_total} resume-marker cases passed\n")

    # The tool reads NO_COLOR and AGENT_SESSIONS_KEEP_DAYS at import, and the
    # cases below assert on the SGR it emits and on which sidecar records
    # survive a merge. Neither may be decided by the ambient environment: a
    # shell exporting KEEP_DAYS=0 prunes every stale record on the spot, which
    # is correct behaviour and a failing test.
    os.environ.pop("NO_COLOR", None)
    os.environ["AGENT_SESSIONS_KEEP_DAYS"] = "30"
    os.environ["AGENT_SESSIONS_MAX_STANZAS"] = "6"
    cases = resurrect_cases(load_tool(RESURRECT_TOOL))
    os.environ["NO_COLOR"] = "1"
    try:
        plain = load_tool(RESURRECT_TOOL)["marker_block"]([CLAUDE_ROW], STAMP).decode()
    finally:
        os.environ.pop("NO_COLOR", None)
    cases.append(("NO_COLOR emits no escapes", "\x1b" not in plain))
    cases.append(("NO_COLOR keeps the sentinel", plain.startswith("#[agent-session] ")))
    marker_failures = failures
    for label, ok in cases:
        if ok:
            print(f"PASS  marker  {label}")
        else:
            failures += 1
            print(f"FAIL  marker  {label}")

    passed = len(cases) - (failures - marker_failures)
    print(f"\n{passed}/{len(cases)} resurrect marker cases passed\n")

    resume = resume_cases(load_tool(RESUME_TOOL))
    resume_failures = failures
    for label, ok in resume:
        if ok:
            print(f"PASS  resume  {label}")
        else:
            failures += 1
            print(f"FAIL  resume  {label}")

    passed = len(resume) - (failures - resume_failures)
    print(f"\n{passed}/{len(resume)} agent-resume cases passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
