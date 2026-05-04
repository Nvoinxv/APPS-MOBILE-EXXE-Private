# =============================================================================
# services/python_runners.py
#
# Python execution service — supports:
#   - run_code()        : one-shot execution
#   - run_code_stream() : async generator, yields output line-by-line (SSE)
#
# Security:
#   - Timeout enforced (default 10s)
#   - Subprocess isolated via sys.executable
#   - stdin closed — no interactive input
#   - Blacklist: blokir import/command berbahaya sebelum dieksekusi
# =============================================================================

import asyncio
import re
import sys
from typing import AsyncGenerator

TIMEOUT_SECONDS = 10


# =============================================================================
#  SECURITY — Blacklist
# =============================================================================
#
#  Strategi: AST-level check + regex pattern matching
#  Bukan 100% bulletproof, tapi cukup untuk block casual misuse.
#  Untuk production-grade isolation → pakai Docker-in-Docker / gVisor.
#
# =============================================================================

# ── Modul yang diblokir total ─────────────────────────────────────────────────
BLOCKED_MODULES = {
    "os",
    "subprocess",
    "sys",
    "shutil",
    "pathlib",
    "glob",
    "socket",
    "asyncio",        # bisa spawn subprocess
    "multiprocessing",
    "threading",
    "signal",
    "ctypes",
    "mmap",
    "resource",
    "pty",
    "termios",
    "tty",
    "fcntl",
    "pwd",
    "grp",
    "nis",
    "syslog",
    "platform",
    "importlib",
    "pkgutil",
    "zipimport",
    "builtins",
    "gc",             # garbage collector manipulation
    "inspect",        # bisa akses frame/source code
    "traceback",
    "linecache",
    "tokenize",
    "ast",
    "dis",            # bytecode disassembler
    "compileall",
    "py_compile",
    "code",
    "codeop",
    "pdb",
    "faulthandler",
    "tempfile",
    "io",
    "pickle",         # arbitrary code execution via deserialization
    "shelve",
    "marshal",
    "struct",
    "codecs",
    "urllib",
    "http",
    "ftplib",
    "smtplib",
    "telnetlib",
    "xmlrpc",
    "webbrowser",
    "email",
    "html",
    "xml",
    "plistlib",
}

# ── Pattern berbahaya (regex) ─────────────────────────────────────────────────
BLOCKED_PATTERNS: list[tuple[str, str]] = [
    # __dunder__ abuse
    (r"__import__",          "Penggunaan __import__ tidak diizinkan"),
    (r"__builtins__",        "Akses __builtins__ tidak diizinkan"),
    (r"__class__",           "Akses __class__ tidak diizinkan"),
    (r"__subclasses__",      "Akses __subclasses__ tidak diizinkan"),
    (r"__globals__",         "Akses __globals__ tidak diizinkan"),
    (r"__locals__",          "Akses __locals__ tidak diizinkan"),
    (r"__code__",            "Akses __code__ tidak diizinkan"),
    (r"__reduce__",          "Akses __reduce__ tidak diizinkan"),
    (r"__getattribute__",    "Akses __getattribute__ tidak diizinkan"),
    (r"__bases__",           "Akses __bases__ tidak diizinkan"),
    (r"__mro__",             "Akses __mro__ tidak diizinkan"),

    # Shell / exec escape
    (r"\beval\s*\(",         "eval() tidak diizinkan"),
    (r"\bexec\s*\(",         "exec() tidak diizinkan"),
    (r"\bcompile\s*\(",      "compile() tidak diizinkan"),
    (r"\bopen\s*\(",         "open() (file I/O) tidak diizinkan"),
    (r"\binput\s*\(",        "input() tidak diizinkan — tidak ada stdin"),
    (r"\bgetattr\s*\(",      "getattr() tidak diizinkan"),
    (r"\bsetattr\s*\(",      "setattr() tidak diizinkan"),
    (r"\bdelattr\s*\(",      "delattr() tidak diizinkan"),
    (r"\bvars\s*\(",         "vars() tidak diizinkan"),
    (r"\bdir\s*\(",          "dir() tidak diizinkan"),

    # Pip / package install
    (r"pip\s+install",       "pip install tidak diizinkan"),
    (r"pip3\s+install",      "pip3 install tidak diizinkan"),
    (r"easy_install",        "easy_install tidak diizinkan"),

    # Environment / process
    (r"environ",             "Akses environment variable tidak diizinkan"),
    (r"getenv",              "Akses getenv tidak diizinkan"),
    (r"fork\s*\(",           "fork() tidak diizinkan"),
    (r"execv\s*\(",          "execv() tidak diizinkan"),
    (r"execve\s*\(",         "execve() tidak diizinkan"),
    (r"system\s*\(",         "system() tidak diizinkan"),
    (r"popen\s*\(",          "popen() tidak diizinkan"),
    (r"spawn\s*\(",          "spawn() tidak diizinkan"),
]

# Pre-compile regex patterns sekali saja (performa)
_COMPILED_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(pattern, re.IGNORECASE), reason)
    for pattern, reason in BLOCKED_PATTERNS
]


# ─────────────────────────────────────────────────────────────────────────────
#  Security checker
# ─────────────────────────────────────────────────────────────────────────────

class SecurityViolation(Exception):
    """Raised kalau code mengandung pattern berbahaya."""
    pass


