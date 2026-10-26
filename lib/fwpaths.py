"""Apps workspace rules for the Python tools - the same as lib/common.sh (docs/workflow.md "Apps workspace").

Order: <PREFIX>_WS (a skill's env prefix, e.g. L4_WS) > FW_WS (environment, else the per-PC file
~/.fw-skills.env; FW_SETTINGS names another file) > <project>/apps, where <project> is the repo
inside the repo checkout, else the current folder. .bench/ (this PC's probes and ports) lives in the
workspace unless <PREFIX>_BENCH_DIR says otherwise. lib/fw_workspace.sh writes the per-PC file.
"""
import os
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def _native(p):
    """/c/fw-ws (Git Bash form) -> C:/fw-ws on Windows; other paths unchanged"""
    m = re.match(r"^/([A-Za-z])(/.*)?$", p)
    if os.name == "nt" and m:
        return f"{m.group(1).upper()}:{m.group(2) or '/'}"
    return p


def settings_file():
    return Path(os.environ.get("FW_SETTINGS") or Path.home() / ".fw-skills.env")


def saved_ws():
    """the workspace chosen for this PC (FW_WS, else the settings file), or None"""
    v = os.environ.get("FW_WS", "")
    if not v:
        try:
            lines = settings_file().read_text(encoding="utf-8").splitlines()
        except OSError:
            lines = []
        vals = [ln.split("=", 1)[1].strip().strip("'\"") for ln in lines if ln.startswith("FW_WS=")]
        v = vals[-1] if vals else ""
    return Path(_native(v)) if v else None


def project_root():
    cwd = Path.cwd().resolve()
    return REPO_ROOT if cwd == REPO_ROOT or REPO_ROOT in cwd.parents else cwd


def default_ws(prefix=None):
    """the apps workspace the scripts use (prefix: a skill's env prefix, e.g. "L4")"""
    v = os.environ.get(f"{prefix}_WS") if prefix else None
    return Path(_native(v)) if v else (saved_ws() or project_root() / "apps")


def bench_dir(prefix=None):
    v = os.environ.get(f"{prefix}_BENCH_DIR") if prefix else None
    return Path(_native(v)) if v else default_ws(prefix) / ".bench"
