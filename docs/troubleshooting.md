# Troubleshooting

Start with `amux-doctor`. It checks the whole machine, and most of this page explains in more detail something that it reports.

## Sessions say "Please run /login"

Read the rest of the error first, because two different problems show that message.

`401 The socket connection was closed unexpectedly` is a network failure that is reported as a sign-in failure. Your credentials are fine, and signing in again does not help. Wait for the connection to come back, then send the prompt again.

`OAuth access token has expired` or `Invalid authentication credentials` is a real sign-in failure. The usual cause is a machine that has both a stored browser login and a long-lived token: sessions use the login and do not fall back to the token when the login expires. See [auth.md](auth.md). To fix it:

```sh
check-claude-auth        # says which credential is really in use
amux-reauth --all        # probe, clear a shadowing login, restart what is stuck
```

## A session shows as running after I stopped it

The bundled amux fixes this. The session list now checks that the agent is running in the pane, not only that a tmux session exists. If you still see it, an older amux is probably first on your `PATH`. `amux-doctor` says which build it found. Run `./install.sh` again.

## A session lost all its context after restarting

The bundled amux fixes this too. When it cannot tell which conversation to resume, it resumes the newest real conversation for the session's directory instead of starting a blank one. Older conversations are never deleted. `amux-convos <session>` lists them, and `amux-convos <session> --resume N` resumes one.

## A session dies about 3 seconds after `amux start`

The usual cause is a Claude Code background session (`claude --bg`, or "Backgrounding after the current tool finishes…") that still holds the newest conversation for that directory. claude refuses to resume a conversation that another process holds. The bundled amux skips such a conversation and says which one it skipped. `claude agents` lists the processes that hold conversations, and `claude stop <id>` releases one.

## A machine shows UNREACHABLE

```sh
amux-config test <box>
```

The message says which case it is. For "unreachable", check these in order:

1. Is the server running there? On that machine: `setup/serve-install --status`
2. Can you reach the address at all? `ping <address>`, or `ssh <address>`
3. Is the port open? A firewall on the serving machine may be blocking 8822 even though the host answers pings.
4. If you are on a VPN or tailnet, is it connected on both machines?

For "reachable but token REJECTED", the token changed. `amux-config token <box>` fetches it again.

## `amux serve` seems dead but the dashboard works (or vice versa)

Do not rely on `pgrep -f "amux serve"`. The command replaces itself with `python .../amux-server.py`, so the string `amux serve` is not in the process table. For the same reason, `pkill -f "amux serve"` stops nothing and reports no error, so a restart done that way has no effect.

`setup/serve-install --status` tests the server over HTTP and looks for the process under its real name.

## Installed commands are "not found"

`~/.local/bin` is probably not on your PATH. `install.sh` warns about this and prints the line to add. `amux-doctor` checks it too.

## The commands run but cannot find `lib/`

`install.sh` makes symlinks to the companion commands instead of copying them, and each command follows its own symlink back to the checkout to find `lib/`. If you moved or deleted the checkout, clone it again and run `install.sh` again.

## Windows: "tmux is missing calls amux needs"

Your tmux is not tmux itself, or it is incomplete. On Windows, run amux inside WSL2 with Ubuntu 26.04 LTS. [windows.md](windows.md) has the steps. Outside WSL, MSYS2 has a real tmux that is untested with amux, psmux is a different program, and Git Bash has no tmux.

## The grid shows boxes instead of status dots

The console font does not have the round Unicode marks. Use plain ASCII marks instead:

```sh
export AMUX_ASCII=1
```

On Windows outside WSL, this is already the default.

## `/chrome` says Disabled even though the extension is installed

This is expected when the machine signs in with a long-lived token. Claude Code then turns Chrome integration off on purpose, and `--chrome` does not turn it back on. Chrome integration is also unavailable in WSL. [auth.md](auth.md) explains why.

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

It never prints a token. It prints only a four-character prefix and a length, which is enough to tell two tokens apart.
