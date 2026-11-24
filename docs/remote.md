# Connecting machines

You need none of this to use amux on one computer. This page is for when you have a second machine.

## How it works

One machine runs `amux serve`, a small HTTPS server that exposes its sessions over a REST API. Any other machine holding that server's **token** can list, peek at, message, create, configure, start and stop those sessions.

The token is the only protection. Anyone who has it controls every session on that machine, and so can read and write any file that those agents can reach. Treat it like a password.

One caller needs no token: the machine itself. The sessions on it, the `amux` command and its hooks reach the server on `127.0.0.1` without one. This applies only when the request comes from your own user (on Linux, also from root). Another person logged in to the same machine is asked for the token like anyone else. The server finds out who is on the other end of the connection: on Linux from the kernel's socket table, on macOS with `lsof`, which takes 10 to 20 milliseconds per connection. To trust every local user again, put `AMUX_LOCAL_TRUST=any` in `~/.amux/server.env`.

Two more rules keep a web page from using that trust. A browser on the same machine is also a same-machine caller, so the server refuses a change that a page of another site asks for (the browser names the page's site in the request), unless the request carries the token. It also skips the token only when the request asks for the server under a name of this machine, such as `localhost` or `127.0.0.1`. The dashboard itself, `curl` and the `amux` command are not affected.

Text typed in the dashboard stays text. A description, the tags, a folder path and a branch name are stored in the session's file, which `amux` reads as shell text. The server therefore refuses a double quote, a backslash, a dollar sign, a backtick or a line break in them, and says so.

For that reason, never expose an amux server directly to the internet. `setup/serve-install` binds to loopback and to one address that you choose, and never to `0.0.0.0`.

## Getting a network path between them

There are three ways, and any of them works. `amux-config` needs only an address that it can reach.

**A private mesh VPN (recommended).** A mesh VPN such as Tailscale gives each machine a stable private address that works from anywhere without port forwarding, and it encrypts the traffic itself. It is the most reliable choice for a laptop that moves between networks. `setup/serve-install` finds a Tailscale address by itself when there is one.

**Your local network.** This works when both machines are always on the same trusted LAN. Use the hostname (`desktop.local`) or the LAN address. It stops working when you take the laptop somewhere else, and a public network such as a coffee shop's is not a trusted LAN.

**An SSH tunnel.** This needs no extra software and works wherever SSH does. Bind the server to loopback only, then forward the port:

```sh
setup/serve-install --loopback-only          # on the machine being served
ssh -N -L 8822:127.0.0.1:8822 that-machine   # on the machine driving it
amux-config add work --host 127.0.0.1        # the tunnel makes it local
```

The cost is that the tunnel must be running whenever you want to reach that machine.

## Setting it up

**On the machine to be reached:**

```sh
setup/serve-install
```

It chooses an address, starts the server, sets it to start again after a reboot, and prints the command to run next.

**On the machine you drive from:**

```sh
amux-config add desktop --host 192.0.2.10
```

That reads the token over SSH and stores it, mode 600, at `~/.amux/remotes/desktop.env`. If there is no SSH between the two machines, move the token another way and pipe it in:

```sh
amux-config add desktop --host 192.0.2.10 --token-stdin < token.txt
```

There is no `--token` flag, on purpose. Every user on the machine can see a token typed on a command line through `ps`, and it stays in your shell history.

**Check it:**

```sh
amux-config test --all
```

It tells three results apart: unreachable (nothing answered), reachable but rejected (the token is wrong or was changed), and working.

## Using it

```sh
amux ls                          # this machine
amux -H desktop ls -c            # that machine (amux -H <box> ... == amux-remote <box> ...)
amux -H desktop exec review --provider codex --dir '~/work/review'
amux -H desktop attach review    # SSH in and attach (add --mosh on a slow link)
amux -A                          # every machine at once, busiest first (== amux-all)
amux pick -A                     # fuzzy-pick any session anywhere (needs fzf; == ccjump)
amux-up desktop myproject        # ensure a session is started AND attach to it
amux attach myproject --find     # not on this machine? look on the others
```

Each of these commands names the machine first. amux has no default machine and never guesses one, even when only one is configured, so that a session cannot start on the wrong computer.

`amux -H <box> start <name>` starts the session and, when you run it in a terminal, attaches too. `--no-attach` (or running it from a script) only starts it.

`exec` creates and starts a session in one operation. It needs `--provider` and accepts `--dir`, `--model`, `--account`, `--full-access`, `--net-sandbox` or `--full-sandbox`, `--autoprompt`, `--partners` (opencode only), `--desc` and `--worktree`. Quote a `~/...` directory so that the remote machine expands it. amux-remote also changes your own home prefix back to `~/`, and says so. `amux -H <box> provider <name> [<p>]` and `amux -H <box> account <name> [P|T|X]` show or change an existing session's agent and account.

The same commands work on this machine and through `-H`, by the same rules.

**What a session is doing.** `amux ls` marks a session `*` while something runs in its pane, `~` when its tmux session is open but the agent has left (a shell prompt, or a pane whose program ended), and leaves it blank when it is stopped. In the compact grid the marks are `●`, `◐` and `○`. `amux start` on a `~` session starts the agent again in that same pane.

**Stop.** `amux stop <name>` asks the agent to exit, so it can save its state, and ends the tmux session once the agent has left, or after 15 seconds if it has not. `amux stop --now <name>` ends the session at once. `amux stop-all` asks every session at the same time.

`--desc` and `--worktree` exist only through `-H`, because the server applies them.

Three more things are the same on both sides. A session pinned in the dashboard is not removed by `rm`: unpin it first, or on this machine use `amux rm --force`. A codex session resumes the same conversation whoever starts it: the newest interactive conversation for its folder, or a new one with `--fresh`. And a row number is always the one that machine's own `amux ls` shows, also when its server hides a session listed in `~/.amux/blocked-sessions.txt`.

Remote session names are validated before SSH attach, encoded before entering a REST path, and matched exactly in tmux. The dashboard token reaches curl through a header file, not a command-line argument, so it never appears in `ps`.

### Optional settings in `~/.amux/remotes/<box>.env`

| Setting | What it does |
|---|---|
| `AMUX_SSH_HOST` | SSH name for attach; may be a space-separated list tried in order (`"box1-lan box1"`) |
| `AMUX_SSH_USER` | SSH user, if it differs from yours |
| `AMUX_MOSH=1` | attach to this machine over mosh by default |

Environment switches: `AMUX_CURL_FAMILY` (default `-4`; set empty if a machine is only reachable over IPv6), `AMUX_HOST_PREFIX` (if your hostname is `my-laptop` but its box entry is `laptop`, set `my-` so it is not listed twice).

## Rotating a token

If a machine's token changes, or you think it leaked:

```sh
amux-config token desktop        # re-fetch over SSH, keeping all other settings
```

Do this on every machine that had the old one. `amux-config test --all` shows which ones still fail.

## More than two machines

It works the same way. Add one `~/.amux/remotes/<name>.env` for each machine. Every command then uses it, and `amux-all` and `ccjump` list every machine that is configured.

Two notes for when you have several:

- Give each machine a name that you will recognize. `laptop` and `gpu-box` are better than `machine1` and `machine2`.
- `amux-all` gives each machine a time limit, so a machine that does not answer makes the view slower but does not block it. That machine is marked as unreachable.
