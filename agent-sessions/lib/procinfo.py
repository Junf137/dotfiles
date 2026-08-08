#!/usr/bin/env python3

# __author__ == Junfeng Lei

"""Process introspection, on the two kernels this repo runs on.

Every fact the agent-sessions tools need about a live process -- who its parent
is, when it started, what it was exec'd from, what it holds open, and above all
the TMUX_PANE in its environment -- comes from /proc on Linux. macOS has no
/proc, so this module puts one small platform-neutral surface in front of both
and lets the callers stay written the way they were.

The Linux backend is a verbatim lift of the /proc reads the tools already did,
so nothing about that kernel's behaviour changes by routing through here.

The Darwin backend uses three interfaces, all of which work for the calling
user's own processes with no privileges and no shelling out:

    sysctl kern.boottime            boot wall-clock, replacing /proc/uptime
    sysctl KERN_PROCARGS2 <pid>     exec path, argv and environ in one read,
                                    replacing /proc/<pid>/{cmdline,environ}
    libproc proc_listpids           the pid table, replacing os.listdir("/proc")
    libproc PROC_PIDTBSDINFO        ppid, comm and start time, replacing the
                                    parts of /proc/<pid>/stat that are read
    libproc proc_pidpath            replacing /proc/<pid>/exe
    libproc PROC_PIDVNODEPATHINFO   replacing /proc/<pid>/cwd
    libproc PROC_PIDLISTFDS         replacing /proc/<pid>/fd/

A process belonging to another user is unreadable on both kernels -- /proc hides
environ and cwd, and libproc refuses outright -- and both backends report that
the same way, as an empty or None result rather than an exception.

Start times are compared, never displayed, so the two kernels are free to
disagree on units: `start_token` returns whatever value distinguishes a pid from
a later reuse of the same pid, as an opaque string. Linux returns field 22 of
/proc/<pid>/stat in clock ticks since boot; Darwin returns whole epoch seconds.
Only ever compare a token against another token from this same machine.

The one place a start time crosses a process boundary is Claude's own live
registry, ~/.claude/sessions/<pid>.json, whose `procStart` field Claude writes
in a different format per kernel -- clock ticks on Linux, a UTC date string on
macOS. `claude_proc_start_matches` owns that difference so callers do not have
to know it exists.
"""

import os
import sys
import time

IS_DARWIN = sys.platform == "darwin"


# ---* Linux: /proc *---


if not IS_DARWIN:

    HZ = os.sysconf("SC_CLK_TCK")

    def boot_time():
        """Wall-clock time the kernel booted, in epoch seconds."""
        with open("/proc/uptime") as fh:
            return time.time() - float(fh.read().split()[0])

    def _stat_fields(pid):
        """/proc/<pid>/stat from ppid onward, with comm safely stripped.

        comm is parenthesised and may itself contain spaces and parentheses, so
        the line cannot be split on whitespace naively.
        """
        with open(f"/proc/{pid}/stat") as fh:
            st = fh.read()
        return st[st.index("(") + 1 : st.rindex(")")], st[st.rindex(")") + 2 :].split()

    def ppid(pid):
        try:
            return int(_stat_fields(pid)[1][1])
        except (OSError, IndexError, ValueError):
            return None

    def comm(pid):
        try:
            return _stat_fields(pid)[0]
        except (OSError, IndexError, ValueError):
            return ""

    def start_token(pid):
        try:
            return str(_stat_fields(pid)[1][19])
        except (OSError, IndexError, ValueError):
            return None

    def start_epoch(pid, boot=None):
        try:
            ticks = int(_stat_fields(pid)[1][19])
        except (OSError, IndexError, ValueError):
            return None
        return (boot if boot is not None else boot_time()) + ticks / HZ

    def environ(pid):
        try:
            with open(f"/proc/{pid}/environ") as fh:
                return dict(kv.split("=", 1) for kv in fh.read().split("\0") if "=" in kv)
        except OSError:
            return {}

    def cmdline(pid):
        try:
            with open(f"/proc/{pid}/cmdline") as fh:
                return fh.read().split("\0")
        except OSError:
            return []

    def exe(pid):
        try:
            return os.readlink(f"/proc/{pid}/exe")
        except OSError:
            return ""

    def cwd(pid):
        try:
            return os.readlink(f"/proc/{pid}/cwd")
        except OSError:
            return None

    def open_files(pid):
        out = []
        try:
            for fd in os.listdir(f"/proc/{pid}/fd"):
                try:
                    out.append(os.readlink(f"/proc/{pid}/fd/{fd}"))
                except OSError:
                    continue
        except OSError:
            pass
        return out

    def pids():
        return [int(e) for e in os.listdir("/proc") if e.isdigit()]

    def claude_proc_start_matches(pid, value):
        """Whether Claude's recorded procStart still describes this live pid.

        On Linux Claude records field 22 verbatim, so this is string equality.
        """
        if value is None:
            return False
        token = start_token(pid)
        return token is not None and str(value) == token


