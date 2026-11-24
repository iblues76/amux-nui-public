# amux-nui-public

amux-nui-public is a build of [**amux**](https://github.com/mixpeek/amux) that is ready to use. amux is the session manager that runs each coding agent (Claude Code, Codex, Gemini, OpenCode, Antigravity) in its own [tmux](https://github.com/tmux/tmux) session. This build adds companion commands for daily work on one computer or on several.

It is the setup that I use every day, with the personal parts taken out. It contains no machine names, accounts, addresses or credentials, so you add your own.

**Version 0.7.5**, which bundles a modified **amux 0.9.19** (`bin/amux`, `bin/amux-server.py`, `bin/amux-remote`). `amux version` prints both numbers.

It runs on **macOS** and **Linux**, and on **Windows inside WSL2**. [What you need](#what-you-need) lists what each system needs.

I use it every day in **iTerm2 on macOS**. It works the same in other terminals, and it is tested in Linux terminals too. Any terminal that runs tmux will do. The iTerm2 extras (`amux-tabs`, tab titles) are optional.

## What you need

| | macOS | Linux | Windows 10 or 11 |
|---|---|---|---|
| **amux runs** | natively | natively | inside WSL2, with Ubuntu 26.04 LTS |
| **Required** | tmux, python3, curl, git | tmux, python3, curl, git | WSL2 and Ubuntu 26.04, then the Linux column inside Ubuntu |
| **How to get it** | [Homebrew](https://brew.sh), then `brew install tmux` | your package manager (examples below) | step by step in [docs/windows.md](docs/windows.md) |
| **Sandbox flags** | nothing extra | bubblewrap, socat | bubblewrap, socat |
| **Optional** | fzf, mosh | fzf, mosh | fzf, mosh |

On macOS, python3, curl and git come with the system and with Apple's command-line tools, which the Homebrew installer adds. On Linux:

```sh
sudo apt install tmux python3 curl git fzf       # Debian, Ubuntu
sudo dnf install tmux python3 curl git fzf       # Fedora
```

You also need at least one coding agent (Claude Code, Codex, Gemini CLI, OpenCode or Antigravity), installed on the same system as amux. On Windows that means inside Ubuntu: an agent installed on Windows itself is not visible there. `setup/bootstrap` (below) can install tmux, python3, curl, fzf and Claude Code for you, with Homebrew on macOS or apt, dnf, pacman, zypper or apk on Linux.

**fzf** is needed for the session pickers, and **mosh** for attaching over slow links. bubblewrap and socat are needed only for the `--net-sandbox` and `--full-sandbox` flags. agy and opencode in `--full-sandbox` also need srt (see [docs/sandbox.md](docs/sandbox.md#requirements)).

Windows itself (PowerShell, Command Prompt, Git Bash) cannot run amux sessions, because amux runs every agent inside tmux, and tmux needs Linux or macOS. [docs/windows.md](docs/windows.md) lists the alternatives, which are untested.

## Install

```sh
git clone https://git.nuilab.org/f.ortega/amux-nui-public.git
cd amux-nui-public
./install.sh          # amux + companions into ~/.local/bin (no sudo)
amux-doctor           # what this machine can and cannot do
setup/bootstrap       # installs whatever amux-doctor says is missing (tmux, python3, fzf, Claude Code)
```

Add `--statusline` to also set up the amux status line in Claude Code (see [below](#status-line)).

`install.sh` copies `amux`, `amux-server.py` and `amux-remote`, and it makes symlinks to the companions. It copies those three because the dashboard reloads itself when its file changes, so it must not run from a checkout that you update with `git pull`. To update, run `git pull && ./install.sh`. The installer also adds one line to `~/.zshrc` or `~/.bashrc` for tab completion (run `AMUX_NO_COMPLETION=1 ./install.sh` to skip that). `./install.sh --help` lists every option. On a machine that only drives other machines, `./install.sh --client` installs `amux` and the companions without the dashboard server.

If you already have upstream amux installed, make sure `~/.local/bin` comes first on your `PATH`. `amux-doctor` tells you which build it finds.

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

A new session needs `--provider`, which is `claude`, `codex`, `gemini`, `opencode` or `agy`. With `opencode`, amux accepts local models only and refuses cloud providers. `--model`, `--full-access` and any other flags for the agent are passed on to it and remembered. codex, agy and opencode run with full access unless you add `--net-sandbox` or `--full-sandbox`, which keep the agent's commands inside the session folder, with or without network. See [docs/sandbox.md](docs/sandbox.md).

There is also a web dashboard, which you can use from a phone on your private network. Run `amux serve`, then open `https://localhost:8822`.

## Several Claude subscriptions

If you have more than one Claude subscription, for example a personal plan and a team seat, each session can bill a different one:

```sh
amux exec api --provider claude --dir ~/projects/api --account team
amux account api personal          # change it later (session stopped)
amux ls                            # P:cc:api / T:cc:api / X:cc:api
```

You create up to three slots (`personal`, `team`, `team2`, or `P`/`T`/`X`). Each slot is a mode-600 file that holds a token from `claude setup-token`. [docs/accounts.md](docs/accounts.md) explains how to create the tokens, how to store them so that they never appear on your screen or in your shell history, and why you then run `claude auth logout`. If you have one subscription and sign in with `/login`, you do not need any of this.

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

Use a private network: a mesh VPN such as Tailscale, a trusted LAN, or an SSH tunnel. Never expose the dashboard to the internet, because its token controls every session on that machine. [docs/remote.md](docs/remote.md) has the details.

## Status line

amux comes with a status line for Claude Code, the line at the bottom of every session:

```
 4  laptop:…/api ○  T  Op5⁵ hi · ctx 82% · in 36k · Σ251k · ⎇ feat/login* · 7d 75% 2d 7h · 5h 61% 3h 29m
```

The colored square holds the session's row in `amux ls`, so `amux 4` attaches to that session. After it come the machine (one color per machine) and the directory, the focus view, the subscription the session bills (`P`/`T`/`X`), the model and effort, the context left, the token counts, the branch when it needs attention, and both quota windows with their reset times. In a narrow pane, the least useful parts are left out first.

```sh
./install.sh --statusline           # or, once installed: amux-statusline --install
```

It backs up `~/.claude/settings.json` and will not replace a status line you already have unless you add `--force`. [docs/statusline.md](docs/statusline.md) explains every part, the color settings, and how to remove it.

## Colors

Every session has a color, shown on its iTerm2 tab and in the status line square, so that you can tell many open tabs apart.

```sh
amux color                     # every session and its color
amux color api orange          # pin one (20 named colors, or '#rrggbb')
amux start api --color teal    # for this launch only
```

Unless you choose one, amux gives each session a color that no running session has. [docs/colors.md](docs/colors.md) has the details.

## Finding a session

`amux search` finds the session where something was discussed. It looks through every session's conversations, the files in its folder, and its name. It prints the matches with their row numbers in `amux ls`, so `amux <row>` opens the one you want:

```sh
amux search "login bug"                    # this machine
amux search --fleetall "login bug"         # every machine you drive (see "More than one computer")
amux search -e login -e oauth -e redirect  # several words: sessions that use them together come first
amux search --show 3 -e oauth              # what session 3 said about it, with dates
amux search --agentic "which session set up the login page, and is it finished?"
```

To find a session by its name, use `--sessions`. It looks at names only, on this machine and on every machine you drive, and lists the matches the way `amux ls` does, one block per machine:

```sh
amux search --sessions login                    # every machine: sessions with "login" in the name
amux search --sessions -c login                 # the same as a compact grid, like amux ls -c
amux search --sessions laptop,desk login        # only those machines ('local' = this one; or --local)
amux search --sessions --matchstring start web  # the name starts with "web" (start, anywhere or end)
amux search --sessions --regex '^web-[0-9]+$'   # a regular expression; -s matches case exactly
```

It reads no conversations, so it answers in about a second. Machines with no match, and machines that did not answer, are named on one line each. `amux <row>` opens a match on this machine, and `amux up <machine> <name>` opens one on another machine.

To search a group of machines, put `CORE="laptop desk"` and `MAIN="laptop desk server"` in `~/.amux/search-groups.conf` (machine names or ssh aliases), then use `--corefleet` or `--mainfleet`. MAIN always includes CORE. `--fleetall` (or `--fleet`) means every machine. Results print machine by machine as each one answers.

To search for several words, repeat `-e`. Sessions are ranked by how often they use the words together, then by how recent they are. In the output, `login×40 oauth×12 · all in 2` means that two of the session's conversations mention both words. `--and` keeps only the sessions that mention every word. `--since 30d` (or `12h`, `2w`, `2026-10-01`) keeps only recent sessions.

The first search on a machine is slower than the later ones. It saves the text of each conversation in `~/.amux/cache/search`, which takes about half a minute for a few GB of history and uses about a tenth of its size. After that, only new or changed conversations are read again, so a search takes a few seconds per machine.

With `--agentic`, a coding agent does the search, and you ask your question in plain words. First, a quick literal search of the question's main words prints. Then the agent (Claude by default) runs more searches, reads what the best sessions said, and ranks them with a reason for each. Each step prints as it happens. The agent searches your CORE group, or this machine if you have no groups, and looks wider only when that finds nothing. It stops after 10 minutes and shows what it found by then. The agent is read-only: it searches conversations and does not run commands on your machines. `amux search --continue "follow-up"` continues the same conversation. Every plain search ends with a one-line tip that shows the `--agentic` version of what you typed. `amux-search -h` lists all options.

## Commands

| Command | What it does |
|---|---|
| [`amux`](bin/amux) | The session manager: `exec`, `start`, `stop`, `ls`, `attach`, `peek`, `send`, `account`, `provider`, `pick`, `-H <box>`, `-A`, `serve` … |
| [`amux-server.py`](bin/amux-server.py) | The dashboard and REST API behind `amux serve`; also auto-resumes and watches sessions |
| [`amux-remote`](bin/amux-remote) | Drive another machine's amux over its REST API (what `amux -H <box>` runs) |
| [`amux-config`](bin/amux-config) | Add, test, rotate and remove the machines you drive. Tokens stay off command lines and out of shell history |
| [`amux-doctor`](bin/amux-doctor) | Reports what this machine can and cannot do |
| [`amux-all`](bin/amux-all) | Every machine's sessions in one view (what `amux -A` runs) |
| [`ccjump`](bin/ccjump) | Fuzzy picker over every session everywhere (what `amux pick` runs) |
| [`amux-up`](bin/amux-up) | Start a session if it is not running, then attach to it, local or remote |
| [`amux-ls`](bin/amux-ls) | This machine's sessions via the dashboard API, compact or verbose, numbered like `amux ls` |
| [`amux-convos`](bin/amux-convos) | A session's past conversations with a snippet of each; resume the right one |
| [`amux-reauth`](bin/amux-reauth) | Fix sessions stuck at `401 / Please run /login`, with no browser |
| [`check-claude-auth`](bin/check-claude-auth) | Checks whether sessions on this machine can sign in, for each account |
| [`amux-search`](bin/amux-search) | Which sessions talked about something, on one machine or all (what `amux search` runs) |
| [`amux-rename`](bin/amux-rename) | Rename a session everywhere at once while it keeps running (what `amux rename` runs) |
| [`amux-rm-stopped`](bin/amux-rm-stopped) | Remove every stopped session from the list (asks first) |
| [`amux-statusline`](bin/amux-statusline) | The Claude Code status line above; `--install` / `--uninstall` |
| [`amux-tabs`](bin/amux-tabs) | One iTerm2 tab per session (macOS) |
| [`amux-color`](bin/amux-color) | One color per session for its iTerm2 tab and status line square (what `amux color` runs) |
| [`amux-sandbox`](bin/amux-sandbox) | Turns `--net-sandbox` / `--full-sandbox` into each agent's own controls ([docs/sandbox.md](docs/sandbox.md)) |
| [`amux-termprobe`](bin/amux-termprobe) | Logs the terminal's real colors around each attach (debugging aid; `AMUX_TERMPROBE=0` disables) |

Every command prints its help with `-h`.

**Moving a session's work to another machine.** `amux offload claude <folder or session>` hands over to [offload](https://git.nuilab.org/f.ortega/offload), a separate one-file tool: the session working in the folder writes a handoff note, the folder is copied over ssh, and a new amux session starts on the other machine and reads the note. `amux offload <anything else>` runs the same tool.

## Docs

- [**accounts.md**](docs/accounts.md): how to bill each session to a different Claude subscription
- [**auth.md**](docs/auth.md): the two ways to sign in to Claude Code, and what each one lets you do
- [**remote.md**](docs/remote.md): how to reach the amux sessions on your other machines
- [**statusline.md**](docs/statusline.md): what each part of the status line means, and how to install it, adjust it and remove it
- [**colors.md**](docs/colors.md): how each session gets its color, and how to choose one yourself
- [**sandbox.md**](docs/sandbox.md): what `--net-sandbox` and `--full-sandbox` allow, how each agent is confined, and what each system needs
- [**windows.md**](docs/windows.md): how to set up amux on Windows, inside WSL2 with Ubuntu 26.04 LTS
- [**troubleshooting.md**](docs/troubleshooting.md): common problems, what causes them, and how to fix them
- [**CHANGELOG.md**](CHANGELOG.md): what changed in each release

## What is different from upstream amux

Fixes and additions, all in `bin/amux`, `bin/amux-server.py` and `bin/amux-remote`:

- A restart keeps the session's context. It resumes the newest real conversation instead of starting a blank one, and it skips a conversation that a background `claude` process holds instead of failing.
- The status is accurate. A stopped session no longer shows as running, `start` reports `still loading` when the agent has not finished starting, and a failed start shows the agent's own error.
- Stale sessions are recycled one at a time, gracefully first, and never while you are attached. Restarting the dashboard no longer kills tmux.
- Each session can have its own agent and its own account (`--provider` and `--account`), and `amux ls` shows both.
- It works across several machines: `amux -H <box>`, `amux -A`, `amux pick`, `--find`, and attach over mosh. Remote control keeps tokens off command lines, validates session names, and matches tmux targets exactly.
- The previous `patches/apply` script is gone. It patched upstream's server in place, and its fixes are now part of the bundled build.

## Security

One rule holds everywhere: a secret never appears on a command line, in output, or in your shell history.

- Tokens move over stdin, SSH, or a mode-600 file. `amux-config` has no `--token` flag on purpose.
- Where a token must be identified, only a short prefix and a length are printed.
- `setup/serve-install` binds to loopback plus one address you choose, never `0.0.0.0`.
- A request from the same machine skips the token only when it comes from your own user (on Linux, also root). Other people with a login on that machine are asked for the token like anyone else. See [docs/remote.md](docs/remote.md).
- A web page open in a browser on the same machine cannot use that trust: the server refuses a change asked for by a page of another site.
- Text typed in the dashboard (a description, tags, a folder, a branch) is stored as text and cannot run as a command.
- `tools/audit-clean` scans the tree (and `--history`) for credentials, private addresses and personal data before anything is published. `tools/selftest` checks that the checkout works, without touching your real `~/.amux`.

## License: MIT + Commons Clause (not plain MIT)

Earlier releases of this repository were plain MIT, because they contained only original companion scripts. This release bundles a modified copy of amux, which upstream licenses as MIT + Commons Clause. A derived work cannot have a more permissive license than its source, and two licenses in one repository would be confusing, so the whole repository now uses the same terms as amux.

In practice, you may use, copy, modify and share all of it freely, including at work. The Commons Clause takes away the right to sell it, which means to offer, for a fee, a product or service whose value comes substantially from this software. If you want to do that, ask first.

- `bin/amux`, `bin/amux-server.py`, `bin/amux-remote`: © 2025 Mixpeek, Inc., modified by Francisco Ortega (modifications © 2026). Upstream's notice is kept, in [LICENSE](LICENSE) and in each file's header.
- Everything else: © 2026 Francisco Ortega.

The full text is in [LICENSE](LICENSE).
