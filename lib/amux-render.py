#!/usr/bin/env python3
"""amux-render.py — render a list of amux sessions from the server JSON.

Reads the /api/sessions JSON on stdin and prints either a compact column-major
grid or verbose rows. Used by BOTH amux-ls (this machine, via 127.0.0.1) and
amux-remote (another machine), so the local and remote views are literally the
same code and cannot drift apart.

Driven entirely by environment variables so the callers stay plain shell:
    AMUX_LS_LABEL     name shown in the header (hostname or box name)
    AMUX_LS_URL       URL shown under the header ("" to omit)
    AMUX_LS_KIND      "remote" (default) or "local" — the word after the label
    AMUX_LS_COMPACT   1 = grid, 0 = verbose rows
    AMUX_LS_BARE      1 = no header at all (for embedding in amux-all/ccjump)
    AMUX_LS_ASCII     1 = ASCII status marks, for Windows consoles
    AMUX_FORCE_COLOR  1 = keep color even when stdout is captured
    COLUMNS           terminal width override
"""
import json, os, sys, shutil, re
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit("could not parse response (check AMUX_URL / AMUX_TOKEN)")
if isinstance(data, dict) and data.get("error"):
    sys.exit("server: " + str(data["error"]))
data = data or []

# Color only on a real terminal (mirrors amux), unless AMUX_FORCE_COLOR is set —
# amux-all sets it so this stays colored even when it captures our output.
_force = os.environ.get("AMUX_FORCE_COLOR","") not in ("", "0")
_use_color = _force or (sys.stdout.isatty() and os.environ.get("TERM","dumb") != "dumb")
if os.environ.get("NO_COLOR") and not _force:
    _use_color = False
if _use_color:
    BOLD="\033[1m"; DIM="\033[2m"; GREEN="\033[32m"; CYAN="\033[36m"; R="\033[0m"
else:
    BOLD=DIM=GREEN=CYAN=R=""
def D(s): return DIM + s + R

label   = os.environ.get("AMUX_LS_LABEL","") or "remote"
url     = os.environ.get("AMUX_LS_URL","")
kind    = os.environ.get("AMUX_LS_KIND","remote")
compact = os.environ.get("AMUX_LS_COMPACT","0") == "1"
bare    = os.environ.get("AMUX_LS_BARE","0")  == "1"
# Windows consoles outside WSL often render the round Unicode marks as boxes,
# depending on the console font; ASCII keeps the grid legible there.
ascii_marks = os.environ.get("AMUX_LS_ASCII","0") == "1"
MARK_ON, MARK_OFF = ("*", "o") if ascii_marks else ("●", "○")
total   = len(data)
running = sum(1 for s in data if s.get("running"))
# Hide archived sessions by default, matching the dashboard.
if os.environ.get("AMUX_SHOW_ARCHIVED","0") != "1":
    data = [s for s in data if not s.get("archived")]
    total   = len(data)
    running = sum(1 for s in data if s.get("running"))

def short_model(s):
    m = ""
    mm = re.search(r"--model\s+(\S+)", s.get("flags","") or "")
    if mm: m = mm.group(1)
    if not m:
        am = s.get("active_model","") or ""
        for tag in ("opus","sonnet","haiku","fable"):
            if tag in am: m = tag; break
        else:
            m = am
    if m.startswith("claude-"): m = m[len("claude-"):]
    return m

def short_dir(s):
    return re.sub(r"^/(Users|home)/[^/]+/", "~/", s.get("dir","") or "")

if not bare:
    print(f"{BOLD}{label}{R} {DIM}({kind}){R} {DIM}·{R} {total} sessions {DIM}·{R} {GREEN}{running} {MARK_ON}{R} running")
    if url:
        extra = f"  {DIM}· ssh {label}{R}" if (kind == "remote" and label and not label[0].isdigit()) else ""
        print(D(url) + extra)
    print()

if total == 0:
    print(D("no sessions"))
    sys.exit(0)

if compact:
    names = [s.get("name","") for s in data]
    runs  = [bool(s.get("running")) for s in data]
    maxw  = max(len(n) for n in names)
    numw  = max(2, len(str(total)))
    cellw = numw + 1 + 1 + 1 + maxw + 2
    try:
        termw = int(os.environ.get("COLUMNS","") or 0)
    except ValueError:
        termw = 0
    if termw <= 0:
        termw = shutil.get_terminal_size((80,24)).columns
    ncols = max(1, min(termw // cellw, total))
    nrows = (total + ncols - 1) // ncols
    for r in range(nrows):
        line = ""
        for c in range(ncols):
            idx = c * nrows + r
            if idx >= total: continue
            if runs[idx]:
                mark = f"{GREEN}{MARK_ON}{R}"; nc = BOLD
            else:
                mark = f"{DIM}{MARK_OFF}{R}"; nc = DIM
            line += f"{idx+1:>{numw}} {mark} {nc}{names[idx]:<{maxw}}{R}  "
        print(line)
else:
    namew = min(max((len(s.get("name","")) for s in data), default=4), 22)
    for s in data:
        icon  = f"{GREEN}{MARK_ON}{R}" if s.get("running") else f"{DIM}{MARK_OFF}{R}"
        name  = s.get("name","")
        model = short_model(s)
        sdir  = short_dir(s)
        print(f" {icon} {BOLD}{name:<{namew}}{R} {CYAN}{model:<7}{R} {DIM}{sdir}{R}")
