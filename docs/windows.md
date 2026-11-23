# Windows

On Windows, amux runs inside **WSL2** (Windows Subsystem for Linux), a real Linux that runs alongside Windows. The recommended distribution there is **Ubuntu 26.04 LTS**, which gets updates until 2031.

Plain Windows (PowerShell, Command Prompt, Git Bash) cannot run amux sessions. amux runs every agent inside tmux, and tmux needs Linux or macOS. Claude Code itself does run on plain Windows, but amux does not.

## What you need

- Windows 11, or Windows 10 version 2004 or later.
- Hardware virtualization turned on in the PC's firmware. Most PCs have it on: Task Manager, Performance, CPU shows "Virtualization: Enabled".
- Administrator rights once, to install WSL.

## Set it up

1. Open **PowerShell as administrator** (right-click PowerShell, then "Run as administrator") and run:

   ```powershell
   wsl --install -d Ubuntu-26.04
   ```

   This turns WSL on and installs Ubuntu 26.04 LTS. Restart Windows if it asks you to.

2. Open **Ubuntu 26.04** from the Start menu (or run `wsl -d Ubuntu-26.04`) and choose a Linux user name and password. Every step below runs in this Ubuntu terminal.

3. Install what amux needs:

   ```sh
   sudo apt update
   sudo apt install -y git tmux python3 curl fzf
   sudo apt install -y bubblewrap socat      # only for --net-sandbox and --full-sandbox
   ```

4. Install your coding agent **inside Ubuntu**. For Claude Code:

   ```sh
   curl -fsSL https://claude.ai/install.sh | bash
   ```

   An agent installed on Windows is not visible inside WSL. The same goes for Codex, Gemini CLI, OpenCode and Antigravity: install them in Ubuntu.

5. Install amux as in the [README](../README.md#install):

   ```sh
   git clone https://git.nuilab.org/f.ortega/amux-nui-public.git
   cd amux-nui-public && ./install.sh && amux-doctor
   ```

   `amux-doctor` reports the platform as "Windows (WSL)" and lists anything still missing.

## Good to know

- **Keep your projects in Ubuntu's home folder** (`~/...`), not under `/mnt/c/`. Files on the Windows drive work, but they are much slower from WSL.
- **Windows Terminal**, built into Windows 11, is a good terminal for this. Ubuntu appears in its new-tab menu.
- **Claude in Chrome does not work from WSL**, so sessions there have no browser control. See [auth.md](auth.md).
- **WSL shuts down when its last terminal closes**, and amux's server stops with it. If other machines drive this one, keep an Ubuntu terminal open. For a machine that should always be reachable, a Linux box or a Mac is a better host.
- **Sandboxes** need bubblewrap and socat (step 3). They have not been tested in WSL yet. amux refuses a sandbox it cannot apply and says why, so nothing runs unconfined by mistake. See [sandbox.md](sandbox.md).
- **Another distribution** works too (`wsl --list --online` shows them). The steps above assume Ubuntu's `apt`.

## Without WSL (untested)

These setups may work, but none has been tested with this repo. Run `amux-doctor` and go by its report. It starts a temporary tmux session and tries every tmux call that amux depends on (`new-session`, `has-session`, `list-sessions`, `send-keys`, `capture-pane`, `set-environment`).

| Setup | Run sessions here | Drive other machines | Claude in Chrome |
|---|---|---|---|
| **MSYS2** with its tmux | untested | untested | yes |
| **Git Bash** (no tmux) | no | untested | yes |
| **Scoop** with psmux | untested | untested | yes |
| **Cygwin** with its tmux | untested | untested | yes |

- **MSYS2** has a real [tmux](https://packages.msys2.org/packages/tmux?variant=x86_64) (`pacman -S tmux`). It has no Linux kernel, though, and [some tmux behavior differs](https://tmux.app/install/windows/), particularly around sockets.
- **Git Bash** has no tmux, so at most it can drive amux on other machines. `amux-remote`, `amux-all`, `amux-ls`, `ccjump` and `amux-config` need only SSH and HTTPS, not tmux.
- **psmux**, which Scoop installs, is a tmux-like program written in Rust, not tmux. amux calls tmux in about fifty places, and psmux has not been checked against them.
- **Claude Code** for these shells is installed on Windows itself, from PowerShell: `irm https://claude.ai/install.ps1 | iex`, or `winget install Anthropic.ClaudeCode`. It lands on the Windows PATH, so Git Bash finds it too.
- **Package managers:** the setup scripts use whichever one you have: `scoop` (needs no administrator rights), `winget`, `choco` or MSYS2's `pacman`. Only MSYS2's `pacman` can give you tmux.
- **Serving:** outside WSL there is no service manager like launchd or systemd, so `setup/serve-install` starts the server but cannot start it at login. Use Task Scheduler for that.

If `amux-doctor` says tmux is missing calls amux needs, that machine cannot reliably run sessions. Use WSL2 as above.
