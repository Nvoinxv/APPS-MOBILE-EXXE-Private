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
#
# FIX — Modular workspace support:
#   - workspace_files: dict[str, str] berisi semua file dalam satu folder
#     indicator. Key = relative path (e.g. "TESTING/TESTING_1.py"),
#     Value = content string.
#   - Sebelum eksekusi, semua file ditulis ke tempdir → Python bisa resolve
#     `from TESTING.TESTING_1 import ...` karena file benar-benar ada di disk.
#   - tempdir dibersihkan otomatis setelah eksekusi selesai (finally block).
#   - BUG FIX: _inject_cwd() hasil (runnable) sekarang benar-benar dipakai
#     sebagai code yang dieksekusi, bukan `code` asli.
# =============================================================================

import asyncio
import os
import re
import sys
import tempfile
import shutil
from typing import AsyncGenerator

TIMEOUT_SECONDS = 10


# =============================================================================
#  SECURITY — Blacklist
# =============================================================================

BLOCKED_MODULES = {
    "os",
    "subprocess",
    "sys",
    "shutil",
    "pathlib",
    "glob",
    "socket",
    "asyncio",
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
    "gc",
    "inspect",
    "traceback",
    "linecache",
    "tokenize",
    "ast",
    "dis",
    "compileall",
    "py_compile",
    "code",
    "codeop",
    "pdb",
    "faulthandler",
    "tempfile",
    "io",
    "pickle",
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

BLOCKED_PATTERNS: list[tuple[str, str]] = [
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
    (r"pip\s+install",       "pip install tidak diizinkan"),
    (r"pip3\s+install",      "pip3 install tidak diizinkan"),
    (r"easy_install",        "easy_install tidak diizinkan"),
    (r"environ",             "Akses environment variable tidak diizinkan"),
    (r"getenv",              "Akses getenv tidak diizinkan"),
    (r"fork\s*\(",           "fork() tidak diizinkan"),
    (r"execv\s*\(",          "execv() tidak diizinkan"),
    (r"execve\s*\(",         "execve() tidak diizinkan"),
    (r"system\s*\(",         "system() tidak diizinkan"),
    (r"popen\s*\(",          "popen() tidak diizinkan"),
    (r"spawn\s*\(",          "spawn() tidak diizinkan"),
]

_COMPILED_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(pattern, re.IGNORECASE), reason)
    for pattern, reason in BLOCKED_PATTERNS
]


# ─────────────────────────────────────────────────────────────────────────────
#  Security checker
# ─────────────────────────────────────────────────────────────────────────────

class SecurityViolation(Exception):
    pass


def _check_blocked_imports(code: str) -> None:
    import_patterns = [
        re.compile(r"^\s*import\s+([\w,\s]+)", re.MULTILINE),
        re.compile(r"^\s*from\s+([\w.]+)\s+import", re.MULTILINE),
    ]
    for pattern in import_patterns:
        for match in pattern.finditer(code):
            raw = match.group(1).strip()
            modules = [m.strip().split()[0].split(".")[0] for m in raw.split(",")]
            for mod in modules:
                if mod in BLOCKED_MODULES:
                    raise SecurityViolation(
                        f"Module '{mod}' tidak diizinkan karena alasan keamanan."
                    )


def _check_blocked_patterns(code: str) -> None:
    for compiled, reason in _COMPILED_PATTERNS:
        if compiled.search(code):
            raise SecurityViolation(reason)


def validate_code(code: str) -> None:
    _check_blocked_imports(code)
    _check_blocked_patterns(code)


# ─────────────────────────────────────────────────────────────────────────────
#  Workspace tempdir helper
#
#  workspace_files: dict[str, str]
#    key   = relative path file dalam workspace, e.g.:
#            "main.py", "TESTING/TESTING_1.py", "utils/helpers.py"
#    value = content file sebagai string
#
#  Return: path absolut tempdir yang sudah berisi semua file.
#  Caller wajib hapus tempdir setelah eksekusi (pakai finally + shutil.rmtree).
# ─────────────────────────────────────────────────────────────────────────────

