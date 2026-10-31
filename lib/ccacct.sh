# ccacct.sh — switch which Claude subscription THIS terminal uses. Source it:
#
#     . ~/path/to/amux-nui-public/lib/ccacct.sh      (add to ~/.zshrc or ~/.bashrc)
#
# Then:
#     ccacct                     show this terminal's account
#     ccacct team                switch this terminal to the team slot (also: personal, team2, P, T, X)
#     ccrun team2 <cmd...>       run ONE command on another account, terminal unchanged
#
# Each account is a mode-600 "slot" file holding a long-lived token from
# `claude setup-token` (see docs/accounts.md):
#     personal (P)  ~/.config/claude-code/env
#     team     (T)  ~/.config/claude-code/env.team
#     team2    (X)  ~/.config/claude-code/env.team2
#
# New amux sessions started from this terminal inherit its account unless you
# pass --account. Nothing here ever prints a token.
# shellcheck shell=bash

_ccacct_norm() {
  case "$1" in
    p|P|personal) printf 'personal' ;;
    t|T|team)     printf 'team' ;;
    x|X|team2|t2) printf 'team2' ;;
    *) return 1 ;;
  esac
}

_ccacct_slot() {
  local f="$HOME/.config/claude-code/env"
  case "$1" in team) f="$f.team" ;; team2) f="$f.team2" ;; esac
  printf '%s' "$f"
}

ccacct() {
  if [ $# -eq 0 ]; then
    if [ -n "${CLAUDE_ACCOUNT-}" ]; then printf 'this terminal: %s\n' "$CLAUDE_ACCOUNT"
    elif [ -n "${CLAUDE_CODE_OAUTH_TOKEN-}" ]; then printf 'this terminal: a token with no account label (treated as personal)\n'
    else printf 'this terminal: no token — claude uses its own /login\n'; fi
    return 0
  fi
  local acct slot
  acct=$(_ccacct_norm "$1") || { echo "usage: ccacct [personal|team|team2]  (or P|T|X)" >&2; return 2; }
  slot=$(_ccacct_slot "$acct")
  if [ ! -f "$slot" ]; then
    if [ "$acct" = personal ]; then
      # No personal slot = this machine uses claude's own /login for personal.
      unset CLAUDE_CODE_OAUTH_TOKEN
      export CLAUDE_ACCOUNT=personal
      echo "this terminal: personal (claude /login — no token slot on this machine)"
      return 0
    fi
    echo "ccacct: no $acct slot at $slot — see docs/accounts.md" >&2
    return 1
  fi
  # shellcheck disable=SC1090
  . "$slot" || return 1
  export CLAUDE_ACCOUNT="$acct"
  echo "this terminal: $acct"
}

ccrun() {
  [ $# -ge 2 ] || { echo "usage: ccrun <personal|team|team2> <command...>" >&2; return 2; }
  local acct="$1"; shift
  ( ccacct "$acct" >/dev/null && exec "$@" )
}
