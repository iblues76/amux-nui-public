# How Claude Code authenticates, and why it decides what you can do

There are two ways to sign Claude Code in, and picking the wrong one is the single most confusing failure in a multi-machine setup. They are not interchangeable: one works over SSH but disables browser control, the other enables browser control but expires and cannot be completed over SSH.

## The two modes

| | `/login` (interactive) | Long-lived token |
|---|---|---|
| How you set it up | Run `claude`, sign in through a browser | `claude setup-token`, then set `CLAUDE_CODE_OAUTH_TOKEN` |
| Where the credential lives | `~/.claude/.credentials.json`, and the macOS Keychain | An environment variable, usually from a mode-600 file |
| Lifetime | Roughly 8 hours, silently auto-refreshed | Long-lived |
| Works over SSH with no browser | **No** | **Yes** |
| Claude in Chrome / browser control | **Yes** | **No — deliberately off** |
| Good for | Your own desktop or laptop | Headless boxes, servers, anything you drive remotely |

## Why browser control only works with `/login`

This is the part that trips everyone up, and it is intentional. From the [official docs](https://code.claude.com/docs/en/chrome):

> Chrome integration also requires signing in with `/login`. If you authenticate with an API key or a long-lived token from `claude setup-token`, Claude Code keeps Chrome integration off, even when you pass `--chrome`, because the browser extension can't authenticate with those credentials.

So on a machine with a token in its environment, `/chrome` reports `Status: Disabled` even with the extension correctly installed. That is the feature working as designed, not a broken setup.

The same page notes this changed recently, which explains why it may have behaved differently before:

> Before v2.1.216, these sessions could enable Chrome integration, but every attempt to connect to the browser extension failed with a 403 error.

In other words, it used to *look* like it worked and then fail at the first browser action. Now it tells you up front.

**One more limit, and it matters for Windows:** Chrome integration [is not supported in WSL](https://code.claude.com/docs/en/chrome) at all. A Windows student running amux inside WSL cannot use browser control from those sessions regardless of how they authenticated. See [windows.md](windows.md).

## The trap: having both at once

This is the failure that looks like a mystery and wastes a day.

If a machine has **both** a long-lived token in its environment **and** a stored browser login, interactive sessions prefer the stored login — and they do **not** fall back to the token when it expires. So roughly 8 hours after that browser login, every session on the machine parks at `Please run /login · 401 OAuth access token has expired`, even though the token sitting right there in the environment is perfectly valid.

A fresh browser login "fixes" it for exactly one more expiry cycle, which is what makes it feel recurring and random.

Worse, the obvious way to check is misleading: `claude -p` silently falls back between credential stores, so it can print a cheerful success using a credential your interactive sessions never touch.

**Verify auth honestly** with `check-claude-auth`, which probes the token directly against the API with curl and separately detects a shadowing login. Or run `amux-doctor`, which flags the both-at-once condition explicitly.

**Fix it by picking one:**

- Keeping the token (right for a headless or remotely-driven box): `claude auth logout`, then restart the sessions. `amux-reauth --all` does that whole sequence.
- Keeping `/login` (right for your daily-driver machine where you want browser control): remove `CLAUDE_CODE_OAUTH_TOKEN` from your shell environment, then restart the sessions.

## Which should you use?

- **One computer, sitting in front of it** → `/login`. You get browser control and never think about tokens.
- **A machine you drive over SSH, or that runs unattended** → long-lived token. `/login` cannot be completed over SSH anyway: there is no way to paste the browser callback back into the pane.
- **Both kinds of machine** → use `/login` on the one you sit at, tokens on the rest. Do not put a token on the machine where you want browser control.

## Setting up a long-lived token safely

```sh
claude setup-token          # prints a token
```

Put it in a mode-600 file and source that from your shell rc. Paste it at a silent prompt so it never lands in your shell history or on a command line:

```sh
umask 077; mkdir -p ~/.config/claude-code
printf 'Paste the token: '; IFS= read -rs TOK; echo
printf 'export CLAUDE_CODE_OAUTH_TOKEN=%s\nexport CLAUDE_ACCOUNT=personal\n' "$TOK" > ~/.config/claude-code/env
unset TOK; chmod 600 ~/.config/claude-code/env
echo '. ~/.config/claude-code/env' >> ~/.zshrc     # or ~/.bashrc
```

Using more than one subscription (a personal plan plus a team seat, say)? See [accounts.md](accounts.md).

**Never** put a token on a command line you type or script (`--token abc123`, `curl -H "Bearer $TOK"`). Anything on a command line is visible to every user on the machine through `ps` while it runs, and it lands in your shell history permanently. That is why `amux-config` has no `--token` flag at all — only `--token-stdin` and `--from-ssh`.

Two more things that bite:

- **The environment only reaches new processes.** Sessions already running keep their old, dead credential until restarted.
- **amux launches sessions through a non-interactive shell**, which does not read `~/.bashrc`. If sessions do not see the token, that is usually why — check with `amux-doctor`.

## A 401 that is not an auth problem

If a session shows `Please run /login · API Error: 401 The socket connection was closed unexpectedly`, that is a **network** failure that Claude Code mislabels as an auth error. The credential is fine. Re-logging in does not fix it and only churns your credentials; wait for the connection to recover and re-send.

Tell the two apart: a real auth failure says `OAuth access token has expired` or `Invalid authentication credentials`. `amux-reauth` already makes this distinction and refuses to act on the socket-close variant.