def _write_workspace_to_tempdir(workspace_files: dict[str, str]) -> str:
    """
    Tulis semua file workspace ke tempdir baru.
    Return absolute path tempdir.
    """
    tmpdir = tempfile.mkdtemp(prefix="exxe_ws_")
    for rel_path, content in workspace_files.items():
        # Sanitize: cegah path traversal
        rel_path = rel_path.lstrip("/").replace("..", "")
        abs_path = os.path.join(tmpdir, rel_path)
        # Buat parent directory kalau belum ada
        os.makedirs(os.path.dirname(abs_path), exist_ok=True)
        with open(abs_path, "w", encoding="utf-8") as f:
            f.write(content)
        # Buat __init__.py di setiap subfolder supaya bisa di-import
        parent = os.path.dirname(abs_path)
        init_path = os.path.join(parent, "__init__.py")
        if not os.path.exists(init_path):
            open(init_path, "w").close()
    return tmpdir


# ─────────────────────────────────────────────────────────────────────────────
#  One-shot execution
# ─────────────────────────────────────────────────────────────────────────────

async def run_code(
    code:            str,
    timeout:         int            = TIMEOUT_SECONDS,
    cwd:             str | None     = None,   # legacy, tidak dipakai lagi
    workspace_files: dict[str, str] | None = None,
) -> dict:
    """
    Jalankan code Python, tunggu sampai selesai, return dict.

    workspace_files: semua file dalam workspace folder indicator.
    Jika diisi, file ditulis ke tempdir → import modular bisa jalan.
    """
    try:
        validate_code(code)
    except SecurityViolation as e:
        return {
            "stdout":    "",
            "stderr":    f"[Security] {str(e)}",
            "exit_code": -2,
        }

    tmpdir = None
    try:
        # Tulis workspace files ke tempdir kalau ada
        if workspace_files:
            tmpdir   = _write_workspace_to_tempdir(workspace_files)
            run_cwd  = tmpdir
        else:
            run_cwd  = None

        # Inject sys.path ke tempdir supaya import resolve dengan benar
        runnable = f"import sys as _sys; _sys.path.insert(0, {repr(run_cwd)})\n{code}" \
                   if run_cwd else code

        proc = await asyncio.create_subprocess_exec(
            sys.executable, "-c", runnable,   # ← pakai runnable, bukan code
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            stdin=asyncio.subprocess.DEVNULL,
            cwd=run_cwd,                       # ← working dir = tempdir
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

    finally:
        # Bersihkan tempdir setelah eksekusi
        if tmpdir and os.path.exists(tmpdir):
            shutil.rmtree(tmpdir, ignore_errors=True)


# =============================================================================
#  Streaming execution — async generator untuk SSE
# =============================================================================

async def run_code_stream(
    code:            str,
    timeout:         int            = TIMEOUT_SECONDS,
    cwd:             str | None     = None,   # legacy, tidak dipakai lagi
    workspace_files: dict[str, str] | None = None,
) -> AsyncGenerator[str, None]:
    """
    Jalankan code Python, yield output line-by-line sebagai SSE events.

    workspace_files: semua file dalam workspace folder indicator.
    Jika diisi, file ditulis ke tempdir → import modular bisa jalan.

    Format setiap yield:
        "data: <json>\\n\\n"

    JSON payload:
        { "type": "stdout" | "stderr" | "system" | "exit", "data": "..." }
    """
    import json

    def _event(type_: str, data: str) -> str:
        payload = json.dumps({"type": type_, "data": data}, ensure_ascii=False)
        return f"data: {payload}\n\n"

    if not code.strip():
        yield _event("system", "[Error] Code is empty.")
        yield _event("exit", "1")
        return

    try:
        validate_code(code)
    except SecurityViolation as e:
        yield _event("system", "─" * 40)
        yield _event("stderr", f"[Security] {str(e)}")
        yield _event("system", "─" * 40)
        yield _event("system", "✗  Execution blocked by security policy.")
        yield _event("exit", "-2")
        return

    tmpdir = None
    proc   = None
    try:
        # Tulis workspace files ke tempdir kalau ada
        if workspace_files:
            tmpdir  = _write_workspace_to_tempdir(workspace_files)
            run_cwd = tmpdir
        else:
            run_cwd = None

        # Inject sys.path ke tempdir
        runnable = f"import sys as _sys; _sys.path.insert(0, {repr(run_cwd)})\n{code}" \
                   if run_cwd else code

        proc = await asyncio.create_subprocess_exec(
            sys.executable, "-c", runnable,   # ← pakai runnable, bukan code
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            stdin=asyncio.subprocess.DEVNULL,
            cwd=run_cwd,                       # ← working dir = tempdir
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

    finally:
        # Bersihkan tempdir setelah stream selesai
        if tmpdir and os.path.exists(tmpdir):
            shutil.rmtree(tmpdir, ignore_errors=True)