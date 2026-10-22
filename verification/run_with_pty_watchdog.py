#!/usr/bin/env python3
"""Run a command under a pseudo-terminal with a wall-clock watchdog.

Usage: run_with_pty_watchdog.py <timeout-seconds> -- <command> [args...]

xctest block-buffers stdout (16 KB) when it writes into a pipe, so a hung
`swift test` run once hid which test was running. Under a pseudo-terminal the
output is line-buffered. When the deadline passes, the watchdog names the last
test that started, samples the running xctest processes with macOS `sample`,
stops the run, and exits with status 124 so the job can still upload its logs.
Otherwise the command's own exit status is returned.
"""

import os
import pty
import re
import select
import signal
import subprocess
import sys
import time

STARTED = re.compile(rb"Test Case '([^']+)' started")


def sample_xctest_processes() -> None:
    listed = subprocess.run(["pgrep", "-x", "xctest"], capture_output=True, text=True, check=False)
    for pid in listed.stdout.split():
        report = f"xctest-hang-{pid}.txt"
        print(f"--- sample of xctest pid {pid} ---", flush=True)
        sampled = subprocess.run(
            ["sudo", "-n", "sample", pid, "3", "-mayDie", "-file", report],
            capture_output=True,
            text=True,
            check=False,
        )
        if sampled.returncode != 0 or not os.path.exists(report):
            print(f"sample failed ({sampled.returncode}): {sampled.stderr.strip()}", flush=True)
            continue
        with open(report, encoding="utf-8", errors="replace") as handle:
            sys.stdout.write(handle.read())
        sys.stdout.flush()


def stop(child_pid: int) -> None:
    for sig in (signal.SIGTERM, signal.SIGKILL):
        subprocess.run(["pkill", f"-{sig.name[3:]}", "-x", "xctest"], check=False)
        try:
            os.killpg(child_pid, sig)
        except ProcessLookupError:
            return
        for _ in range(50):
            finished, _ = os.waitpid(child_pid, os.WNOHANG)
            if finished:
                return
            time.sleep(0.1)


def main() -> int:
    if len(sys.argv) < 4 or sys.argv[2] != "--":
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    timeout = float(sys.argv[1])
    command = sys.argv[3:]

    child_pid, master = pty.fork()
    if child_pid == 0:
        try:
            os.environ["TERM"] = "dumb"  # plain log lines, no progress-bar escape codes
            os.execvp(command[0], command)
        finally:
            os._exit(127)

    deadline = time.monotonic() + timeout
    last_started = b""
    pending = b""
    status = None
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            name = last_started.decode(errors="replace") or "none"
            print(f"\n::error::Command exceeded {int(timeout)} s; last test started: {name}", flush=True)
            sample_xctest_processes()
            stop(child_pid)
            return 124
        ready, _, _ = select.select([master], [], [], min(remaining, 5.0))
        if not ready:
            # A leftover grandchild can keep the terminal open after the command exits.
            finished, child_status = os.waitpid(child_pid, os.WNOHANG)
            if finished:
                status = child_status
                break
            continue
        try:
            data = os.read(master, 65536)
        except OSError:
            data = b""
        if not data:
            break
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()
        pending += data
        *lines, pending = pending.split(b"\n")
        for line in lines:
            match = STARTED.search(line)
            if match:
                last_started = match.group(1)

    if status is None:
        _, status = os.waitpid(child_pid, 0)
    return os.waitstatus_to_exitcode(status)


if __name__ == "__main__":
    sys.exit(main())
