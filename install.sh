#!/usr/bin/env bash
# install.sh — install amux (this repo's modified build) and its companion commands.
#
#   ./install.sh                  install or update everything into ~/.local/bin
#   ./install.sh --client         companions + amux-remote only (drive other machines,
#                                 run no sessions here)
#   ./install.sh --statusline     also set up the amux status line in Claude Code
#                                 (backs up ~/.claude/settings.json; see docs/statusline.md)
#   ./install.sh --uninstall      remove the symlinks we created (core copies stay)
#   ./install.sh --show-config    print where things would go; change nothing
#
# Two classes of files:
#   CORE        amux, amux-server.py, amux-remote — COPIED into the core dir.
#               Copied, not symlinked, on purpose: amux-server.py watches its own
#               file and exits to reload, so a symlink into this checkout would
#               swap code under the running dashboard on every `git pull`.
#               Updating is an explicit step:  git pull && ./install.sh
#   COMPANIONS  everything else in bin/ — symlinked, so they find lib/ in this
#               checkout. Keep the checkout where it is.
#
# Settings (environment, or ~/.config/amux/install.conf):
#   BINDIR=<dir>            companion dir (default ~/.local/bin)
#   AMUX_CORE_BINDIR=<dir>  core dir (default: same as BINDIR). Use a system dir
#                           such as /usr/local/bin only if you run amux as a system
#                           service that cannot execute from your home directory.
#   AMUX_ROLE=full|client   same as --client
#   AMUX_NO_COMPLETION=1    do not add tab completion to ~/.zshrc / ~/.bashrc
#
# After installing, run:  amux-doctor
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
CORE=(amux amux-server.py amux-remote)

# Environment overrides win over the optional local config.
_env_core_set="${AMUX_CORE_BINDIR+x}"; _env_core="${AMUX_CORE_BINDIR-}"
_env_bindir_set="${BINDIR+x}";         _env_bindir="${BINDIR-}"
_env_role_set="${AMUX_ROLE+x}";        _env_role="${AMUX_ROLE-}"
INSTALL_CONFIG="${AMUX_INSTALL_CONFIG-$HOME/.config/amux/install.conf}"
if [ -f "$INSTALL_CONFIG" ]; then
  # shellcheck disable=SC1090
  . "$INSTALL_CONFIG"
fi
[ "$_env_core_set" = x ] && AMUX_CORE_BINDIR="$_env_core"
[ "$_env_bindir_set" = x ] && BINDIR="$_env_bindir"
[ "$_env_role_set" = x ] && AMUX_ROLE="$_env_role"

MODE=install
ROLE=full
STATUSLINE=0
[ -n "${AMUX_ROLE-}" ] && ROLE="$AMUX_ROLE"
while [ $# -gt 0 ]; do
  case "$1" in
    --client)      ROLE=client ;;
    --statusline)  STATUSLINE=1 ;;
    --uninstall)   MODE=uninstall ;;
    --show-config) MODE=show ;;
    -h|--help)     awk 'NR==1&&/^#!/{next} /^#/{sub(/^# ?/,"");print;next} {exit}' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

BIN="$HOME/.local/bin"
[ -n "${BINDIR-}" ] && BIN="$BINDIR"
CORE_BINDIR="$BIN"
[ -n "${AMUX_CORE_BINDIR-}" ] && CORE_BINDIR="$AMUX_CORE_BINDIR"
case "$ROLE" in
  full|server) CORE_SKIP=0 ;;
  client)      CORE_SKIP=1 ;;
  *) echo "invalid role '$ROLE' (expected full or client)" >&2; exit 2 ;;
esac

is_core() {
  local b="$1" c
  for c in "${CORE[@]}"; do [ "$b" = "$c" ] && return 0; done
  return 1
}

if [ "$MODE" = show ]; then
  echo "companion dir: $BIN"
  echo "core dir:      $CORE_BINDIR"
  echo "role:          $ROLE"
  exit 0
fi

