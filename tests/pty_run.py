#!/usr/bin/env python3
"""Run a command on a pty, answering sudo password prompts.

Bootstrap's escalation has to be exercised from a real terminal, because the
path it picks depends on whether one is present. Used by tests/e2e-sudors.sh.

Exits non-zero if Ansible ever asks for a become password: on sudo-rs that
means the run is heading for the prompt-matching bug instead of the sudoers
grant, which is exactly what the test exists to catch.
"""

import os
import pty
import sys

PASSWORD = (os.environ.get("TEST_SUDO_PASSWORD", "") + "\n").encode()
OUTPUT_PATH = os.environ.get("TEST_OUTPUT")

captured = bytearray()
saw_become_prompt = False


def master_read(fd):
    """Stream child output, replying to each sudo password prompt."""
    global saw_become_prompt
    data = os.read(fd, 1024)
    captured.extend(data)
    if b"BECOME password" in data:
        saw_become_prompt = True
    elif b"assword" in data and data.rstrip().endswith(b":"):
        os.write(fd, PASSWORD)
    return data


status = pty.spawn(sys.argv[1:], master_read)

if OUTPUT_PATH:
    with open(OUTPUT_PATH, "wb") as handle:
        handle.write(bytes(captured))

if saw_become_prompt:
    print("\n[pty-run] Ansible asked for a become password", file=sys.stderr)
    sys.exit(1)

sys.exit(os.waitstatus_to_exitcode(status))
