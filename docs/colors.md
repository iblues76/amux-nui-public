# Colors: one per session

Each session has a color. It is the color of the session's **iTerm2 tab** and of the **square in the status line**, so the two always match. amux paints the tab whenever you attach (`amux start`, `amux attach`, `amux up`, `amux-tabs`, and `amux -H <box> attach` over ssh or mosh) and clears it when you detach.

```sh
amux color                    # every session and its color
amux color palette            # the 20 named colors
amux color api                # one session's color
```

## Choosing a color

| You type | What happens |
|---|---|
| `amux color api orange` | Pins orange for `api`. It stays until you change it. |
| `amux color api '#ff8800'` | Pins any color. The status line uses the nearest terminal color. |
| `amux color api next` | Pins the next color that no running session is using. |
| `amux color api auto` | Unpins: amux chooses again. |
| `amux color api none` | No tab color for this session. |
| `amux color api --reroll` | Keeps it automatic but picks a different color. |
| `amux start api --color teal` | Teal for this launch only. Also works on `attach`, `up` and `amux-tabs`. |
| `amux exec api --provider claude --color teal` | Pins teal when the session is created (`register` too). |

A color given on the command line wins over a pinned color, and a pinned color wins over the automatic choice. If the session is running, pinning repaints its open tab at once. `amux recolor` repaints the open tabs of every running session, or of the ones you name.

## The 20 colors

red, blue, yellow, green, magenta, orange, cyan, purple, lime, pink, teal, brown, indigo, olive, crimson, forest, sky, salmon, lavender, silver.

They are ordered so that the first ones handed out are the easiest to tell apart. The number inside the status line square turns black or white to stay readable on its color.

## How the automatic color is chosen

```sh
amux color --mode             # show the mode
amux color --mode distinct    # set it
```

| Mode | Behavior |
|---|---|
| `distinct` (default) | A color no running session has. amux remembers it, and changes it only if it would clash with a session that is already open. |
| `hash` | Derived from the session's name. Always the same, but two sessions can share a color. |
| `row` | Follows the session's `amux ls` row. |
| `random` | A new color at every start. |

With more than 20 sessions running at once, colors repeat.

## Terminals

Tab colors need iTerm2. amux recognizes it on its own; in other terminals nothing is sent. `AMUX_TABCOLOR=0` turns tab painting off, and `AMUX_TABCOLOR=1` forces it when iTerm2 is not recognized (for example behind an ssh server that drops the terminal's name). The status line square works in every terminal.

Two limits:

- With iTerm2's tmux integration (`--cc`), iTerm2 creates the tabs itself and they are not colored.
- mosh does not pass the color sequence along. amux works around it: when the session runs behind a mosh connection, it also connects back over ssh to the machine the mosh came from and paints that tab directly. This works whether you used `amux -H <box> attach --mosh` or ran `mosh <box>` yourself and then `amux attach` there, but only if the remote machine can ssh back to yours without a password (key login). Otherwise the tab keeps the color set at attach, if any. `AMUX_MOSH_RELAY=0` turns the connect-back off.

Colors are stored in `~/.amux/colors.json` on the machine that runs the session.
