#!/usr/bin/env bash
# amux-common.sh — shared platform / package-manager / config layer for the amux companion tools.
#
#   Sourced by the commands in bin/ and the scripts in setup/. Never run directly.
#
#   Everything in here answers one of four questions:
#     1. What kind of machine is this?        amux_platform
#     2. How do I install software on it?     amux_pkgmgr / amux_pkg_install
#     3. How do I download a file?            amux_fetch
#     4. Where do configs and secrets live?   amux_remotes_dir / amux_write_secret
#
#   The rule that shapes all of it: DETECT, never assume. A student's machine may
#   have brew or port or apt or winget or scoop or MSYS2 pacman; curl or wget or
#   only PowerShell. Hardcoding one of each is how a setup script "works on my
#   machine" and nowhere else.
#
# shellcheck shell=bash

# Where this library lives — lets a symlinked command find the checkout.
AMUX_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Guard against double-sourcing (bin/ scripts may source this transitively).
[ -n "${_AMUX_COMMON_SOURCED:-}" ] && return 0
_AMUX_COMMON_SOURCED=1

# ─────────────────────────────────────────────────────────────────────────────
# Colors — only on a real terminal. Piping -h into a file or pager must not
# spray escape codes. AMUX_FORCE_COLOR=1 forces on (for captured output that
# still lands in a terminal); NO_COLOR turns it off (https://no-color.org).
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "${AMUX_FORCE_COLOR:-}" ] && [ "${AMUX_FORCE_COLOR:-}" != "0" ]; then
  _amux_color=1
elif [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
  _amux_color=1
else
  _amux_color=0
fi
if [ "$_amux_color" = 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; CYAN=$'\033[36m'
else
  BOLD=''; DIM=''; RESET=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''
fi

# ─────────────────────────────────────────────────────────────────────────────
# Output helpers
# ─────────────────────────────────────────────────────────────────────────────
amux_die()  { printf '%serror:%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
amux_warn() { printf '%swarn:%s %s\n'  "$YELLOW" "$RESET" "$*" >&2; }
amux_info() { printf '%s·%s %s\n'      "$DIM" "$RESET" "$*"; }
amux_ok()   { printf '  %s✓%s %s\n'    "$GREEN" "$RESET" "$*"; }
amux_bad()  { printf '  %s✗%s %s\n'    "$RED" "$RESET" "$*"; }
amux_hmm()  { printf '  %s!%s %s\n'    "$YELLOW" "$RESET" "$*"; }

# Print a script's own leading comment block as its --help text. Every command in
# bin/ uses this, so the header comment IS the documentation and cannot drift.
amux_self_help() {
  awk 'NR==1 && /^#!/ {next}
       /^[[:space:]]*#/ {sub(/^[[:space:]]*#[[:space:]]?/,""); print; next}
       {exit}' "$1"
}

amux_have() { command -v "$1" >/dev/null 2>&1; }

# Should status dots fall back to ASCII? Windows terminals outside WSL often
# render ● / ○ as replacement boxes depending on the console font.
# An explicit AMUX_ASCII always wins, so a user on any platform can force either
# style — and so the setting is testable without a Windows machine.
amux_ascii_default() {
  if [ -n "${AMUX_ASCII:-}" ]; then printf '%s\n' "$AMUX_ASCII"; return; fi
  case "$(amux_platform)" in msys|cygwin) printf '1\n' ;; *) printf '0\n' ;; esac
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Platform detection
#
# Returns one of: macos | linux | wsl | msys | cygwin | unknown
#
# WSL is deliberately distinct from linux: it IS Linux, but three things differ
# that the setup layer must know about — systemd may be absent (WSL1 and older
# WSL2 configs), the Windows host reaches services differently, and Claude
# Code's Chrome integration is not supported there at all.
#
# msys covers Git Bash and MSYS2 (uname -s: MINGW64_NT-*, MSYS_NT-*).
# ─────────────────────────────────────────────────────────────────────────────
amux_platform() {
  [ -n "${_AMUX_PLATFORM:-}" ] && { printf '%s\n' "$_AMUX_PLATFORM"; return; }
  local u; u=$(uname -s 2>/dev/null || echo unknown)
  case "$u" in
    Darwin)  _AMUX_PLATFORM=macos ;;
    Linux)
      # WSL advertises itself in the kernel release string ("microsoft" /
      # "WSL2"). /proc/version is the other tell; check both — a custom-built
      # WSL kernel may not carry "microsoft" in uname -r.
      if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null \
         || printf '%s' "$(uname -r 2>/dev/null)" | grep -qiE 'microsoft|wsl'; then
        _AMUX_PLATFORM=wsl
      else
        _AMUX_PLATFORM=linux
      fi ;;
    MINGW*|MSYS*) _AMUX_PLATFORM=msys ;;
    CYGWIN*)      _AMUX_PLATFORM=cygwin ;;
    *)            _AMUX_PLATFORM=unknown ;;
  esac
  printf '%s\n' "$_AMUX_PLATFORM"
}

