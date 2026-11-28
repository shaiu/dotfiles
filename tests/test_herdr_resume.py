"""Tests for the Claude Code hook that reports a resume command (OSC 7577).

Spec: https://www.superlogical.com/rex/docs/build/program-resume
Run:  /usr/bin/python3 tests/test_herdr_resume.py
"""
import base64
import hashlib
import importlib.util
import json
import os
import pty
import re
import select
import shlex
import subprocess
import sys
import tempfile
import time
import unittest

HOOK = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "claude", ".claude", "hooks", "herdr-resume.py",
)
SPEC_TOKEN = "dummy-token-replace-me"
TOKEN = "test-token-0123456789abcdef"
SESSION = "11111111-2222-4333-8444-555555555555"
FRAME = re.compile(rb"\x1b\]7577;([^\x07\x1b]*)\x1b\\")


def load_hook():
    spec = importlib.util.spec_from_file_location("herdr_resume", HOOK)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def slug(path):
    return re.sub(r"[^A-Za-z0-9]", "-", path)


class SpecVectors(unittest.TestCase):
    """The published examples carry real hashes, so we must match them byte for byte."""

    def test_neovim_example(self):
        report = load_hook().build_report(
            SPEC_TOKEN, 74877, 1795543200,
            ["nvim", "-S", "/home/user/.local/state/nvim/sessions/8f2c1d.vim"], None)
        self.assertEqual(
            report,
            "pid=74877:time=1795543200:argv=bnZpbQ==,LVM=,"
            "L2hvbWUvdXNlci8ubG9jYWwvc3RhdGUvbnZpbS9zZXNzaW9ucy84ZjJjMWQudmlt:"
            "mac=9dbb99bfb856749a87563839d7ce9062818d78cf25909db93f309e0cd3b1909b")

    def test_lazygit_example_with_cwd(self):
        report = load_hook().build_report(
            SPEC_TOKEN, 74877, 1795543200, ["lazygit"], "/home/user/src/project")
        self.assertEqual(
            report,
            "pid=74877:time=1795543200:argv=bGF6eWdpdA==:"
            "cwd=L2hvbWUvdXNlci9zcmMvcHJvamVjdA==:"
            "mac=35cb909805c380336efd3689a125acc774a9dec8422a1d21492ebec06ca758e1")


