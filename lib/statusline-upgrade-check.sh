#!/bin/bash
# Detect a PENDING Claude Code upgrade and cache a short label in ~/.claude/.upgrade-flag,
# which amux-statusline reads (cheaply) and renders. This script may hit the network, so
# amux-statusline runs it DETACHED + THROTTLED (<= every 2h) — never inline.
# Manager-aware:
#   - Homebrew cask  -> "Brew:U"  (brew does NOT auto-update; needs `brew upgrade --cask claude-code`)
#   - npm global     -> "npm:U"   (needs `npm i -g @anthropic-ai/claude-code@latest`)
#   - native installer -> ""      (it self-updates; the "restart to apply" hint is inline in amux-statusline)
export PATH="/opt/homebrew/bin:/usr/local/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:$PATH"
FLAG="$HOME/.claude/.upgrade-flag"
label=""
if command -v brew >/dev/null 2>&1 && brew list --cask claude-code >/dev/null 2>&1; then
  if brew outdated --cask claude-code 2>/dev/null | grep -qi 'claude-code'; then label="Brew:U"; fi
elif command -v npm >/dev/null 2>&1 && npm ls -g @anthropic-ai/claude-code >/dev/null 2>&1; then
  npm outdated -g @anthropic-ai/claude-code >/dev/null 2>&1 || label="npm:U"   # npm outdated exits 1 when stale
fi
printf '%s' "$label" > "$FLAG"