# Human-readable platform label, e.g. "Windows (MSYS2/Git Bash)".
amux_platform_label() {
  case "$(amux_platform)" in
    macos)  printf 'macOS\n' ;;
    linux)  printf 'Linux\n' ;;
    wsl)    printf 'Windows (WSL)\n' ;;
    msys)   printf 'Windows (MSYS2/Git Bash)\n' ;;
    cygwin) printf 'Windows (Cygwin)\n' ;;
    *)      printf 'unknown\n' ;;
  esac
}

# True on any flavor of Windows, including WSL.
amux_is_windows() {
  case "$(amux_platform)" in wsl|msys|cygwin) return 0 ;; *) return 1 ;; esac
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Package manager detection
#
# Returns the FIRST manager found, preferring the one that needs no admin
# rights and installs per-user — a student on a lab machine often cannot sudo.
#
#   macOS    brew > port
#   Linux    apt > dnf > pacman > zypper > apk        (whatever the distro has)
#   MSYS2    pacman                                    (note: MSYS2's pacman, not Arch's)
#   Windows  scoop > winget > choco                    (scoop first: no admin needed)
# ─────────────────────────────────────────────────────────────────────────────
amux_pkgmgr() {
  [ -n "${_AMUX_PKGMGR:-}" ] && { printf '%s\n' "$_AMUX_PKGMGR"; return; }
  local p; p=$(amux_platform)
  _AMUX_PKGMGR=none
  case "$p" in
    macos)
      if   amux_have brew; then _AMUX_PKGMGR=brew
      elif amux_have port; then _AMUX_PKGMGR=port
      fi ;;
    linux|wsl)
      # Order is by prevalence, not preference — a box has exactly one of these.
      for m in apt-get dnf pacman zypper apk; do
        if amux_have "$m"; then
          case "$m" in apt-get) _AMUX_PKGMGR=apt ;; *) _AMUX_PKGMGR=$m ;; esac
          break
        fi
      done ;;
    msys|cygwin)
      # MSYS2 ships pacman and is the only Windows environment with a real tmux.
      # Git Bash has NO package manager — fall through to the Windows-native ones,
      # which are reachable from Git Bash because they're on the Windows PATH.
      if amux_have pacman; then _AMUX_PKGMGR=msys2
      elif amux_have scoop;  then _AMUX_PKGMGR=scoop
      elif amux_have winget; then _AMUX_PKGMGR=winget
      elif amux_have choco;  then _AMUX_PKGMGR=choco
      fi ;;
  esac
  # Windows-native managers are also worth finding from WSL (they're callable via
  # interop as winget.exe / scoop / choco.exe) but we do NOT use them from WSL:
  # installing a Windows package won't put tmux inside the WSL distro.
  printf '%s\n' "$_AMUX_PKGMGR"
}

# Does this package manager need elevated rights?
amux_pkgmgr_needs_admin() {
  case "$(amux_pkgmgr)" in
    apt|dnf|pacman|zypper|apk|port|choco) return 0 ;;
    brew|scoop|winget|msys2|none)         return 1 ;;
  esac
  return 1
}

# The literal command a human would type to install <pkg> here. Printed in
# guidance so a student can run it themselves when we won't (or can't) auto-install.
amux_pkg_install_cmd() { # $1 = package name
  local pkg="$1"
  case "$(amux_pkgmgr)" in
    brew)   printf 'brew install %s\n' "$pkg" ;;
    port)   printf 'sudo port install %s\n' "$pkg" ;;
    apt)    printf 'sudo apt-get install -y %s\n' "$pkg" ;;
    dnf)    printf 'sudo dnf install -y %s\n' "$pkg" ;;
    pacman) printf 'sudo pacman -S --noconfirm %s\n' "$pkg" ;;
    zypper) printf 'sudo zypper install -y %s\n' "$pkg" ;;
    apk)    printf 'sudo apk add %s\n' "$pkg" ;;
    msys2)  printf 'pacman -S --noconfirm %s\n' "$pkg" ;;
    scoop)  printf 'scoop install %s\n' "$pkg" ;;
    winget) printf 'winget install %s\n' "$pkg" ;;
    choco)  printf 'choco install -y %s\n' "$pkg" ;;
    *)      printf '(no package manager detected — install %s manually)\n' "$pkg" ;;
  esac
}

