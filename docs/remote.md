# Connecting machines

You need none of this to use one computer. Install amux, run `amux`, done. This page is for when a second machine appears.

## The model

One machine runs `amux serve`, a small HTTPS server that exposes its sessions over a REST API. Any other machine holding that server's **token** can list, peek at, message, create, configure, start and stop those sessions.

The token is the whole security boundary. Anyone with it controls every session on that machine — which means it can read and write any file those agents can reach. Treat it exactly like a password.

Consequently: **never expose an amux server directly to the internet.** `setup/serve-install` binds to loopback plus one specific address you choose, never `0.0.0.0`, on purpose.

## Getting a network path between them

Pick whichever fits. `amux-config` does not care which you chose — it only wants an address it can reach.

**A private mesh VPN (recommended).** Something like Tailscale gives each machine a stable private address that works from anywhere without port forwarding, and the traffic is encrypted end to end independently of amux. This is the least fragile option for a laptop that moves between networks. `setup/serve-install` detects a Tailscale address automatically when one exists.

**Your local network.** Fine when both machines are always on the same trusted LAN. Use the hostname (`desktop.local`) or the LAN IP. It stops working the moment you take the laptop elsewhere, and a coffee-shop network is not a trusted LAN.

**An SSH tunnel.** No extra software, works wherever SSH does. Bind the server to loopback only, then forward the port:

```sh
setup/serve-install --loopback-only          # on the machine being served
ssh -N -L 8822:127.0.0.1:8822 that-machine   # on the machine driving it
amux-config add work --host 127.0.0.1        # the tunnel makes it local
```

The tunnel must be running whenever you want to reach it, which is the tradeoff.

## Setting it up

**On the machine to be reached:**

```sh
setup/serve-install
```

It works out an address, starts the server, makes it survive reboot, and prints the exact command to run next.

**On the machine you drive from:**

```sh
amux-config add desktop --host 192.0.2.10
```

That reads the token over SSH and stores it mode-600 at `~/.amux/remotes/desktop.env`. No SSH between them? Move the token across some other way and pipe it in:

```sh
amux-config add desktop --host 192.0.2.10 --token-stdin < token.txt
```

There is deliberately no `--token` flag. A token typed on a command line is visible to every user on the machine via `ps` and is saved to your shell history forever.

**Check it:**

```sh
amux-config test --all
```

This distinguishes the three failures that look alike: unreachable (nothing answered), reachable but rejected (the token is wrong or was rotated), and working.

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

Every one of these names the machine **first**, the same way. There is no default remote and no inferred "the only configured one" — guessing which machine to drive is how you start a session on the wrong computer.

`amux -H <box> start <name>` starts the session and, when you run it in a terminal, attaches too. `--no-attach` (or running it from a script) only starts it.

`exec` creates and starts a session in one operation. It needs `--provider` and accepts `--dir`, `--model`, `--account`, `--full-access`, `--desc` and `--worktree`; quote a `~/...` directory so the remote machine expands it (amux-remote also rewrites your own home prefix back to `~/` and says so). `amux -H <box> provider <name> [<p>]` and `amux -H <box> account <name> [P|T|X]` show or change an existing session's agent and account.

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

Do this on every machine that had the old one. `amux-config test --all` will show you which ones still fail.

## Growing past two machines

Nothing changes. Add one `~/.amux/remotes/<name>.env` per machine and every command picks it up automatically — `amux-all` and `ccjump` enumerate whatever is configured.

Two things worth doing once you have several:

- Give each machine a name you will recognize under pressure. `laptop` and `gpu-box` beat `machine1` and `machine2`.
- `amux-all` bounds each machine's call with a timeout, so one unreachable machine slows the view rather than hanging it. It marks the dead one and moves on.
