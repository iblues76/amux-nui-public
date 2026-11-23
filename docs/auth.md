# How Claude Code authenticates, and why it decides what you can do

There are two ways to sign in to Claude Code, and they are not interchangeable. A long-lived token works over SSH but turns browser control off. `/login` allows browser control, but it expires and cannot be completed over SSH. Choosing the wrong one for a machine is a common cause of trouble when you use several machines.

## The two modes

| | `/login` (interactive) | Long-lived token |
|---|---|---|
| How you set it up | Run `claude`, sign in through a browser | `claude setup-token`, then set `CLAUDE_CODE_OAUTH_TOKEN` |
| Where the credential lives | `~/.claude/.credentials.json`, and the macOS Keychain | An environment variable, usually from a mode-600 file |
| Lifetime | About 8 hours, refreshed automatically | Long-lived |
| Works over SSH with no browser | **No** | **Yes** |
| Claude in Chrome / browser control | **Yes** | **No**, on purpose |
| Good for | Your own desktop or laptop | Servers, machines without a screen, and anything you drive remotely |

## Why browser control only works with `/login`

This is intentional. The [Claude Code documentation](https://code.claude.com/docs/en/chrome) says:

> Chrome integration also requires signing in with `/login`. If you authenticate with an API key or a long-lived token from `claude setup-token`, Claude Code keeps Chrome integration off, even when you pass `--chrome`, because the browser extension can't authenticate with those credentials.

So on a machine with a token in its environment, `/chrome` reports `Status: Disabled` even when the extension is installed correctly. Nothing is broken. Claude Code is working as designed.

The same page says that this changed recently, so it may have behaved differently for you before:

> Before v2.1.216, these sessions could enable Chrome integration, but every attempt to connect to the browser extension failed with a 403 error.

Before that version, Chrome integration seemed to be on and then failed at the first browser action. Now Claude Code says at once that it is off.

There is one more limit, which matters on Windows. Chrome integration [is not supported in WSL](https://code.claude.com/docs/en/chrome). Someone who runs amux inside WSL cannot use browser control from those sessions, however they signed in. See [windows.md](windows.md).

## When a machine has both

This problem is the hardest one to diagnose, because the error does not point to its cause.

If a machine has both a long-lived token in its environment and a stored browser login, interactive sessions use the stored login, and they do not fall back to the token when the login expires. About 8 hours after that browser login, every session on the machine stops at `Please run /login · 401 OAuth access token has expired`, although the token in the environment is still valid.

Signing in through the browser again makes the sessions work for another 8 hours, and then they stop again. That is why the problem seems to come back at random.

The obvious check is misleading. `claude -p` falls back from one credential store to the other without saying so, so it can succeed with a credential that your interactive sessions never use.

To see which credential is really in use, run `check-claude-auth`. It tests the token directly against the API with curl, and it separately detects a stored login that shadows the token. `amux-doctor` reports this condition too.

To fix it, keep one of the two:

- To keep the token, which is right for a machine without a screen or one that you drive remotely, run `claude auth logout` and restart the sessions. `amux-reauth --all` does both.
- To keep `/login`, which is right for the machine you sit at and where you want browser control, remove `CLAUDE_CODE_OAUTH_TOKEN` from your shell environment and restart the sessions.

## Which one to use

- On one computer that you sit in front of, use `/login`. You get browser control and need no tokens.
- On a machine that you drive over SSH, or that runs unattended, use a long-lived token. `/login` cannot be completed over SSH, because there is no way to paste the browser's reply back into the pane.
- If you have both kinds of machine, use `/login` on the one you sit at and tokens on the rest. Do not put a token on the machine where you want browser control.

## Setting up a long-lived token safely

```sh
claude setup-token          # prints a token
```

Put it in a mode-600 file, and source that file from your shell rc. Paste the token at a silent prompt, so that it never appears in your shell history or on a command line:

```sh
umask 077; mkdir -p ~/.config/claude-code
printf 'Paste the token: '; IFS= read -rs TOK; echo
printf 'export CLAUDE_CODE_OAUTH_TOKEN=%s\nexport CLAUDE_ACCOUNT=personal\n' "$TOK" > ~/.config/claude-code/env
unset TOK; chmod 600 ~/.config/claude-code/env
echo '. ~/.config/claude-code/env' >> ~/.zshrc     # or ~/.bashrc
```

If you use more than one subscription, for example a personal plan and a team seat, see [accounts.md](accounts.md).

Never put a token on a command line that you type or put in a script (`--token abc123`, `curl -H "Bearer $TOK"`). Every user on the machine can see a command line through `ps` while it runs, and it stays in your shell history. That is why `amux-config` has no `--token` flag, only `--token-stdin` and `--from-ssh`.

Two more things to know:

- A change to the environment reaches only new processes. Sessions that are already running keep their old credential until you restart them.
- amux starts sessions through a non-interactive shell, which does not read `~/.bashrc`. If sessions do not see the token, that is the usual reason. `amux-doctor` checks for it.

## A 401 that is not an auth problem

If a session shows `Please run /login · API Error: 401 The socket connection was closed unexpectedly`, the network failed, and Claude Code reports it as a sign-in error. The credential is fine, and signing in again does not help. Wait for the connection to come back, and send the prompt again.

To tell the two apart, read the message. A real sign-in failure says `OAuth access token has expired` or `Invalid authentication credentials`. `amux-reauth` makes the same distinction and does nothing for the socket error.