# Actually install. Returns non-zero (without exiting) so callers can degrade
# gracefully — a missing optional package should never abort a whole setup run.
amux_pkg_install() { # $1 = package name
  local pkg="$1" mgr; mgr=$(amux_pkgmgr)
  [ "$mgr" = none ] && { amux_warn "no package manager detected; install '$pkg' manually"; return 1; }
  amux_info "installing $pkg via $mgr…"
  case "$mgr" in
    brew)   brew install "$pkg" ;;
    port)   sudo port install "$pkg" ;;
    apt)    sudo apt-get update -qq && sudo apt-get install -y "$pkg" ;;
    dnf)    sudo dnf install -y "$pkg" ;;
    pacman) sudo pacman -S --noconfirm "$pkg" ;;
    zypper) sudo zypper install -y "$pkg" ;;
    apk)    sudo apk add "$pkg" ;;
    msys2)  pacman -S --noconfirm "$pkg" ;;
    scoop)  scoop install "$pkg" ;;
    winget) winget install --accept-package-agreements --accept-source-agreements "$pkg" ;;
    choco)  choco install -y "$pkg" ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Downloader
#
# curl is present on macOS, most Linux, AND native Windows 10 1803+ — but not
# on a minimal Debian or Alpine, where wget is the one that's there. Under
# PowerShell-only environments neither may be on the bash PATH.
# ─────────────────────────────────────────────────────────────────────────────
amux_downloader() {
  [ -n "${_AMUX_DL:-}" ] && { printf '%s\n' "$_AMUX_DL"; return; }
  if   amux_have curl;       then _AMUX_DL=curl
  elif amux_have wget;       then _AMUX_DL=wget
  elif amux_have powershell.exe || amux_have pwsh; then _AMUX_DL=powershell
  else _AMUX_DL=none
  fi
  printf '%s\n' "$_AMUX_DL"
}

# amux_fetch <url> <dest> — download to a file. Returns non-zero on failure.
amux_fetch() {
  local url="$1" dest="$2"
  case "$(amux_downloader)" in
    curl) curl -fsSL -o "$dest" "$url" ;;
    wget) wget -qO "$dest" "$url" ;;
    powershell)
      local ps; ps=$(amux_have pwsh && echo pwsh || echo powershell.exe)
      "$ps" -NoProfile -Command \
        "Invoke-WebRequest -UseBasicParsing -Uri '$url' -OutFile '$dest'" ;;
    *) amux_warn "no downloader (curl/wget/powershell) available"; return 1 ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Paths and config
#
# CC_HOME mirrors amux's own env var so a student who has moved ~/.amux keeps
# one source of truth instead of two directories drifting apart.
# ─────────────────────────────────────────────────────────────────────────────
amux_home()        { printf '%s\n' "${CC_HOME:-$HOME/.amux}"; }
amux_remotes_dir() { printf '%s\n' "$(amux_home)/remotes"; }
amux_sessions_dir(){ printf '%s\n' "$(amux_home)/sessions"; }

# Space-separated names of configured boxes. MUST NOT fail on a fresh install:
# under `set -euo pipefail`, a bare `ls` of a missing dir would abort the caller
# mid-usage() and print nothing at all — which reads as a broken program.
amux_list_boxes() {
  local d; d=$(amux_remotes_dir)
  [ -d "$d" ] || return 0
  ls "$d" 2>/dev/null | sed -n 's/\.env$//p' | tr '\n' ' ' || true
}

amux_box_env_path() { printf '%s\n' "$(amux_remotes_dir)/$1.env"; }
amux_box_exists()   { [ -f "$(amux_box_env_path "$1")" ]; }

