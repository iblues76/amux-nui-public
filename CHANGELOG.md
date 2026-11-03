# Changelog

What changed in each release of amux-nui-public, newest first. From 0.3.0 on, every release is a git tag (`v0.3.1`) and a tarball on the [download page](https://amux.nuilab.org/download/).

## 0.5.0 — 2026-11-03

- **Faster `amux search`.** Each machine now keeps the text of its conversations in `~/.amux/cache/search`. The first search builds it (about half a minute for a few GB of history); after that, a search takes a few seconds per machine. Counts are exact. Very long conversations, previously skipped, are now searched too.
- **Several words at once**: `amux search -e login -e oauth`. Sessions that use the words together rank first, then newer ones. `--and` keeps only sessions with every word; `--since 30d` keeps recent ones.
- **`amux search --show [machine] <row|folder> -e word`**: one session's conversations, newest first, with their opening prompts and dated excerpts around the words.
- **Machine groups**: `--corefleet` and `--mainfleet` search the `CORE` and `MAIN` lists in `~/.amux/search-groups.conf`. `--fleetall` is every machine, and `--fleet` still works. Results print as each machine answers.
- **`--agentic` is faster and never comes back empty-handed.** It starts with a quick search of the question's main words, prints each step as it goes, searches your CORE group first (this machine if you have no groups), and stops after 10 minutes with what it found by then. It is told to search conversations only, never to run commands on your machines, and more write commands are blocked.
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