class InARealTerminal(unittest.TestCase):
    """Runs the hook under a process named `claude` on a real pseudo-terminal."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = os.path.realpath(tmp.name)
        self.project = os.path.join(self.dir, "my project")
        os.mkdir(self.project)
        self.claude = os.path.join(self.dir, "claude")
        os.symlink("/bin/bash", self.claude)

    def payload(self, **overrides):
        data = {
            "session_id": SESSION,
            "cwd": self.project,
            "transcript_path": "/x/.claude/projects/%s/%s.jsonl" % (slug(self.project), SESSION),
            "hook_event_name": "SessionStart",
            "source": "startup",
        }
        data.update(overrides)
        return json.dumps(data)

    def run_hook(self, stdin, token=TOKEN, claude_args=(), project_dir=None):
        """Return (bytes seen by the terminal, hook output, hook exit code, claude pid)."""
        stdin_file = os.path.join(self.dir, "stdin.json")
        out_file = os.path.join(self.dir, "out")
        code_file = os.path.join(self.dir, "code")
        pid_file = os.path.join(self.dir, "pid")
        with open(stdin_file, "w") as handle:
            handle.write(stdin)
        # Like Claude Code: the hook runs through an intermediate shell, with pipes.
        inner = "%s %s < %s 2>&1 | cat > %s; echo ${PIPESTATUS[0]} > %s" % tuple(
            shlex.quote(p) for p in
            (sys.executable, HOOK, stdin_file, out_file, code_file))
        script = os.path.join(self.dir, "fake.sh")
        with open(script, "w") as handle:
            handle.write("echo $$ > %s\n/bin/sh -c %s\ntrue\n" % (
                shlex.quote(pid_file), shlex.quote("/bin/bash -c %s; true" % shlex.quote(inner))))
        env = {"PATH": "/usr/bin:/bin"}
        if token is not None:
            env["OSC7577_TOKEN"] = token
        if project_dir is not None:
            env["CLAUDE_PROJECT_DIR"] = project_dir
        pid, master = pty.fork()
        if pid == 0:
            os.execve(self.claude, [self.claude, script] + list(claude_args), env)
        seen = b""
        deadline = time.time() + 20
        while time.time() < deadline:
            if select.select([master], [], [], 0.2)[0]:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                seen += chunk
        os.waitpid(pid, 0)
        os.close(master)
        with open(out_file) as handle:
            output = handle.read()
        with open(code_file) as handle:
            code = int(handle.read())
        with open(pid_file) as handle:
            claude_pid = int(handle.read())
        return seen, output, code, claude_pid

    def fields(self, seen):
        frames = FRAME.findall(seen)
        self.assertEqual(len(frames), 1, "terminal saw %r" % seen)
        body, mac = frames[0].decode().rsplit(":mac=", 1)
        self.assertEqual(mac, hashlib.sha256(("%s:%s" % (body, TOKEN)).encode()).hexdigest())
        fields = dict(pair.split("=", 1) for pair in body.split(":"))
        if "argv" in fields:
            fields["argv"] = [base64.b64decode(a).decode() for a in fields["argv"].split(",")]
        if "cwd" in fields:
            fields["cwd"] = base64.b64decode(fields["cwd"]).decode()
        return fields

    def assert_silent(self, result):
        seen, output, code, _ = result
        self.assertEqual(FRAME.findall(seen), [])
        self.assertEqual((output, code), ("", 0))

    def test_reports_resume_command_for_the_claude_process(self):
        seen, output, code, claude_pid = self.run_hook(self.payload())
        fields = self.fields(seen)
        self.assertEqual(fields["argv"], ["claude", "--resume", SESSION])
        self.assertEqual(int(fields["pid"]), claude_pid)
        self.assertLessEqual(abs(int(fields["time"]) - time.time()), 60)
        self.assertEqual(fields["cwd"], self.project)
        # SessionStart stdout is added to Claude's context, so it must stay empty.
        self.assertEqual((output, code), ("", 0))

    def test_uses_the_transcript_folder_after_claude_changed_directory(self):
        elsewhere = os.path.join(self.dir, "elsewhere")
        os.mkdir(elsewhere)
        seen = self.run_hook(self.payload(cwd=elsewhere), project_dir=self.project)[0]
        self.assertEqual(self.fields(seen)["cwd"], self.project)

    def test_omits_cwd_when_no_folder_matches_the_transcript(self):
        seen = self.run_hook(self.payload(transcript_path="/x/projects/-other/a.jsonl"))[0]
        self.assertNotIn("cwd", self.fields(seen))

    def test_silent_without_token(self):
        self.assert_silent(self.run_hook(self.payload(), token=None))

    def test_silent_for_headless_runs(self):
        for flag in ("-p", "--print"):
            with self.subTest(flag=flag):
                self.assert_silent(self.run_hook(self.payload(), claude_args=[flag]))

    def test_silent_for_bad_input(self):
        for bad in ("not json", "[]", "{}", self.payload(session_id="x; reboot"),
                    self.payload(session_id="--dangerously-skip-permissions")):
            with self.subTest(stdin=bad[:60]):
                self.assert_silent(self.run_hook(bad))


class OutsideClaude(unittest.TestCase):
    def test_silent_when_no_claude_process_is_above_it(self):
        done = subprocess.run(
            [sys.executable, HOOK], input=json.dumps({"session_id": SESSION}),
            env={"PATH": "/usr/bin:/bin", "OSC7577_TOKEN": TOKEN},
            capture_output=True, text=True, start_new_session=True)
        self.assertEqual((done.returncode, done.stdout, done.stderr), (0, "", ""))


if __name__ == "__main__":
    unittest.main()