# ---* macOS: libproc + sysctl *---


else:

    import calendar
    import ctypes
    import struct

    _libc = ctypes.CDLL("/usr/lib/libSystem.dylib")

    # proc_pidinfo's third parameter is a uint64_t. Left to ctypes' default
    # int conversion it is passed in a 32-bit register and the flavors that
    # actually use it (a file descriptor) read garbage in the top half.
    _libc.proc_pidinfo.argtypes = [
        ctypes.c_int, ctypes.c_int, ctypes.c_uint64, ctypes.c_void_p, ctypes.c_int
    ]
    _libc.proc_pidinfo.restype = ctypes.c_int
    _libc.proc_pidfdinfo.argtypes = [
        ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_int
    ]
    _libc.proc_pidfdinfo.restype = ctypes.c_int
    _libc.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
    _libc.proc_pidpath.restype = ctypes.c_int
    _libc.proc_listpids.argtypes = [ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_int]
    _libc.proc_listpids.restype = ctypes.c_int

    PROC_ALL_PIDS = 1
    PROC_PIDLISTFDS = 1
    PROC_PIDTBSDINFO = 3
    PROC_PIDVNODEPATHINFO = 9
    PROC_PIDFDVNODEPATHINFO = 2
    PROX_FDTYPE_VNODE = 1

    MAXPATHLEN = 1024
    PATHINFO_MAX = 4096
    # Sizes and offsets below are of structs in <sys/proc_info.h>.
    BSDINFO_SIZE = 136                      # sizeof(struct proc_bsdinfo)
    VNODEPATHINFO_SIZE = 2 * (152 + MAXPATHLEN)   # sizeof(struct proc_vnodepathinfo)
    FDVNODEPATHINFO_SIZE = 24 + 152 + MAXPATHLEN  # sizeof(struct vnode_fdinfowithpath)
    # A vnode_info_path is a 152-byte vnode_info followed by the path; in the fd
    # flavor it sits behind a 24-byte proc_fileinfo.
    VIP_PATH_OFF = 152
    FD_VIP_PATH_OFF = 24 + 152

    CTL_KERN, KERN_BOOTTIME, KERN_PROCARGS2, KERN_ARGMAX = 1, 21, 49, 8

    def _sysctl(mib_values, size):
        mib = (ctypes.c_int * len(mib_values))(*mib_values)
        length = ctypes.c_size_t(size)
        buf = ctypes.create_string_buffer(size)
        if _libc.sysctl(mib, len(mib_values), buf, ctypes.byref(length), None, 0) != 0:
            return None
        return buf.raw[: length.value]

    def boot_time():
        """Wall-clock time the kernel booted, from `sysctl kern.boottime`."""
        raw = _sysctl([CTL_KERN, KERN_BOOTTIME], 16)      # struct timeval
        if not raw or len(raw) < 8:
            return time.time()
        return float(struct.unpack_from("q", raw, 0)[0])

    def _bsdinfo(pid):
        """(ppid, comm, start epoch seconds) from PROC_PIDTBSDINFO, or None.

        Returns None for a process that has exited or belongs to another user;
        libproc refuses both, matching what /proc does by hiding the fields.
        """
        buf = ctypes.create_string_buffer(BSDINFO_SIZE)
        if _libc.proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, buf, BSDINFO_SIZE) != BSDINFO_SIZE:
            return None
        raw = buf.raw
        return (
            struct.unpack_from("I", raw, 16)[0],                     # pbi_ppid
            raw[48:64].split(b"\0")[0].decode("utf-8", "replace"),   # pbi_comm
            struct.unpack_from("Q", raw, 120)[0],                    # pbi_start_tvsec
        )

    def ppid(pid):
        info = _bsdinfo(pid)
        return info[0] if info else None

    def comm(pid):
        info = _bsdinfo(pid)
        return info[1] if info else ""

    def start_token(pid):
        info = _bsdinfo(pid)
        return str(info[2]) if info else None

    def start_epoch(pid, boot=None):
        """Wall-clock start time of a process, in epoch seconds.

        `boot` is accepted for signature parity with the Linux backend and
        ignored: this kernel reports an absolute epoch already.
        """
        info = _bsdinfo(pid)
        return float(info[2]) if info else None

    def _procargs(pid):
        """(exec_path, argv, environ) from KERN_PROCARGS2 in one read.

        The blob is an int32 argc, the exec path, a run of NUL padding, then
        argc NUL-terminated argv strings, then the environment to the end.
        """
        raw = _sysctl([CTL_KERN, KERN_ARGMAX], 4)
        argmax = struct.unpack_from("i", raw, 0)[0] if raw and len(raw) >= 4 else 262144
        data = _sysctl([CTL_KERN, KERN_PROCARGS2, pid], argmax)
        if not data or len(data) < 4:
            return "", [], {}
        argc = struct.unpack_from("i", data, 0)[0]
        rest = data[4:]

        end = rest.find(b"\0")
        if end < 0:
            return "", [], {}
        path = rest[:end].decode("utf-8", "replace")
        while end < len(rest) and rest[end] == 0:      # alignment padding
            end += 1

        parts = rest[end:].split(b"\0")
        argv = [p.decode("utf-8", "replace") for p in parts[: max(argc, 0)]]
        env = {}
        for part in parts[max(argc, 0) :]:
            if b"=" in part:
                key, _, val = part.partition(b"=")
                env[key.decode("utf-8", "replace")] = val.decode("utf-8", "replace")
        return path, argv, env

    def environ(pid):
        return _procargs(pid)[2]

    def cmdline(pid):
        return _procargs(pid)[1]

    def exe(pid):
        buf = ctypes.create_string_buffer(PATHINFO_MAX)
        if _libc.proc_pidpath(pid, buf, PATHINFO_MAX) <= 0:
            return ""
        return buf.value.decode("utf-8", "replace")

    def cwd(pid):
        buf = ctypes.create_string_buffer(VNODEPATHINFO_SIZE)
        if _libc.proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, buf, VNODEPATHINFO_SIZE) <= 0:
            return None
        path = buf.raw[VIP_PATH_OFF : VIP_PATH_OFF + MAXPATHLEN].split(b"\0")[0]
        return path.decode("utf-8", "replace") or None

    def open_files(pid):
        size = _libc.proc_pidinfo(pid, PROC_PIDLISTFDS, 0, None, 0)
        if size <= 0:
            return []
        buf = ctypes.create_string_buffer(size + 4096)
        got = _libc.proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buf, len(buf))
        out = []
        for off in range(0, max(got, 0) - 7, 8):       # struct proc_fdinfo
            fd, fdtype = struct.unpack_from("iI", buf.raw, off)
            if fdtype != PROX_FDTYPE_VNODE:
                continue
            fb = ctypes.create_string_buffer(FDVNODEPATHINFO_SIZE)
            if _libc.proc_pidfdinfo(pid, fd, PROC_PIDFDVNODEPATHINFO, fb, FDVNODEPATHINFO_SIZE) <= 0:
                continue
            path = fb.raw[FD_VIP_PATH_OFF : FD_VIP_PATH_OFF + MAXPATHLEN].split(b"\0")[0]
            if path:
                out.append(path.decode("utf-8", "replace"))
        return out

    def pids():
        size = _libc.proc_listpids(PROC_ALL_PIDS, 0, None, 0)
        if size <= 0:
            return []
        buf = (ctypes.c_int * (size // 4 + 256))()
        got = _libc.proc_listpids(PROC_ALL_PIDS, 0, buf, ctypes.sizeof(buf))
        return [p for p in buf[: max(got, 0) // 4] if p > 0]

    # Claude renders procStart on macOS as strftime("%a %b %e %H:%M:%S %Y") in
    # UTC -- e.g. "Fri Aug  7 01:25:44 2026", with %e's leading space kept. It
    # is the same second as PROC_PIDTBSDINFO's pbi_start_tvsec.
    _CLAUDE_PROC_START = "%a %b %d %H:%M:%S %Y"

    def claude_proc_start_matches(pid, value):
        """Whether Claude's recorded procStart still describes this live pid.

        Compared as a parsed instant rather than as text, so a change in how
        Claude pads the day of month cannot silently turn this guard off -- and
        a guard that stops matching would drop the exact tier, not loosen it.
        Both a UTC and a local reading are accepted: only the former has ever
        been observed, but a wrong timezone would fail closed and cost the tier.
        """
        if not value:
            return False
        info = _bsdinfo(pid)
        if not info:
            return False
        try:
            parsed = time.strptime(str(value).strip(), _CLAUDE_PROC_START)
        except ValueError:
            return False
        started = info[2]
        # Each reading is guarded: time.mktime raises OverflowError outside
        # roughly 1901-2038, and a garbage procStart must fail closed here
        # rather than as a traceback out of the caller.
        for reading in (calendar.timegm, time.mktime):
            try:
                if abs(reading(parsed) - started) <= 1:
                    return True
            except (ValueError, OverflowError):
                continue
        return False


# ---* Shared *---


def process_table():
    """(children by ppid, comm by pid) for every process this user can see."""
    kids, comms = {}, {}
    for pid in pids():
        parent = ppid(pid)
        if parent is None:
            continue
        comms[pid] = comm(pid)
        kids.setdefault(parent, []).append(pid)
    return kids, comms
