# amux-nui-public

A ready-to-use build of [**amux**](https://github.com/mixpeek/amux) — the session manager that runs each coding agent (Claude Code, Codex, Gemini, OpenCode, Antigravity) in its own [tmux](https://github.com/tmux/tmux) session — plus the companion commands that make it pleasant to live in day to day, across one computer or several.

This is the setup its maintainer uses every day, with the personal parts taken out: no machine names, accounts, addresses or credentials ship in it. You bring your own.

**Version 0.4.0** — bundles a modified **amux 0.9.14** (`bin/amux`, `bin/amux-server.py`, `bin/amux-remote`).

Works on **macOS and Linux**, and on **Windows** through WSL (driving other machines from MSYS2 or Git Bash is untested; see [docs/windows.md](docs/windows.md)).

I use it every day in **iTerm2 on macOS**, and it works the same in other terminals: it is tested in Linux terminals too. Anything that runs tmux will do; the iTerm2 extras (`amux-tabs`, tab titles) are optional.

## Install

```sh
git clone https://git.nuilab.org/f.ortega/amux-nui-public.git
cd amux-nui-public
./install.sh          # amux + companions into ~/.local/bin (no sudo)
amux-doctor           # what this machine can and cannot do
setup/bootstrap       # installs whatever amux-doctor says is missing (tmux, python3, fzf, Claude Code)
```

Add `--statusline` to also set up the amux status line in Claude Code (see [below](#status-line)).

`install.sh` **copies** `amux`, `amux-server.py` and `amux-remote` (the dashboard reloads itself when its file changes, so it must not run from a checkout you `git pull`), and **symlinks** the companions. To update: `git pull && ./install.sh`. It also adds one line to `~/.zshrc` / `~/.bashrc` for tab completion (`AMUX_NO_COMPLETION=1 ./install.sh` to skip). `./install.sh --help` lists every option.

Needs **tmux**, **python3**, **curl**, and at least one coding agent. Optional: **fzf** (pickers), **mosh** (attach over slow links).

If you already have upstream amux installed, make sure `~/.local/bin` comes first on your `PATH`; `amux-doctor` tells you which build it finds.

## Quick start (one computer)

```sh
amux exec api --provider claude --dir ~/projects/api    # create + start + attach
# ... work; detach with Ctrl-b d
amux ls                  # every session; green * = running
amux 1                   # attach to row 1
amux peek api            # last lines without attaching
amux send api "run the tests"
amux stop api            # the conversation is kept; `amux start api` resumes it
amux --help              # everything else
```

`--provider` is required for a new session: `claude`, `codex`, `gemini`, `opencode` (local models only — amux refuses cloud providers for it) or `agy`. `--model`, `--full-access` and any other agent flags ride along and are remembered.

Optional web dashboard (also usable from a phone on your private network): `amux serve`, then open `https://localhost:8822`.

## Several Claude subscriptions

If you have more than one — a personal plan and a team seat, for example — each session can bill a different one:

```sh
amux exec api --provider claude --dir ~/projects/api --account team
amux account api personal          # change it later (session stopped)
amux ls                            # P:cc:api / T:cc:api / X:cc:api
```

You create up to three slots (`personal`, `team`, `team2`, or `P`/`T`/`X`), each a mode-600 file holding a token from `claude setup-token`. **[docs/accounts.md](docs/accounts.md)** walks through minting the tokens, storing them without them ever reaching your screen or shell history, and the `claude auth logout` step that prevents the most confusing failure in this setup. With one subscription and `/login`, ignore all of this.

## More than one computer

On each machine you want to **reach**:

```sh
setup/serve-install       # runs `amux serve` on loopback + one private address, survives reboot
```

On the machine you **drive from**:

```sh
amux-config add desktop --host <address>     # reads the token over SSH, stores it mode 600
amux-config test --all

amux -H desktop ls -c                        # that machine's sessions
amux -H desktop exec review --provider codex --dir '~/work/review'
amux -A                                      # every machine at once
amux pick -A                                 # fuzzy-pick any session anywhere, attach
```

Use a private network — a mesh VPN such as Tailscale, a trusted LAN, or an SSH tunnel. Never expose the dashboard to the internet: its token controls every session on that machine. Details: **[docs/remote.md](docs/remote.md)**.

## Status line

The bottom line of every Claude Code session, built to go with amux:

```
 4  laptop:…/api ○  T  Op5⁵ hi · ctx 82% · in 36k · Σ251k · ⎇ feat/login* · 7d 75% 2d 7h · 5h 61% 3h 29m
```

The colored square holds the session's `amux ls` row, so `amux 4` attaches to exactly that session. Then the machine (one color per machine) and directory, focus view, which subscription it bills (`P`/`T`/`X`), model and effort, context left, tokens, the branch when it needs attention, and both quota windows with their reset times. Narrow panes drop the least useful parts first.

```sh
./install.sh --statusline           # or, once installed: amux-statusline --install
```

It backs up `~/.claude/settings.json` and will not replace a status line you already have unless you add `--force`. Every segment, the color settings and removal: **[docs/statusline.md](docs/statusline.md)**.

## Finding a session

Which session was it where you fixed that bug? `amux search` looks through every session's conversations, the files in its folder, and its name, and prints the matches with their `amux ls` row numbers, so `amux <row>` opens the one you want:

```sh
amux search "login bug"               # this machine
amux search --fleet "login bug"       # every machine you drive (see "More than one computer")
amux search --agentic "which session set up the login page, and is it finished?"
```

With `--agentic`, a coding agent (Claude by default) runs several searches for you, reads the matching conversations, and ranks the sessions with a reason for each. It takes a minute or two. `amux search -c "follow-up"` continues the same conversation. Every plain search ends with a one-line tip showing the `--agentic` version of what you typed. All options: `amux-search -h`.

## Commands

| Command | What it does |
|---|---|
| [`amux`](bin/amux) | The session manager: `exec`, `start`, `stop`, `ls`, `attach`, `peek`, `send`, `account`, `provider`, `pick`, `-H <box>`, `-A`, `serve` … |
| [`amux-server.py`](bin/amux-server.py) | The dashboard and REST API behind `amux serve`; also auto-resumes and watches sessions |
| [`amux-remote`](bin/amux-remote) | Drive another machine's amux over its REST API (what `amux -H <box>` runs) |
| [`amux-config`](bin/amux-config) | Add, test, rotate and remove the machines you drive. Tokens never touch argv or history |
| [`amux-doctor`](bin/amux-doctor) | Honest report of what this machine can do |
| [`amux-all`](bin/amux-all) | Every machine's sessions in one view (what `amux -A` runs) |
| [`ccjump`](bin/ccjump) | Fuzzy picker over every session everywhere (what `amux pick` runs) |
| [`amux-up`](bin/amux-up) | Ensure a session is started **and** attach to it, local or remote |
| [`amux-ls`](bin/amux-ls) | This machine's sessions via the dashboard API, compact or verbose |
| [`amux-convos`](bin/amux-convos) | A session's past conversations with a snippet of each; resume the right one |
| [`amux-reauth`](bin/amux-reauth) | Fix sessions stuck at `401 / Please run /login`, with no browser |
| [`check-claude-auth`](bin/check-claude-auth) | Whether sessions here will really authenticate, per account |
| [`amux-search`](bin/amux-search) | Which sessions talked about something, on one machine or all (what `amux search` runs) |
| [`amux-rename`](bin/amux-rename) | Rename a session everywhere at once without losing its context |
| [`amux-rm-stopped`](bin/amux-rm-stopped) | Remove every stopped session from the list (asks first) |
| [`amux-statusline`](bin/amux-statusline) | The Claude Code status line above; `--install` / `--uninstall` |
| [`amux-tabs`](bin/amux-tabs) | One iTerm2 tab per session (macOS) |
| [`amux-termprobe`](bin/amux-termprobe) | Logs the terminal's real colors around each attach (debugging aid; `AMUX_TERMPROBE=0` disables) |

Every command answers `-h`.

## Docs

- [**accounts.md**](docs/accounts.md) — several Claude subscriptions: slots, tokens, the logout step
- [**auth.md**](docs/auth.md) — `/login` vs long-lived tokens, browser control, the both-at-once trap
- [**remote.md**](docs/remote.md) — connecting machines; tokens and rotation
- [**statusline.md**](docs/statusline.md) — the status line: every segment, settings, install and removal
- [**windows.md**](docs/windows.md) — WSL vs MSYS2 vs Git Bash
- [**troubleshooting.md**](docs/troubleshooting.md) — symptoms, causes, fixes
- [**CHANGELOG.md**](CHANGELOG.md) — what changed in each release

## What is different from upstream amux

Fixes and additions, all in `bin/amux`, `bin/amux-server.py` and `bin/amux-remote`:

- **Context is never silently lost.** Restarts resume the newest real conversation instead of starting a blank one; a conversation held by a background `claude` process is skipped, not fatal.
- **Honest status.** A stopped session no longer shows as running; `start` reports `still loading` instead of a false `started`, and start failures carry the agent's real error.
- **Gentler housekeeping.** Stale sessions are recycled gracefully first, one at a time, and never while you are attached; a dashboard restart no longer kills tmux.
- **Several agents and several accounts**: per-session `--provider` and `--account`, shown in `amux ls`.
- **Several machines**: `amux -H <box>`, `amux -A`, `amux pick`, `--find`, attach over mosh, and secret-safe remote control (tokens off argv, names validated, exact tmux targets).
- The previous `patches/apply` script is gone: it patched upstream's server in place, and the fixes it carried are now part of the bundled build.

## Security

The rule throughout: **a secret never reaches argv, stdout, or your shell history.**

- Tokens move over stdin, SSH, or a mode-600 file. `amux-config` has no `--token` flag on purpose.
- Where a token must be identified, only a short prefix and a length are printed.
- `setup/serve-install` binds to loopback plus one address you choose, never `0.0.0.0`.
- `tools/audit-clean` scans the tree (and `--history`) for credentials, private addresses and personal data before anything is published; `tools/selftest` proves the checkout works without touching your real `~/.amux`.

## License: MIT + Commons Clause (not plain MIT)

Earlier releases of this repository were plain MIT, because they contained only original companion scripts. This release **bundles a modified copy of amux**, which upstream licenses as **MIT + Commons Clause**. A derived work cannot be relicensed more permissively than its source, and splitting one repository across two licenses invites confusion, so the **whole repository** now uses the same terms as amux.

In practice: you may use, copy, modify and share all of it freely, including at work. What the Commons Clause takes away is the right to **sell** it — to offer, for a fee, a product or service whose value comes substantially from this software. If you want to do that, ask first.

- `bin/amux`, `bin/amux-server.py`, `bin/amux-remote`: © 2025 Mixpeek, Inc., modified by Francisco Ortega (modifications © 2026). Upstream's notice is kept, in [LICENSE](LICENSE) and in each file's header.
- Everything else: © 2026 Francisco Ortega.

Full text: [LICENSE](LICENSE).