if [ "$MODE" = uninstall ]; then
  # Unwire the status line first, or Claude Code would be left pointing at a removed file.
  if [ -L "$BIN/amux-statusline" ] && [ "$(readlink "$BIN/amux-statusline")" = "$here/bin/amux-statusline" ]; then
    "$BIN/amux-statusline" --uninstall || true
  fi
  n=0
  for f in "$here"/bin/*; do
    l="$BIN/$(basename "$f")"
    # Only remove what we created: a symlink pointing back at this checkout.
    if [ -L "$l" ] && [ "$(readlink "$l")" = "$f" ]; then
      rm -f "$l"; echo "  removed $(basename "$f")"; n=$((n+1))
    fi
  done
  echo "uninstalled $n symlinks from $BIN (core copies in $CORE_BINDIR left in place)"
  exit 0
fi

mkdir -p "$BIN"

# ── core ─────────────────────────────────────────────────────────────────────
core_changed=0
if [ "$CORE_SKIP" = 1 ]; then
  echo "core: skipped (client-only role)"
else
  SUDO=""
  if [ ! -d "$CORE_BINDIR" ] && ! mkdir -p "$CORE_BINDIR" 2>/dev/null; then
    command -v sudo >/dev/null 2>&1 || { echo "cannot create $CORE_BINDIR" >&2; exit 1; }
    sudo mkdir -p "$CORE_BINDIR"
  fi
  if [ ! -w "$CORE_BINDIR" ]; then
    command -v sudo >/dev/null 2>&1 || { echo "$CORE_BINDIR is not writable and sudo is unavailable" >&2; exit 1; }
    SUDO="sudo"
  fi
  for c in "${CORE[@]}"; do
    src="$here/bin/$c"
    [ -f "$src" ] || { echo "  MISSING in repo: bin/$c" >&2; exit 1; }
    dst="$CORE_BINDIR/$c"
    if [ -L "$dst" ]; then $SUDO rm -f "$dst"; fi        # replace an old symlink with a copy
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
      echo "  core $c: up to date"
    else
      $SUDO cp "$src" "$dst.tmp.$$" && $SUDO chmod 755 "$dst.tmp.$$" && $SUDO mv -f "$dst.tmp.$$" "$dst"
      echo "  core $c: installed -> $dst"
      [ "$c" = amux-server.py ] && core_changed=1
    fi
  done
fi

# ── companions (symlinks) ────────────────────────────────────────────────────
n=0
for f in "$here"/bin/*; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  if is_core "$b"; then
    # amux-remote doubles as the client tool: on a client-only install (or when
    # the core lives elsewhere) it is symlinked like any companion.
    [ "$b" = amux-remote ] || continue
    if [ "$CORE_SKIP" = 0 ] && [ "$CORE_BINDIR" = "$BIN" ]; then continue; fi
  fi
  chmod +x "$f"
  ln -sf "$f" "$BIN/$b"
  n=$((n + 1))
done
chmod +x "$here"/lib/*.py 2>/dev/null || true
echo "linked $n companion commands into $BIN"

# ── status line (opt-in) ─────────────────────────────────────────────────────
# Never automatic: it edits ~/.claude/settings.json, and refuses to replace a status
# line you already have unless you run  amux-statusline --install --force  yourself.
if [ "$STATUSLINE" = 1 ]; then
  "$BIN/amux-statusline" --install || echo "  status line: not installed (see above)" >&2
fi

# ── Linux: keep tmux alive when the amux-serve service restarts ──────────────
# amux-server.py starts the tmux server, so tmux and EVERY agent session can be
# born inside the amux-serve unit's cgroup. With systemd's default
# KillMode=control-group a `systemctl restart amux-serve` kills all of them.
# The drop-in sets KillMode=process. This never creates a unit and never
# restarts anything: it only adds the drop-in where a unit already exists.
DROPIN_SRC="$here/systemd/amux-serve.service.d/10-keep-tmux.conf"
if [ "$CORE_SKIP" = 0 ] && [ "$(uname -s 2>/dev/null)" = Linux ] && command -v systemctl >/dev/null 2>&1; then
  # per-user unit (what setup/serve-install creates) — no sudo needed
  if [ -f "$HOME/.config/systemd/user/amux-serve.service" ]; then
    ud="$HOME/.config/systemd/user/amux-serve.service.d"
    if ! cmp -s "$DROPIN_SRC" "$ud/10-keep-tmux.conf" 2>/dev/null; then
      mkdir -p "$ud" && cp "$DROPIN_SRC" "$ud/10-keep-tmux.conf"
      systemctl --user daemon-reload 2>/dev/null || true
      echo "  user unit: KillMode=process drop-in installed (no restart done)"
    fi
  fi
  # system unit, if you run one — needs passwordless sudo, else just warns
  if [ "$(systemctl show amux-serve.service -p LoadState --value 2>/dev/null || true)" = loaded ]; then
    sd=/etc/systemd/system/amux-serve.service.d
    if [ -f "$sd/10-keep-tmux.conf" ] && cmp -s "$DROPIN_SRC" "$sd/10-keep-tmux.conf"; then :
    elif sudo -n true >/dev/null 2>&1; then
      sudo install -d -m 0755 "$sd" && sudo install -m 0644 "$DROPIN_SRC" "$sd/10-keep-tmux.conf" \
        && sudo systemctl daemon-reload && echo "  system unit: KillMode=process drop-in installed (no restart done)"
    else
      echo "  WARNING: a system amux-serve unit exists but sudo needs a password; install" >&2
      echo "           $DROPIN_SRC into $sd yourself, or a restart will kill your sessions" >&2
    fi
  fi
fi

# ── tab completion ───────────────────────────────────────────────────────────
# Written to ~/.amux/completion.{zsh,bash} and sourced by ONE marked line at the
# end of ~/.zshrc / ~/.bashrc (end, so it lands after any compinit). The line is
# guarded by [ -f ], so deleting the file disables it. Opt out: AMUX_NO_COMPLETION=1
if [ "$CORE_SKIP" = 0 ] && [ "${AMUX_NO_COMPLETION-0}" != 1 ]; then
  COMP_DIR="$HOME/.amux"; mkdir -p "$COMP_DIR"
  COMP_MARK="# amux tab-completion (added by amux install.sh)"
  for sh in zsh bash; do
    if bash "$here/bin/amux" completion "$sh" > "$COMP_DIR/completion.$sh.new" 2>/dev/null; then
      mv -f "$COMP_DIR/completion.$sh.new" "$COMP_DIR/completion.$sh"
    else
      rm -f "$COMP_DIR/completion.$sh.new"; echo "  WARNING: could not generate $sh completion" >&2; continue
    fi
    rc="$HOME/.${sh}rc"
    case "$sh" in
      zsh)  line="[ -f ~/.amux/completion.zsh ] && source ~/.amux/completion.zsh  $COMP_MARK" ;;
      bash) line="[[ \$- == *i* && -f ~/.amux/completion.bash ]] && source ~/.amux/completion.bash  $COMP_MARK" ;;
    esac
    if [ -f "$rc" ] || [ "${SHELL##*/}" = "$sh" ]; then
      if grep -qF "$COMP_MARK" "$rc" 2>/dev/null; then
        echo "  completion: $sh already set up ($rc)"
      else
        printf '\n%s\n' "$line" >> "$rc"
        echo "  completion: $sh added (one line appended to $rc; open a new shell)"
      fi
    fi
  done
fi

case ":$PATH:" in
  *":$BIN:"*) ;;
  *)
    echo
    echo "NOTE: $BIN is not on your PATH. Add it:"
    case "${SHELL##*/}" in
      zsh)  echo "  echo 'export PATH=\"$BIN:\$PATH\"' >> ~/.zshrc && exec zsh" ;;
      bash) echo "  echo 'export PATH=\"$BIN:\$PATH\"' >> ~/.bashrc && exec bash" ;;
      *)    echo "  export PATH=\"$BIN:\$PATH\"   (add to your shell's rc file)" ;;
    esac ;;
esac

if [ "$core_changed" = 1 ]; then
  cat <<'EON'

NOTE: amux-server.py changed. If the dashboard is already running, restart it:
  Linux:  systemctl --user restart amux-serve
  macOS:  launchctl kickstart -k gui/$(id -u)/com.amux-nuilab.serve
  (or just run setup/serve-install again)
EON
fi
echo
echo "Next:  amux-doctor        # check what this machine can do"
echo "       setup/bootstrap    # install anything it says is missing"
