#!/usr/bin/env python3

import os
import select
import shlex
import sys
import termios
import tty


def main() -> int:
    argv = sys.argv[1:]
    if not argv:
        return 1

    context_file = os.environ.get("ARCHMEROS_AICHAT_CONTEXT_FILE", "").strip()
    inject = ""
    if context_file:
        inject = f".file {shlex.quote(context_file)}\r"

    pid, master_fd = os.forkpty()
    if pid == 0:
        os.execvp(argv[0], argv)

    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    old_tty = None
    if os.isatty(stdin_fd):
        old_tty = termios.tcgetattr(stdin_fd)
        tty.setraw(stdin_fd)

    injected = False
    prompt_markers = ("Type \".help\"", "> ", "(To exit, press Ctrl+D")
    banner = ""

    try:
        while True:
            readers = [master_fd]
            if os.isatty(stdin_fd):
                readers.append(stdin_fd)

            ready, _, _ = select.select(readers, [], [])

            if master_fd in ready:
                try:
                    data = os.read(master_fd, 4096)
                except OSError:
                    break
                if not data:
                    break

                os.write(stdout_fd, data)

                if inject and not injected:
                    try:
                        banner += data.decode("utf-8", errors="ignore")
                    except Exception:
                        banner += ""
                    if any(marker in banner for marker in prompt_markers):
                        os.write(master_fd, inject.encode("utf-8"))
                        injected = True

            if stdin_fd in ready:
                try:
                    user_data = os.read(stdin_fd, 4096)
                except OSError:
                    user_data = b""
                if not user_data:
                    break
                os.write(master_fd, user_data)
    finally:
        if old_tty is not None:
            termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty)

    _, status = os.waitpid(pid, 0)
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
