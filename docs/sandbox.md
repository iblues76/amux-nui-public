# Sandboxes

Two flags keep an agent's commands inside the session folder:

| Flag | Files the agent's commands can use | Network for those commands |
|---|---|---|
| `--net-sandbox` | read and write the session folder; read the system and the program folders in your home | yes |
| `--full-sandbox` | the same | no |

In both modes, every other folder in your home (and every other user's) is hidden from the commands the agent runs. The program folders that stay readable are `~/.local/bin`, `~/.local/lib`, `~/.local/share/uv`, `~/.local/share/pipx`, `~/.cargo/bin`, `~/.rustup`, `~/.nvm`, `~/.pyenv`, `~/.rbenv`, `~/.sdkman`, conda installs, `~/.gitconfig` and similar; app data such as the rest of `~/.local/share` stays hidden. The agent's own connection to its model, and its provider-side web search, are not commands and keep working.

Without a flag, codex, agy and opencode run with full access, and claude keeps the permission mode from your Claude Code settings.

## Using it

```sh
amux exec review --provider codex --dir ~/Dev/myapp --full-sandbox   # remembered for every start
amux register api --provider claude --net-sandbox                     # same, without starting
amux start review --net-sandbox                                       # this launch only
amux -H otherbox exec job --provider opencode --dir '~/x' --full-sandbox
```

A one-shot `--full-access` on `amux start` drops a remembered sandbox for that launch. A sandbox flag cannot be combined with `--full-access`, and the two sandboxes cannot be combined with each other.

If a sandbox cannot be applied on the machine, the launch is refused with the reason. It never falls back to running unconfined.

## How each agent is confined

| Agent | Mechanism |
|---|---|
| claude | Claude Code's own sandbox for shell commands (bubblewrap on Linux, Seatbelt on macOS), plus `permissions.blockReadsOutsideWorkingDirectories` and `blockWritesOutsideWorkingDirectories` for its file tools. It stays in your usual permission mode. |
| codex | A permission profile generated for the folder (`~/.codex/amux-sbx-*.config.toml`) with `-a never`. |
| agy | The whole agent is wrapped. |
| opencode | The whole agent is wrapped, and runs with `--auto` inside the wrapper. |

Wrapping uses bubblewrap on Linux and Seatbelt on macOS for `--net-sandbox`. On macOS, srt is also allowed pseudo-terminal operations, which the agents' terminal interfaces need. For `--full-sandbox` it uses [srt](https://github.com/anthropic-experimental/sandbox-runtime) (Anthropic's sandbox runtime), which lets only the agent's own model endpoints through: for opencode, the hosts in `opencode.json` and of the providers you signed in to; for agy, Google's API hosts.

The generated settings live in `~/.amux/sandbox/` and are rewritten at every start. `amux-sandbox explain` prints this summary on any machine.

## Requirements

| System | Needs | Install |
|---|---|---|
| macOS | nothing extra (`/usr/bin/sandbox-exec` is built in) | nothing to install |
| Linux, WSL2 | bubblewrap and socat | `sudo apt install bubblewrap socat` or `sudo dnf install bubblewrap socat` |
| `--full-sandbox` for agy or opencode, any system | srt, which runs on Node.js | `npm install --prefix ~/.amux/sandbox @anthropic-ai/sandbox-runtime` |

Native Windows is not supported. Run amux inside WSL2; [windows.md](windows.md) has the steps.

**Ubuntu 24.04** restricts the user namespaces that bubblewrap relies on (an AppArmor setting), so bubblewrap may not start there. amux then refuses the sandbox and prints why. Ubuntu 26.04 ships an AppArmor profile for bubblewrap.

**Tested so far** on Fedora 44 (all four agents) and macOS (claude, codex and opencode). Ubuntu and WSL2 have not been tested yet.

## Limits

- **MCP servers run outside the sandbox** for claude and codex. Those agents start them as their own processes, so an MCP server keeps its normal file and network access. For agy and opencode the MCP servers run inside the wrapper.
- **codex: files created later.** codex's profile lists the entries in your home folder when the session starts, so a file or folder created in a home folder after that is readable to its commands until the next start. claude, agy and opencode hide the whole home folder and do not have this gap.
- **Package caches in your home are not writable** (`~/.npm`, `~/.cache/pip`, `~/.cargo/registry`). Point the tool at the session folder instead, for example `npm --cache ./.npm` or `CARGO_HOME=./.cargo`.
- **A wrapped agent can read its own configuration**, including the API keys it needs (`~/.config/opencode`, `~/.gemini`), because the agent and its commands share one sandbox.
- **Claude with `--net-sandbox`:** in auto mode, a command has to name the host it needs, and auto mode approves it. Claude does this when it is told a command was blocked.
- **Writes outside the folder** fail, or land in a temporary layer that is thrown away when the command ends. Nothing reaches your real home folder.
- `--net-sandbox` and `--full-sandbox` are not available for `iterm2` sessions.
- **codex may decline instead of trying.** The codex model reads its permission profile and can refuse a command that touches a denied path rather than run it and be blocked. Either way the path stays closed.