# Load a box's config into the environment. Sourcing is intentional: the file is
# `KEY=value` shell, mode 600, written only by amux-config.
amux_load_box() { # $1 = box name
  local f; f=$(amux_box_env_path "$1")
  [ -f "$f" ] || return 1
  # shellcheck disable=SC1090
  . "$f"
  AMUX_URL="${AMUX_URL%/}"   # strip trailing slash so path joins stay clean
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Secret handling
#
# The one hard rule: a token's VALUE never reaches stdout, argv, or a log.
#   - argv is world-readable via `ps` while the process runs
#   - stdout ends up in scrollback, transcripts, and CI logs
# So secrets move over STDIN or via a mode-600 file, and are only ever
# summarized as prefix+length.
# ─────────────────────────────────────────────────────────────────────────────

# Create/replace a file with mode 600, content read from STDIN. The umask is set
# BEFORE the file is created so there is no window where it exists world-readable.
amux_write_secret_file() { # $1 = path; content on stdin
  local path="$1" dir; dir=$(dirname "$path")
  mkdir -p "$dir" && chmod 700 "$dir" 2>/dev/null || true
  ( umask 077; cat > "$path" )
  chmod 600 "$path" 2>/dev/null || true
}

# Safe-to-print summary of a secret: a SHORT prefix + length, never the value.
# 4 characters is enough to tell two tokens apart after a rotation, and little
# enough that pasting this output into a bug report or screenshot costs nothing.
amux_secret_summary() { # secret on stdin
  local s; s=$(cat)
  if [ -z "$s" ]; then printf 'EMPTY\n'; else
    printf '%s… (%d chars)\n' "$(printf '%s' "$s" | cut -c1-4)" "${#s}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# HTTP against a box's amux server
#
# -k because amux serves a self-signed cert by default. The token goes in a
# header read from a FILE DESCRIPTOR, never `-H "Bearer $TOK"` — that form puts
# the live token in the process table for anyone running `ps`.
# ─────────────────────────────────────────────────────────────────────────────
amux_api() { # $1 = METHOD, $2 = path, rest = extra curl args. Needs AMUX_URL/AMUX_TOKEN.
  local method="$1" path="$2"; shift 2
  [ -n "${AMUX_URL:-}" ]   || { amux_warn "AMUX_URL not set"; return 1; }
  [ -n "${AMUX_TOKEN:-}" ] || { amux_warn "AMUX_TOKEN not set"; return 1; }
  printf 'Authorization: Bearer %s\n' "$AMUX_TOKEN" | \
    curl -sk -X "$method" -H @- "$@" "${AMUX_URL}${path}"
}

# Reachability probe: prints the HTTP status code, or 000 when unreachable.
#
# NOTE: on a connection failure curl BOTH writes "000" via -w AND exits non-zero.
# Chaining `|| printf '000'` therefore emits "000000", which no caller matches —
# so a dead box reads as an unrecognized status instead of "unreachable". Capture
# first, then substitute only when the output is genuinely empty.
amux_api_code() { # $1 = path (default /)
  local path="${1:-/}" out
  [ -n "${AMUX_URL:-}" ] || { printf '000\n'; return 1; }
  out=$(printf 'Authorization: Bearer %s\n' "${AMUX_TOKEN:-}" | \
    curl -sk -o /dev/null -w '%{http_code}' --max-time "${AMUX_TIMEOUT:-10}" \
      -H @- "${AMUX_URL}${path}" 2>/dev/null)
  printf '%s\n' "${out:-000}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Python
#
# python3 is already a hard dependency (amux's server is a Python program), so we
# lean on it rather than requiring jq — one less thing for a student to install.
# Falls back to `python` for systems where that is the 3.x interpreter.
# ─────────────────────────────────────────────────────────────────────────────
amux_python() {
  if   amux_have python3; then printf 'python3\n'
  elif amux_have python;  then printf 'python\n'
  else return 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Session rendering lives in lib/amux-render.py, NOT here.
#
# Both amux-ls (this machine) and amux-remote (another machine) pipe the raw
# /api/sessions JSON into that one program. Keeping a second renderer in this
# library is how the local and remote views silently drift apart, so there
# deliberately is not one.
# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# tmux capability probe — the heart of amux-doctor on Windows.
#
# "Is tmux installed" is NOT the question. MSYS2's tmux and Scoop's psmux both
# exist but may not implement the specific calls amux makes. So we RUN them
# against a throwaway session and report what actually worked.
# ─────────────────────────────────────────────────────────────────────────────
amux_probe_tmux() {
  # Prints one "PASS <call>" / "FAIL <call>" line per probed capability.
  # Returns 0 only if every probe passed.
  amux_have tmux || { printf 'FAIL tmux-present\n'; return 1; }
  printf 'PASS tmux-present\n'

  local s="amuxprobe$$" rc=0
  # -d detached, -s named. If this fails nothing else can work.
  if tmux new-session -d -s "$s" 2>/dev/null; then
    printf 'PASS new-session\n'
  else
    printf 'FAIL new-session\n'; return 1
  fi

  tmux has-session   -t "$s" 2>/dev/null   && printf 'PASS has-session\n'   || { printf 'FAIL has-session\n';   rc=1; }
  tmux list-sessions -F '#{session_name}' >/dev/null 2>&1 \
                                           && printf 'PASS list-sessions\n' || { printf 'FAIL list-sessions\n'; rc=1; }
  tmux send-keys -t "$s" "echo amuxprobe" Enter 2>/dev/null \
                                           && printf 'PASS send-keys\n'     || { printf 'FAIL send-keys\n';     rc=1; }
  # capture-pane is the one amux leans on hardest (peek, the auth watchdog,
  # every dashboard row) and the most likely to be missing in a reimplementation.
  if tmux capture-pane -pt "$s" >/dev/null 2>&1; then
    printf 'PASS capture-pane\n'
  else
    printf 'FAIL capture-pane\n'; rc=1
  fi
  # set-environment / show-environment: how a session inherits auth.
  tmux set-environment  -t "$s" AMUX_PROBE 1 2>/dev/null \
                                           && printf 'PASS set-environment\n' || { printf 'FAIL set-environment\n'; rc=1; }

  tmux kill-session -t "$s" 2>/dev/null || true
  return $rc
}
