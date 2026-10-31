# Using more than one Claude subscription

If you have one Claude subscription and sign in with `/login`, skip this page — amux works without it.

It is for when you have **several** — say a personal plan plus a seat in a team or organization — and want to choose, per session, which one a session bills to. amux calls these **accounts** and gives each one a short letter:

| Account | Letter | Slot file (mode 600) | Typical use |
|---|---|---|---|
| `personal` | **P** | `~/.config/claude-code/env` | your own plan; the default |
| `team` | **T** | `~/.config/claude-code/env.team` | a Team or Enterprise seat |
| `team2` | **X** | `~/.config/claude-code/env.team2` | a second org or seat |

All three are optional. A machine with no slot files at all simply uses Claude Code's own `/login`. The names are just labels — `team` does not have to be a Team plan.

Accounts only apply to **claude** sessions (and iTerm2 tabs, which run claude). For codex, gemini, opencode and agy, `--account` is accepted and ignored.

## 1. Mint a token for each account

Each slot holds a long-lived token from `claude setup-token`. Run it in a normal terminal — **not** inside an agent session, where the token would be written into the transcript:

```sh
claude setup-token
```

It opens a browser. **Sign in as the account you want for this slot** (use a private window, or a browser profile that is signed in to that account, so you do not mint the wrong one). It prints a token that starts with `sk-ant-oat`. Repeat for each account.

## 2. Store each token in its slot

Paste each token at a silent prompt, so it never appears on screen, in your shell history, or on a command line (`ps` shows command lines to every user on the machine):

```sh
umask 077; mkdir -p ~/.config/claude-code
printf 'Paste the TEAM token: '; IFS= read -rs TOK; echo
printf 'export CLAUDE_CODE_OAUTH_TOKEN=%s\nexport CLAUDE_ACCOUNT=team\n' "$TOK" > ~/.config/claude-code/env.team
unset TOK; chmod 600 ~/.config/claude-code/env.team
```

Same for `env` (with `CLAUDE_ACCOUNT=personal`) and `env.team2` (with `CLAUDE_ACCOUNT=team2`). Check without printing anything secret:

```sh
ls -l ~/.config/claude-code/          # every slot should be -rw-------
check-claude-auth team                # probes that slot's token directly (no value printed)
```

To put a slot on another machine, copy the file over SSH, which keeps it off every screen: `scp -p ~/.config/claude-code/env.team box1:.config/claude-code/` (create the directory there first with `mkdir -m 700`).

## 3. Log out of the browser session — the shadowing trap

If a machine has **both** a token slot **and** a stored browser login, interactive sessions prefer the browser login and do **not** fall back to the token when that login expires (about 8 hours later). Every session then stops at `Please run /login · 401`, even though the token is fine.

So on any machine where you use slots, remove the stored login once:

```sh
claude auth logout
```

`check-claude-auth` detects this condition, and `amux-reauth --all` fixes it for running sessions. Full explanation: [auth.md](auth.md).

The trade-off: a machine authenticated only by tokens cannot use Claude in Chrome (browser control needs `/login`). Keep `/login` on the one computer where you want browser control, and do not put slots there.

## 4. Pick the account per session

```sh
amux exec api --provider claude --dir ~/projects/api --account team    # stored with the session
amux start api --account personal                                      # this launch only
amux account api                                                       # show it
amux account api X                                                     # change it (session must be stopped)
amux -H box1 exec api --provider claude --dir ~/projects/api --account T   # same, on another machine
```

With no `--account`, a new session takes the account of the terminal you launch it from (`$CLAUDE_ACCOUNT`), else `personal`.

A session whose slot is missing on that machine **refuses to start** rather than silently billing a different subscription.

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

Mint a new one with `claude setup-token`, overwrite the slot file the same way, then restart the sessions that use it (`amux stop <name>; amux start <name>` — the conversation resumes). Minting a new token does **not** revoke the old one; revoke it in your Claude account settings if it may have leaked.
