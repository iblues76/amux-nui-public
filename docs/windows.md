# Windows

amux runs each agent session inside **tmux**, and tmux is a Unix program. That single fact decides everything below: what works natively on Windows, what needs WSL, and what cannot work at all.

Good news: even where you cannot run sessions locally, you can in principle still **drive** other machines. `amux-remote`, `amux-all`, `amux-ls`, `ccjump` and `amux-config` are just HTTPS and SSH — they need no tmux whatsoever. In practice that is **untested** outside WSL: the bundled `amux-remote` has not been tried under Git Bash or MSYS2.

## The four setups

| Setup | Run sessions here | Drive other machines | Claude in Chrome |
|---|---|---|---|
| **WSL2** | yes | yes | **no** — unsupported in WSL |
| **MSYS2 + tmux** | probably — verify | untested | yes |
| **Git Bash** (no tmux) | no | untested | yes |
| **Scoop + psmux** | experimental | untested | yes |

Run **`amux-doctor`** to find out which one you actually have. It does not guess from version strings: it starts a throwaway tmux session and runs the exact calls amux depends on (`new-session`, `has-session`, `list-sessions`, `send-keys`, `capture-pane`, `set-environment`), then tells you which ones worked.

## Which should you pick?

**Use WSL2 if you want the full thing on one machine.** It is real Linux, so amux behaves exactly as it does on a Mac or a server. The cost is browser control: Claude in Chrome [is not supported in WSL](https://code.claude.com/docs/en/chrome).

```powershell
wsl --install -d Ubuntu
```

Then inside the WSL terminal, follow the normal Linux install in the [README](../README.md).

**Try Git Bash if this machine is a control station.** You sit at Windows, your sessions run on a Linux box or a Mac. Nothing to install beyond [Git for Windows](https://git-scm.com/downloads/win) and this repo. `amux-doctor` will tell you local sessions are unavailable — that is expected and fine. This path is **untested** with the bundled `amux-remote`. If you need a control station that is known to work, use WSL2.

**Try MSYS2 if you want sessions locally without WSL, and want browser control.** MSYS2 ships a genuine [tmux 3.6](https://packages.msys2.org/packages/tmux?variant=x86_64):

```sh
pacman -S tmux
```

The honest caveat: this path is **untested**. MSYS2 has no real Linux kernel, and [some tmux behavior differs](https://tmux.app/install/windows/), particularly around sockets. It may work perfectly for you. Run `amux-doctor` and believe what it reports rather than what this table says.

**Scoop users:** Scoop's answer is [psmux](https://github.com/psmux/psmux), a tmux-compatible multiplexer written in Rust. It is not tmux. amux calls tmux in roughly fifty places, and psmux compatibility with all of them is unverified. `amux-doctor` will tell you where it stands on your machine. Treat it as experimental.

Cygwin also provides tmux and gets the same treatment: try it, then run `amux-doctor`.

## Package managers

The setup scripts detect whichever you have — `winget`, `scoop`, `choco`, or MSYS2's `pacman` — and use it. You do not have to standardize on one.

- **Scoop** installs per-user and needs no administrator rights, which matters on a locked-down lab machine.
- **WinGet** ships with Windows 11 and knows Claude Code: `winget install Anthropic.ClaudeCode`.
- **Chocolatey** works but wants administrator rights.
- **MSYS2 pacman** is the only one of the four that can give you tmux.

Downloading is detected the same way: `curl` (built into Windows 10 1803 and later), `wget`, or PowerShell's `Invoke-WebRequest`.

## Installing Claude Code on Windows

Install it **natively**, from PowerShell, even if you plan to use Git Bash:

```powershell
irm https://claude.ai/install.ps1 | iex
```

It lands on the Windows PATH, so Git Bash finds it too. If you are using WSL, install it *inside* the WSL distro instead, with the Linux installer — a Windows install is not visible to WSL.

## Serving from Windows

Running `setup/serve-install` on Windows has a real limitation: outside WSL there is no per-user service manager equivalent to launchd or systemd, so it starts the server but cannot make it start automatically at login. Use Task Scheduler for that.

Under WSL there is a sharper gotcha: **a WSL distro shuts down when its last shell exits**, taking your server with it. If other machines need to reach this one, keep a terminal open, or configure the distro to stay running. For a machine that should always be reachable, a Linux box or a Mac is a better host.

## What to do if `amux-doctor` says tmux is missing calls

That machine cannot reliably run sessions locally. You have three options, in order of least work:

1. Use it as a control station and run sessions on another machine. Everything in this repo except local session management should still work, though that is untested.
2. Install MSYS2 and its real tmux.
3. Move to WSL2, accepting the loss of browser control from those sessions.
