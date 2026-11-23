# Using more than one Claude subscription

If you have one Claude subscription and sign in with `/login`, you can skip this page. amux works without it.

This page is for when you have several subscriptions, for example a personal plan and a seat in a team or organization, and you want to choose which one each session bills to. amux calls them **accounts** and gives each one a letter:

| Account | Letter | Slot file (mode 600) | Typical use |
|---|---|---|---|
| `personal` | **P** | `~/.config/claude-code/env` | your own plan; the default |
| `team` | **T** | `~/.config/claude-code/env.team` | a Team or Enterprise seat |
| `team2` | **X** | `~/.config/claude-code/env.team2` | a second org or seat |

All three are optional. A machine with no slot files uses Claude Code's own `/login`. The names are only labels, so `team` does not have to be a Team plan.

Accounts apply only to claude sessions (and to iTerm2 tabs, which run claude). For codex, gemini, opencode and agy, `--account` is accepted and ignored.

## 1. Create a token for each account

Each slot holds a long-lived token from `claude setup-token`. Run that command in a normal terminal, not inside an agent session, where the token would be written into the transcript:

```sh
claude setup-token
```

It opens a browser. Sign in as the account you want for this slot. Use a private window, or a browser profile that is signed in to that account, so that you do not create a token for the wrong one. The command prints a token that starts with `sk-ant-oat`. Repeat this for each account.

## 2. Store each token in its slot

Paste each token at a silent prompt, so it never appears on screen, in your shell history, or on a command line (`ps` shows command lines to every user on the machine):

```sh
umask 077; mkdir -p ~/.config/claude-code
printf 'Paste the TEAM token: '; IFS= read -rs TOK; echo
printf 'export CLAUDE_CODE_OAUTH_TOKEN=%s\nexport CLAUDE_ACCOUNT=team\n' "$TOK" > ~/.config/claude-code/env.team
unset TOK; chmod 600 ~/.config/claude-code/env.team
```

Do the same for `env` (with `CLAUDE_ACCOUNT=personal`) and `env.team2` (with `CLAUDE_ACCOUNT=team2`). Then check the slots. These commands print nothing secret:

```sh
ls -l ~/.config/claude-code/          # every slot should be -rw-------
check-claude-auth team                # probes that slot's token directly (no value printed)
```

To put a slot on another machine, copy the file over SSH, which keeps it off every screen: `scp -p ~/.config/claude-code/env.team box1:.config/claude-code/` (create the directory there first with `mkdir -m 700`).

## 3. Log out of the browser session

If a machine has both a token slot and a stored browser login, interactive sessions use the browser login, and they do not fall back to the token when that login expires, about 8 hours later. Every session then stops at `Please run /login · 401`, although the token is still valid.

So on any machine where you use slots, remove the stored login once:

```sh
claude auth logout
```

`check-claude-auth` detects this condition, and `amux-reauth --all` fixes it for running sessions. [auth.md](auth.md) explains it in full.

This has a cost: a machine that signs in only with tokens cannot use Claude in Chrome, because browser control needs `/login`. Keep `/login` on the one computer where you want browser control, and do not put slots there.

## 4. Pick the account per session

```sh
amux exec api --provider claude --dir ~/projects/api --account team    # stored with the session
amux start api --account personal                                      # this launch only
amux account api                                                       # show it
amux account api X                                                     # change it (session must be stopped)
amux -H box1 exec api --provider claude --dir ~/projects/api --account T   # same, on another machine
```

With no `--account`, a new session takes the account of the terminal you launch it from (`$CLAUDE_ACCOUNT`), else `personal`.

A session whose slot is missing on that machine does not start. It never bills a different subscription instead.

`amux ls` shows the account in front of every claude session: `P:cc:api`, `T:cc:api`, `X:cc:api`. The web dashboard shows the same letter on each card; click it to change the account of a stopped session.

## 5. Switch the terminal itself (optional)

`lib/ccacct.sh` adds two shell functions. Source it from your rc file:

```sh
echo '. ~/path/to/amux-nui-public/lib/ccacct.sh' >> ~/.zshrc     # or ~/.bashrc
```

```sh
ccacct                 # which account this terminal uses
ccacct team            # switch this terminal (plain `claude` and new amux sessions follow)
ccrun team2 claude     # run one command on another account; the terminal stays as it was
```

## Rotating a token

Create a new token with `claude setup-token`, overwrite the slot file the same way, then restart the sessions that use it (`amux stop <name>; amux start <name>`). The conversation resumes. A new token does not revoke the old one. If the old one may have leaked, revoke it in your Claude account settings.
