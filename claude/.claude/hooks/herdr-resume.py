#!/usr/bin/env python3
"""Claude Code SessionStart hook: tell the terminal how to resume this session.

Sends an OSC 7577 (Program Resume Protocol) report on behalf of the `claude`
process, so that a terminal which supports it (herdr-core 0.1.23+) can run
`claude --resume <id>` again after a reboot, crash or core stop.

Spec: https://www.superlogical.com/rex/docs/build/program-resume

Does nothing when the terminal gives no OSC7577_TOKEN. It always exits 0 and
prints nothing, because SessionStart output is added to Claude's context.

No `clear` report is sent on exit: Herdr drops the record when the owning
process ends, and a `clear` sent during a shutdown would lose the session.

Launch flags are not carried over. A resumed session starts with the settings
defaults, so permissions are never widened by an unattended restart.
"""
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import time

SESSION_ID = re.compile(r"[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}")
MAX_BYTES = 2048  # the size every terminal must accept, framing included


def encode(text):
    return base64.b64encode(text.encode()).decode()


def build_report(token, pid, now, argv, cwd):
    body = "pid=%d:time=%d:argv=%s" % (pid, now, ",".join(encode(a) for a in argv))
    if cwd:
        body += ":cwd=" + encode(cwd)
    mac = hashlib.sha256(("%s:%s" % (body, token)).encode()).hexdigest()
    return "%s:mac=%s" % (body, mac)


def find_claude():
    """Return (pid, tty, arguments) of the nearest `claude` ancestor, or None."""
    pid = os.getppid()
    while pid > 1:
        line = subprocess.run(
            ["/bin/ps", "-o", "ppid=,tty=,command=", "-p", str(pid)],
            capture_output=True, text=True).stdout.split()
        if len(line) < 3:
            return None
        if os.path.basename(line[2]) == "claude":
            return pid, line[1], line[3:]
        pid = int(line[0])
    return None


def resume_dir(data):
    """The folder Claude stores this conversation under, or None if unsure.

    `claude --resume` looks the session up by folder, and the hook's `cwd`
    moves when Claude changes directory. The transcript's parent folder is
    named after the right one, so use whichever candidate matches it.
    """
    transcript = data.get("transcript_path")
    if not isinstance(transcript, str):
        return None
    stored = os.path.basename(os.path.dirname(transcript))
    for path in (data.get("cwd"), os.environ.get("CLAUDE_PROJECT_DIR")):
        if isinstance(path, str) and os.path.isabs(path) and re.sub(r"[^A-Za-z0-9]", "-", path) == stored:
            return path
    # Without `cwd`, the terminal uses the claude process's own directory.
    return None


def main():
    token = os.environ.get("OSC7577_TOKEN")
    if not token:
        return
    data = json.load(sys.stdin)
    session = data.get("session_id")
    if not isinstance(session, str) or not SESSION_ID.fullmatch(session):
        return
    owner = find_claude()
    if owner is None:
        return
    pid, tty, args = owner
    # A headless run must not come back as an interactive session.
    if "-p" in args or "--print" in args or tty.startswith("?"):
        return
    report = build_report(
        token, pid, int(time.time()), ["claude", "--resume", session], resume_dir(data))
    frame = ("\x1b]7577;%s\x1b\\" % report).encode()
    if len(frame) > MAX_BYTES:
        return
    # Hooks have no controlling terminal, so write to claude's own by name.
    fd = os.open("/dev/" + tty, os.O_WRONLY | os.O_NOCTTY)
    try:
        os.write(fd, frame)
    finally:
        os.close(fd)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # A failed report only costs auto-resume; never disturb the session.
        pass
