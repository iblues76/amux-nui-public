# Troubleshooting

Start with `amux-doctor`. It checks the machine end to end and most of what follows is a longer explanation of something it already told you.

## Sessions say "Please run /login"

**First, read the rest of the error.** Two very different problems share that banner.

`401 The socket connection was closed unexpectedly` is a **network** failure mislabelled as an auth failure. Your credentials are fine. Logging in again does not help and only churns your credential store. Wait for the connection to recover, then re-send.

`OAuth access token has expired` or `Invalid authentication credentials` is a real auth failure. Usually it is the shadowing trap: a stored browser login and a long-lived token on the same machine, where sessions prefer the login and do not fall back when it expires. See [auth.md](auth.md). Fix:

```sh
check-claude-auth        # says honestly which credential is in play
amux-reauth --all        # probe, clear a shadowing login, restart what is stuck
```

## A session shows as running after I stopped it

Fixed in the bundled amux: the session list now checks that the agent is actually running in the pane, not just that a tmux session exists. If you still see it, an older amux is probably first on your `PATH` — `amux-doctor` says which build it found; re-run `./install.sh`.

## A session lost all its context after restarting

Also fixed in the bundled amux: when it cannot tell which conversation to resume, it resumes the newest real conversation for the session's directory instead of starting a blank one. Older conversations are never deleted — use `amux-convos <session>` to list them and `amux-convos <session> --resume N` to pick one.

## A session dies about 3 seconds after `amux start`

Usually a Claude Code **background** session (`claude --bg`, or "Backgrounding after the current tool finishes…") still holds the newest conversation for that directory, and claude refuses to resume a conversation another process holds. The bundled amux skips held conversations and says which one it skipped; `claude agents` lists the holders, and `claude stop <id>` releases one.

## A machine shows UNREACHABLE

```sh
amux-config test <box>
```

The message distinguishes the cases. For "unreachable", work outward:

1. Is the server running there? On that machine: `setup/serve-install --status`
2. Can you reach the address at all? `ping <address>`, or `ssh <address>`
3. Is the port open? A firewall on the serving machine may be blocking 8822 even though the host answers pings.
4. If you are on a VPN or tailnet, is it connected on *both* machines?

For "reachable but token REJECTED", the token changed. `amux-config token <box>` re-fetches it.

## `amux serve` seems dead but the dashboard works (or vice versa)

Do not trust `pgrep -f "amux serve"`. The command execs into `python .../amux-server.py`, so the string `amux serve` is not in the process table at all — a `pkill -f "amux serve"` silently kills nothing, which looks like "the restart did not take".

`setup/serve-install --status` reports the HTTP probe as the authority and matches the process on the right pattern.

## Installed commands are "not found"

`~/.local/bin` is probably not on your PATH. `install.sh` warns about this and prints the line to add. Check with `amux-doctor`, which tests it explicitly.

## The commands run but cannot find `lib/`

`install.sh` symlinks rather than copies, and each command resolves its own symlink back to the checkout to locate `lib/`. If you moved or deleted the checkout, re-clone it and re-run `install.sh`.

## Windows: "tmux is missing calls amux needs"

Your tmux is not the real thing, or not complete enough. See [windows.md](windows.md). The short version: MSYS2's tmux is genuine, psmux is a reimplementation, and Git Bash has none. You should still be able to drive other machines regardless, though that is untested outside WSL.

## The grid shows boxes instead of status dots

A console font without the round Unicode marks. Force ASCII:

```sh
export AMUX_ASCII=1
```

This is the default on Windows outside WSL already.

## `/chrome` says Disabled even though the extension is installed

Expected when the machine authenticates with a long-lived token — Claude Code turns Chrome integration off deliberately in that mode, and `--chrome` will not override it. Also unavailable in WSL entirely. Full explanation in [auth.md](auth.md).

## Undoing things

```sh
setup/serve-install --uninstall # stop the server, remove the autostart entry
./install.sh --uninstall        # remove the symlinks this repo created
```

`install.sh --uninstall` only removes symlinks that point back at this checkout, so it will not delete a same-named command belonging to something else.

## Reporting a problem

Include the output of:

```sh
amux-doctor
```

It never prints a token — only a four-character prefix and a length, which is enough to tell two tokens apart without revealing either.
