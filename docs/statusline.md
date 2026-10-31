# The amux status line

Claude Code draws one line under the prompt box, and lets a script decide what goes on it. `amux-statusline` is that script, built for running many sessions at once under amux: every session says which one it is, where it runs, what it bills, and how much room it has left.

```
 4  laptop:…/api ○  T  Op5⁵ hi · ctx 82% · in 36k · Σ251k · ⎇ feat/login* · 7d 75% 2d 7h · 5h 61% 3h 29m ↻
```

It is optional. amux works the same without it.

## Install

```sh
./install.sh --statusline        # from the checkout, together with everything else
amux-statusline --install        # or later, on its own
```

Either one writes a `statusLine` entry into `~/.claude/settings.json` that points at the `amux-statusline` command in `~/.local/bin`, so `git pull` in the checkout updates it. It takes effect on the next render; no restart needed.

- A backup is made first: `~/.claude/settings.json.bak-amux-<date>`.
- If you already have a status line, it stops and shows it. `amux-statusline --install --force` replaces it (still with a backup).
- `amux-statusline --uninstall` removes the entry, but only if it is still this one. `./install.sh --uninstall` does that for you.

Needs `python3`. `git` is used for the branch segment only; without it, the branch is simply never shown.

## What each part means

| Part | Example | Meaning |
|---|---|---|
| Session square | ` 4 ` | Row number in `amux ls`, so `amux 4` attaches to this session. The color is fixed per session name |
| Mosh mark | ` 4 M ` | Someone is attached to this session over mosh |
| Machine and directory | `laptop:…/api` | Machine name (one stable color per machine) and the live working directory |
| Focus view | `○` or `◉` | Claude Code's focus (brief) transcript view: `◉` on, `○` off |
| Account | `P`, `T`, `X` | Which subscription this session bills to ([accounts.md](accounts.md)). Blank on a `/login` machine |
| Model and effort | `Op5⁵ hi` | Tier, major version, minor as a superscript (Opus 5.5), then effort: `lo`, `md`, `hi`, `xh`, `mx` |
| Context | `ctx 82%` | Context left before auto-compaction. Green above 50, yellow above 20, then red |
| Next prompt | `in 36k` | Tokens the next prompt sends: system prompt, tools and the whole conversation |
| Session total | `Σ251k` | Tokens over the whole session. Unlike `ctx` and `in`, it survives `/compact` |
| Branch | `⎇ feat/login*` | Shown only when it needs attention: off `main`/`master`, or `*` for uncommitted work |
| Weekly quota | `7d 75% 2d 7h` | Weekly subscription use and time until it resets |
| 5-hour quota | `5h 61% 3h 29m` | Same for the 5-hour window |
| Update | `↻` | A newer Claude Code is ready. Amber: restart the session to use it. Red: brew or npm install, upgrade it yourself |

A few details:

- **Branch from the session root.** The branch comes from the directory the session started in, not wherever a command last `cd`'d to. When the session root holds several repositories but is not one itself, it lists the first one that is off its default branch, plus how many more (`⎇ app:feat/x +1`).
- **Quotas** appear only on Pro/Max plans, and only after the session's first reply.
- **Tab titles.** Inside tmux it also renames the window to `name (O hi)` (model initial and effort), so tab titles in iTerm2 and other terminals show them.

## Narrow panes

When the line does not fit, parts go in this order: branch, then the directory (leaving only the machine name), `Σ`, `7d`, `5h`, `in`, `ctx`. The session square, machine, focus view, account and model always stay, and so does `↻`. Below 100 columns `Σ` is left out even when it would fit.

## Settings

All optional, in `~/.config/amux/statusline.conf`, one per line:

```
# fix the color of a machine whose name contains "desk" (xterm-256 color number)
color desk 208
# show "desk01" instead of "lab-desk01"
strip-prefix lab-
# append each 5h / 7d quota reading to ~/.claude/quota.log (at most once a minute per account)
quota-log on
```

Without a `color` line, each machine gets a color picked from its name, the same on every render. `AMUX_STATUSLINE_CONF=<file>` points at a different file.

## Terminals

I use it daily in iTerm2 on macOS, and it works the same in Linux terminals. A terminal needs:

- **256 colors**: any modern terminal, and tmux with the default `TERM` settings.
- **A font with the symbols** `◉ ○ ⎇ Σ ↻` and superscript digits. Most current monospace fonts have them.
- In iTerm2, leave **"Treat ambiguous-width characters as double width"** off, or the line is measured wrong and gets cut early.

## When it looks wrong

- **Blank line.** Run it by hand with a sample, and any Python error shows:
  `echo '{"model":{"display_name":"Opus 5.5"}}' | amux-statusline`
- **No square number.** The session is not an amux session, or was started outside amux.
- **Different from someone else's.** Check you are both on the same checkout version (`cat VERSION`).