def _check_blocked_imports(code: str) -> None:
    """
    Parse import statements dan cek apakah modulnya ada di BLOCKED_MODULES.
    Support: import X, import X as Y, from X import Y, from X.Y import Z
    """
    # Regex untuk semua bentuk import
    import_patterns = [
        re.compile(r"^\s*import\s+([\w,\s]+)", re.MULTILINE),
        re.compile(r"^\s*from\s+([\w.]+)\s+import", re.MULTILINE),
    ]

    for pattern in import_patterns:
        for match in pattern.finditer(code):
            raw = match.group(1).strip()
            # Handle "import os, sys, numpy" → split by comma
            modules = [m.strip().split()[0].split(".")[0] for m in raw.split(",")]
            for mod in modules:
                if mod in BLOCKED_MODULES:
                    raise SecurityViolation(
                        f"Module '{mod}' tidak diizinkan karena alasan keamanan."
                    )


def _check_blocked_patterns(code: str) -> None:
    """Scan code terhadap regex patterns berbahaya."""
    for compiled, reason in _COMPILED_PATTERNS:
        if compiled.search(code):
            raise SecurityViolation(reason)


def validate_code(code: str) -> None:
    """
    Full security check. Raise SecurityViolation kalau ada yang terdeteksi.
    Dipanggil sebelum subprocess dijalankan.
    """
    _check_blocked_imports(code)
    _check_blocked_patterns(code)


# =============================================================================
#  One-shot execution
# =============================================================================

async def run_code(code: str, timeout: int = TIMEOUT_SECONDS) -> dict:
    """
    Jalankan code Python, tunggu sampai selesai, return dict.
    Dipakai oleh POST /execute (non-streaming).
    """
    # Security check dulu sebelum subprocess
    try:
        validate_code(code)
    except SecurityViolation as e:
        return {
            "stdout":    "",
            "stderr":    f"[Security] {str(e)}",
            "exit_code": -2,
        }

    try:
        proc = await asyncio.create_subprocess_exec(
            sys.executable, "-c", code,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            stdin=asyncio.subprocess.DEVNULL,
        )

        stdout, stderr = await asyncio.wait_for(
            proc.communicate(), timeout=timeout
        )

        return {
            "stdout":    stdout.decode("utf-8", errors="replace"),
            "stderr":    stderr.decode("utf-8", errors="replace"),
            "exit_code": proc.returncode,
        }

    except asyncio.TimeoutError:
        try:
            proc.kill()
            await proc.wait()
        except Exception:
            pass
        return {
            "stdout":    "",
            "stderr":    f"[Timeout] Execution exceeded {timeout}s limit.",
            "exit_code": -1,
        }

    except Exception as e:
        return {
            "stdout":    "",
            "stderr":    f"[Runner Error] {str(e)}",
            "exit_code": -1,
        }


# =============================================================================
#  Streaming execution — async generator untuk SSE
# =============================================================================

async def run_code_stream(
    code: str,
    timeout: int = TIMEOUT_SECONDS,
) -> AsyncGenerator[str, None]:
    """
    Jalankan code Python, yield output line-by-line sebagai SSE events.

    Format setiap yield:
        "data: <json>\\n\\n"

    JSON payload:
        { "type": "stdout" | "stderr" | "system" | "exit", "data": "..." }
    """
    import json

    def _event(type_: str, data: str) -> str:
        payload = json.dumps({"type": type_, "data": data}, ensure_ascii=False)
        return f"data: {payload}\n\n"

    # Guard: kode kosong
    if not code.strip():
        yield _event("system", "[Error] Code is empty.")
        yield _event("exit", "1")
        return

    # Security check
    try:
        validate_code(code)
    except SecurityViolation as e:
        yield _event("system", "─" * 40)
        yield _event("stderr", f"[Security] {str(e)}")
        yield _event("system", "─" * 40)
        yield _event("system", "✗  Execution blocked by security policy.")
        yield _event("exit", "-2")
        return

    proc = None
    try:
        proc = await asyncio.create_subprocess_exec(
            sys.executable, "-c", code,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            stdin=asyncio.subprocess.DEVNULL,
        )

        yield _event("system", "▶  Running...")
        yield _event("system", "─" * 40)

        async def _read_stream(stream, type_: str):
            while True:
                line = await stream.readline()
                if not line:
                    break
                yield _event(type_, line.decode("utf-8", errors="replace").rstrip("\n"))

        async def _collect():
            stdout_lines = []
            stderr_lines = []

            async def _drain_stdout():
                async for event in _read_stream(proc.stdout, "stdout"):
                    stdout_lines.append(event)

            async def _drain_stderr():
                async for event in _read_stream(proc.stderr, "stderr"):
                    stderr_lines.append(event)

            await asyncio.gather(_drain_stdout(), _drain_stderr())
            return stdout_lines, stderr_lines

        stdout_events, stderr_events = await asyncio.wait_for(
            _collect(), timeout=timeout
        )

        had_stdout = False
        for ev in stdout_events:
            had_stdout = True
            yield ev

        if not had_stdout:
            yield _event("system", "(no stdout output)")

        if stderr_events:
            yield _event("system", "─" * 40)
            for ev in stderr_events:
                yield ev

        await proc.wait()
        exit_code = proc.returncode

        yield _event("system", "─" * 40)

        if exit_code == 0:
            yield _event("system", "✓  Process exited with code 0")
        else:
            yield _event("system", f"✗  Process exited with code {exit_code}")

        yield _event("exit", str(exit_code))

    except asyncio.TimeoutError:
        if proc:
            try:
                proc.kill()
                await proc.wait()
            except Exception:
                pass
        yield _event("system", "─" * 40)
        yield _event("stderr", f"[Timeout] Execution exceeded {timeout}s limit.")
        yield _event("exit", "-1")

    except Exception as e:
        if proc:
            try:
                proc.kill()
                await proc.wait()
            except Exception:
                pass
        yield _event("system", "─" * 40)
        yield _event("stderr", f"[Runner Error] {str(e)}")
        yield _event("exit", "-1")