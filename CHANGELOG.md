# Changelog

What changed in each release of amux-nui-public, newest first. From 0.3.0 on, every release is a git tag (`v0.3.1`) and a tarball on the [download page](https://amux.nuilab.org/download/).

## 0.7.5 — 2026-11-24

The command line and the server each had their own answer to "is this session running" and their own way to stop one. They now share one rule. Update the server on every machine: the list a new `amux` draws for another machine is best with a new server there (an older one still works).

- **Three states, the same everywhere.** `amux ls` marks a session `*` while something runs in its pane, `~` when its tmux session is open but the agent has left, and leaves it blank when it is stopped. The compact grid shows `●`, `◐` and `○`. Before, `*` on this machine meant "the tmux session exists", while through `amux -H <box>` it meant "the agent is alive", judged from the text on the screen (a line that ended in `$` or `%` counted as a shell prompt). Both sides now look at the pane's processes. `amux info`, `amux search --sessions`, `amux -A` and the picker show the same states.
- **`amux start` brings the agent back in place.** On a `~` session it used to attach you to the bare shell. It now starts the agent again in that same pane, and the conversation is resumed as usual.
- **`amux stop` asks first.** It asks the agent to exit, so it can save its state, and ends the tmux session once the agent has left, or after 15 seconds. It used to end the session at once, while `amux -H <box> stop` asked first and then left a shell behind. Both now end in the same state: stopped. `amux stop --now <name>` ends a session at once, also through `-H`. `amux stop-all` asks every session at the same time, and `amux stop-all --now` ends them all at once.
- **macOS: only your own user skips the token.** On a Mac, every local user could reach the dashboard server without the token. The server now checks who owns the other end of a same-machine connection there too (with `lsof`, 10 to 20 ms per connection), as it already did on Linux. On macOS root needs the token as well. `AMUX_LOCAL_TRUST=any` in `~/.amux/server.env` restores the old behavior.
- **`amux offload`: move a session's work to another machine.** `amux offload claude <folder or session>` runs the [offload](https://git.nuilab.org/f.ortega/offload) tool (0.2.0 or newer, installed separately): the session working in the folder writes a handoff note, the folder is copied, and a new amux session starts on the other machine and reads the note. Any other `amux offload <args>` goes to the same tool. `amux help` lists it under the words move and transfer.
- **`amux info --dir <folder>`** lists the sessions registered for a folder. `--porcelain` prints one tab-separated line per session (name, state, agent, account, folder, flags) for scripts.
- Stopping a codex, opencode or other non-Claude session through the server no longer types Claude's `/rename` command into it first.
- `amux-ls` and `amux -H <box> ls -c` use the row number the server sends.

## 0.7.4 — 2026-11-23

Update the server on every machine that runs one: the first two items are security fixes.

- **Text typed in the dashboard can no longer run as a command.** A session's description, tags, folder and branch are stored in its file, which `amux` reads as shell text. A description containing `$(…)` ran as a command the next time `amux ls` read the session. The server now refuses a double quote, a backslash, a dollar sign, a backtick and a line break in those fields and tells you why, and it writes every other value so that it stays text. Anyone who could use a machine's dashboard could run commands on it this way.
- **A web page cannot drive the server from your own browser.** A request from the same machine and the same user needs no token, and a browser on that machine counts as such a caller. The server now refuses a change that a page of another site asks for, and it skips the token only when the request asks for the server under a name of this machine. This mattered when the server ran without TLS, or with a certificate the browser trusts for `localhost`. The dashboard, `curl` and the `amux` command are not affected. See [docs/remote.md](docs/remote.md).
- **A pinned session is not removed by accident.** `amux rm` and `amux rmnum` now refuse a session pinned in the dashboard, as the dashboard and `amux -H <box> rm` already did. `amux rm --force` removes it. `amux-rm-stopped` keeps pinned sessions and lists iTerm2 sessions on a line of their own.
- **A codex session resumes the same conversation whoever starts it.** `amux start` took the newest interactive conversation for the folder, while the dashboard and `amux -H <box> start` took an id stored earlier, which could be an older conversation. Both now follow one rule: `--fresh` starts a new conversation; otherwise the newest interactive conversation for the folder; if there is none, the stored one when its file still exists.
- **Row numbers from another machine are that machine's own.** A server hides the sessions listed in `~/.amux/blocked-sessions.txt`, which shifted every later row in `amux -H <box> ls -c` and `amux search --sessions` by one. The server now sends each session's row. An older server on the other machine still works, with the old numbering.
- **`amux start <name>` takes `--provider` anywhere among its options.** It was read only as the first word after the name.
- **`amux board add` accepts a title with a quote in it.** The request was built by hand and broke on a quote or a backslash.
- **`./install.sh --client` installs `amux` too.** A client-only install had `amux-remote` and the companions but not the `amux` command that `amux -H`, `amux -A`, `amux up` and `amux search` belong to. It still leaves the dashboard server out.
- The dashboard shows the server's reason when a change is refused, where it showed only the status number.
- `tools/audit-clean` no longer prints awk warnings. A dot in its list of allowed public names matched any character.

## 0.7.3 — 2026-11-23

- **Find a session by its name, on every machine.** `amux search --sessions login` lists the sessions whose name contains "login" on this machine and on every machine you drive, one block per machine, each row as `amux ls` prints it. `-c` gives the compact grid of `amux ls -c`. `--matchstring start|anywhere|end` says where the text must sit, `--regex 'pattern'` takes a regular expression, `-s` matches case exactly, and a machine list or `--local` limits where it looks. It reads names only, so it answers in about a second. See "Finding a session" in the [README](README.md).
- **`amux search -c` now means compact.** To reply to the last `--agentic` answer, use `amux search --continue`. `-c` used to do that; alone, it now tells you so.
- **`amux search` row numbers match `amux ls` again.** Search numbered sessions in file order while `amux ls` sorts them by name, so `amux <row>` after a search could open another session. The hint for opening a hit on another machine named a command that does not exist; it now says `amux pick <box> --sessionid <row>`. A session that shares its folder with another one is no longer missed by `--in name`.
- **`amux rename` renames in place.** It now runs `amux-rename`: the registration, the state file, the running tmux session, the color and the dashboard rows move together and the agent keeps running. Before, it stopped the session, moved only the registration and restarted it. `amux rename -n` shows the plan first.
- **`amux up <name>` works for a session on this machine.** It answered "not a local session" for every local session. A machine can also be given by another of its names.
- **Re-registering a session no longer moves it.** `amux register` or `amux exec` on an existing session without `--dir` kept nothing: the session moved to the current folder and lost the description, tags and pin set in the dashboard. The folder and those fields are now kept; `--dir <path>` or `--pwd` still moves it.
- **Options are checked.** `--strict-mcp-config` no longer swallows the option after it. An option that needs a value says so when the value is missing, where it used to crash. `amux register` refuses what it cannot store, and `amux ls` refuses arguments it does not know, where both used to ignore them.
- **One codex default model.** A codex session started by the server (the dashboard, `amux -H <box> start`, an automatic restart) or switched with `amux provider <name> codex` used an older default model than `amux start`. All of them now use the same one.
- **`amux start-all` starts every session.** It attached to the first one it started and never reached the rest. It now starts each without attaching and reports any that could not start.
- **`amux rm` removes the session's state file too.** Left behind, it was inherited by the next session registered under the same name.
- **A machine that is down says why.** `amux -H <box> provider`, `model`, `account`, `full-access` and `info` answered "could not parse server response", and `curl` exited without a word. Each now names the cause, as `ls` did.
- **Same-machine requests to the dashboard are checked on Linux.** A request from the machine itself skipped the token whoever sent it, so anyone with a login there could drive the sessions and read the token from the dashboard page. It is now skipped only for your own user and root. macOS is unchanged. See [docs/remote.md](docs/remote.md).
- **`amux peek` shows the same amount everywhere.** 30 lines by default, on this machine and through `-H` (which showed 80). The line count must be a number.
- **`amux version` also prints this release.** It printed only the version of the bundled amux program (0.9.x), never the release (0.7.x).
- Tab completion offers only what works where you type it: the attach options (`--mosh`, `--cc`, `--plain`) and `peek --raw` after `-H` or `--find`, `--desc` and `--worktree` after `-H`. `amux help` no longer calls codex "sandboxed" by default and lists the companion commands that exist. `amux-tabs --all` reads session names correctly again and has `--dry-run`. `amux-ls` numbers rows like `amux ls`.

## 0.7.2 — 2026-11-21

- **What each system needs, in one table.** The README's new "What you need" section covers macOS, Linux and Windows: how amux runs on each, what to install and how, and what the sandbox flags add.
- **Windows: WSL2 with Ubuntu 26.04 LTS, step by step.** [docs/windows.md](docs/windows.md) is rewritten around the one supported way to run amux on Windows, from `wsl --install` to `amux-doctor`. MSYS2, Git Bash, psmux and Cygwin are in a separate untested section.
- [docs/sandbox.md](docs/sandbox.md): the install command for each system, Node.js for srt, a note on Ubuntu 24.04's AppArmor restriction, and where the sandboxes have been tested. The README's docs list now includes it.
- `amux-doctor` and `setup/bootstrap` point Windows users to WSL2 with Ubuntu 26.04 LTS.

## 0.7.1 — 2026-11-21

- **Sandboxes keep less of your home readable.** Only program and toolchain folders stay readable (`~/.local/bin`, `~/.local/lib`, `~/.cargo/bin`, `~/.rustup`, `~/.nvm` and the like). The rest of `~/.local/share`, where other programs keep their data and keys, and `~/.cargo`'s credentials are now hidden too.
- **agy and opencode in `--full-sandbox` work on macOS.** Their terminal interface failed to start there (`setRawMode failed`).
- [docs/sandbox.md](docs/sandbox.md) lists the folders that stay readable and two more limits: codex can read a home file created after the session started, and package caches in your home are not writable.

## 0.7.0 — 2026-11-21

- **Sandboxes: `--net-sandbox` and `--full-sandbox`.** The agent's commands can read and write only the session folder, plus read the system and your home toolchains. Every other home folder is hidden from them. `--full-sandbox` also takes away their network. The agent's connection to its model and its web search keep working. Remember a sandbox with `amux register` or `amux exec`, or use it for one launch with `amux start`. claude and codex use their own sandboxes; agy and opencode are wrapped whole (bubblewrap or srt on Linux, Seatbelt or srt on macOS). A launch that cannot be sandboxed is refused. See [docs/sandbox.md](docs/sandbox.md).
- **codex, agy and opencode now default to full access** (no approvals). Before, they ran in their own restricted modes unless you passed `--full-access`. Use a sandbox flag to keep them confined. claude is unchanged.
- `amux -H <machine> exec … --full-sandbox` works too: the server hands a sandboxed start to the command-line `amux`.

## 0.6.2 — 2026-11-17

- **Tab colors over mosh.** mosh does not pass iTerm2's tab-color sequence along, so a session reached by `mosh <box>` and then `amux attach` kept an uncolored tab. When a session runs behind mosh, amux now also connects back over ssh to the machine the mosh came from and paints that tab directly. This needs key-based ssh from the remote machine back to yours; `AMUX_MOSH_RELAY=0` turns it off. See [docs/colors.md](docs/colors.md).

## 0.6.1 — 2026-11-14

- **`amux models` is current again.** The Claude list now shows the `fable` alias, Claude Fable 5.2 and Claude Haiku 5.5. It had stopped at Fable 5.1 and had no `fable` alias, although `--model fable` already worked.
- `amux help flags` names `fable` among the Claude aliases for `--model`.
- Nothing else changes: any full Claude model ID still works with `--model`, whether it is listed or not.

## 0.6.0 — 2026-11-14

- **One color per session**: `amux color`. The session's iTerm2 tab and the square in its status line now share a color, and amux paints the tab every time you attach, however you opened it, not only from `amux-tabs`.
- **20 named colors** instead of 16 similar ones. `amux color palette` lists them.
- **Pick your own**: `amux color <name> orange` (a name or `#rrggbb`) pins it; `next` takes the next color nobody is using; `auto` hands the choice back; `none` turns it off; `--reroll` picks a different automatic one.
- **For one launch**: `--color <c>` on `amux start`, `attach`, `up` and `amux-tabs`. On `amux exec` and `register` it pins the color at creation.
- **Automatic colors no longer collide.** The default mode, `distinct`, gives each session a color no running session has. `amux color --mode hash|row|random` selects the other ways.
- `amux recolor` repaints tabs that are already open. Remote attach colors the tab over ssh and mosh.
- **Tab titles fit the window.** With the status line installed, a window of 110 columns or more is titled `name@machine (O hi)`; a narrower one, such as a laptop screen, gets the session name alone. `title-wide <columns>` in `~/.config/amux/statusline.conf` moves the cut-off.
- **No `[mosh]` in front of the tab title** when you attach with `--mosh`.
- **Tips for a clean iTerm2 tab title**: how to drop `(tmux)`, `(mosh-client)` and the tab numbers. See [docs/statusline.md](docs/statusline.md#tab-titles).
- Upgrading: tab and square colors change once, because the palette is new. Sessions keep the color they get from then on.
- See [docs/colors.md](docs/colors.md).

## 0.5.0 — 2026-11-03

- **Faster `amux search`.** Each machine now keeps the text of its conversations in `~/.amux/cache/search`. The first search builds it (about half a minute for a few GB of history); after that, a search takes a few seconds per machine. Counts are exact. Very long conversations, previously skipped, are now searched too.
- **Several words at once**: `amux search -e login -e oauth`. Sessions that use the words together rank first, then newer ones. `--and` keeps only sessions with every word; `--since 30d` keeps recent ones.
- **`amux search --show [machine] <row|folder> -e word`**: one session's conversations, newest first, with their opening prompts and dated excerpts around the words.
- **Machine groups**: `--corefleet` and `--mainfleet` search the `CORE` and `MAIN` lists in `~/.amux/search-groups.conf`. `--fleetall` is every machine, and `--fleet` still works. Results print as each machine answers.
- **`--agentic` is faster and always shows a result.** It starts with a quick search of the question's main words, prints each step as it goes, searches your CORE group first (this machine if you have no groups), and stops after 10 minutes with what it found by then. It is told to search conversations only, never to run commands on your machines, and more write commands are blocked.
- File names listed in `~/.config/amux/search-exclude.txt` (one per line) are never searched.
- `amux search … | head` no longer ends in a Python error. A search started from inside a Claude Code session doesn't list that session as a match.
- See "Finding a session" in the [README](README.md).

## 0.4.0 — 2026-10-31

- **`amux search`**: find which sessions talked about something. It matches conversations (Claude Code, Codex, OpenCode, Antigravity), the files in each session's folder, and session names, and prints `amux ls` row numbers so `amux <row>` opens the match. Search this machine, a list of machines, or all of them with `--fleet`. Project folders with no session yet are listed too.
- **`amux search --agentic "question"`**: a coding agent runs the searches for you, reads the matching conversations, and ranks the sessions with a reason for each. `amux search -c` asks a follow-up. Pick the agent, model, effort and account with `--provider`, `--model`, `--effort`, `--account`.
- Every plain search ends with a one-line tip showing the `--agentic` version of what you typed.
- See "Finding a session" in the [README](README.md).

## 0.3.1 — 2026-10-30

- **Status line.** New `amux-statusline`: the Claude Code status line built for amux. Each session shows its `amux ls` row number, machine, directory, account, model and effort, context left, tokens, branch and subscription quotas, and sheds parts in a fixed order on narrow panes. Install with `./install.sh --statusline` or `amux-statusline --install`. It backs up `~/.claude/settings.json` first and will not replace a status line you already have without `--force`. See [docs/statusline.md](docs/statusline.md).
- Machine colors come from the host name, or from `~/.config/amux/statusline.conf` (`color`, `strip-prefix`, `quota-log`).
- README: tested terminals (iTerm2 on macOS daily, Linux terminals) and a status line section.

## 0.3.0 — 2026-10-30

- **Full amux included.** The repository now ships a modified amux 0.9.14 (`bin/amux`, `bin/amux-server.py`, `bin/amux-remote`), derived from [mixpeek/amux](https://github.com/mixpeek/amux), alongside the companion tools. `install.sh` installs all of it.
- **`amux up`**: start a session if needed, then attach, in one command (`amux up <name>`, or `amux -H <box> up <name>` on another machine).
- **Accounts.** Bill each session to a different Claude subscription: personal, team and team2 slots (P, T, X), `lib/ccacct.sh`. See [docs/accounts.md](docs/accounts.md).
- `install.sh` adds the `KillMode=process` drop-in where an `amux-serve` unit exists, so restarting the server does not kill your tmux sessions. Shell completion included.
- Windows: WSL is the supported path. Git Bash and MSYS2 are marked untested.
- License: MIT + Commons Clause for the whole repository; upstream copyright kept on derived files.

## 0.2.1 — 2026-07-30

- `amux-remote` and `amux-up` forward start flags, report stop extras loudly, and explain that start is not attach.

## 0.2.0 — 2026-07-29

- Companion tools only (amux itself came from upstream). Hardened remote control, aligned `amux-rename` and `amux-reauth`, `tools/selftest` sandbox test.
