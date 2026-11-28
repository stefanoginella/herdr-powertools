# Screenshots

How the pictures in `docs/images/` are made, so that they can be taken again after a change, and new ones added.

Every picture is the real app, never a drawing of it, and never my own window. A second Herdr runs in a sandbox, `/var/tmp/herdr-app-demo`, with its own core, its own home and six made-up projects. No real project, session or machine name may show in a picture: `herdr-app` is the one real name allowed.

## Taking them all again

```sh
docs/screenshots/retake.sh
```

It takes about ten minutes. It builds the sandbox from nothing (deleting the last one), starts it, sets the scene, takes the shots, closes it, and frames the shots into `docs/images/`. The sandbox's window opens in a corner of the screen and is minimized at once: your own Herdr is not touched, and can stay open.

It needs macOS, Herdr installed with `herdr-app` and `hc` on the `PATH`, `python3` with [Pillow](https://python-pillow.org), `node`, `rg`, `git`, `rsync` and `cwebp` (`brew install webp`). The shots are 2220×1410, taken on a display of one pixel a point: on a Retina display a shot has twice the pixels, and the boxes in `pictures.json` no longer fit.

Then look at what changed (`git status docs/images`) before committing: the times, the figures and the newest commits in the pictures differ from run to run.

For the indent-guide picture, set `HERDR_SHOTS_APP` to the absolute path of the patched Herdr executable when running `build.sh` or `retake.sh`. The sandbox links that binary for both the window and CLI. It picks up a local release at `build/Herdr Power Tools.app` automatically. With stock Herdr, the full retake preserves the published native guide picture and retakes the others. The `guides` step stages two same-named files and a wrapped line indented with literal tabs.

For a separate run, set `HERDR_SHOTS_DIR` to a fresh short absolute path containing `herdr-app-demo` and `HERDR_SHOTS_SESSION` to a unique short name. If the core socket path is still too long, set `HERDR_SHOTS_SOCKET` to a short path under `/tmp` and use the same environment for each script.

## One step at a time

```sh
cd docs/screenshots
./build.sh              # the sandbox, from nothing
./launch.sh &           # its window; it runs until the window is closed
./scene.sh              # six spaces, their agents, the folders, the editor
./shoot.sh              # every raw shot, or only some steps: ./shoot.sh git usage
./make.sh               # every picture into docs/images, or only some: ./make.sh usage
. ./lib.sh              # in bash: herdr-app and hc now talk to the sandbox
look hero               # a half-size copy of a shot, in the sandbox's look/
quit_sandbox            # close the window and stop its core
```

| File | What it does |
|---|---|
| `lib.sh` | Where the sandbox is, its environment, and the helpers: `h` (a command), `req` (steps through the stage mod, then draws), `zoom`, `shot`, `look`, `open_file`, `quit_sandbox` |
| `build.sh` | The sandbox: stubs for `docker`, `ddev`, `gh` and the programs a mod could start, a fake home with this setup's mods and layout as they are in the working folder, the fake projects, and a copy of this repository as it is committed, with branches, a pull request and uncommitted changes to draw |
| `launch.sh` | Starts the sandbox's Herdr with a clean environment |
| `scene.sh` | The scene every picture starts from |
| `shoot.sh` | The raw shots, in steps: `diff editor guides files search goto git sidebar window usage review ci tools spotify` |
| `spotify-osascript.sh` | The sandbox substitute for Spotify's macOS scripting helper. The Spotify step stages [Stargazer by Bird of Prey](https://open.spotify.com/track/1gWKIOySPIvxvV3GwGA5Rf), with its public Spotify cover and two fictional pins. It captures the player and both transport states. Other steps see a closed player. |
| `pictures.json` | Every picture: its canvas, and which parts of which shots go where |
| `frame.py` | Draws them: the backdrop, each part as a card with rounded corners, a hairline and a shadow |
| `make.sh` | Runs `frame.py`, then saves each picture as lossless WebP in `docs/images/` |
| `lines.py` | Prints a shot's long one-pixel lines, which are the borders of its panes and panels: for reading a crop box |
| `gen-usage.mjs` | A year of fake Claude and Codex sessions for the Usage pictures, made relative to now |
| `stage/` | A mod put in the sandbox only: it sets shared state, opens overlays and runs commands, as told in a JSON file |
| `agents/` | The stand-in agents: a screen each, printed by `run.sh`, which also reports the agent's status |

## What a picture is

- **One canvas:** 1680×1050, the README's column at two pixels a point. The overview is 2520×1575, the same shape, and the Usage and File Editor pictures are taller.
- **One backdrop**, a gradient in the app's own grey-blue, with rounded corners.
- **Cards:** each a part of a shot at the app's own pixels, never scaled, and cut by the canvas's edge when it is larger. A small feature is shot at a higher zoom, not enlarged.
- **The window's three buttons** are drawn back in where a card shows the window's top left corner: the system draws them, so a shot has none.
- **Lossless WebP**, about a third of the same PNG.

The layout gallery preview (`preview.png`) and the README cover (`docs/images/power-tools.webp`) are the same card in two formats. They use the same renderer, fonts and backdrop as the feature gallery previews, with crops from the published Usage, Spaces Sidebar and Git Panel screenshots. Run `python3 docs/gallery.py` from the repository root to rebuild the covers and gallery previews after remaking those screenshots. `retake.sh` does this for a full retake.

## Changing a picture, or adding one

1. **Stage it** in a step of `shoot.sh`, and end with `shot <name>`. What can be driven from a shell: any app command (`h`), an overlay with props, and the requests the mods take from shared state (`req`; each mod's notes in `docs/agents/` say which it takes). What can't: typing, hovering, dragging and selecting. A picture that needs one of those can't be taken this way.
2. **Look:** `./shoot.sh <step>`, then `look <name>`, or `look <name> x y w h` for a part at full size.
3. **Read the box** of the pane, panel or dialog: `python3 lines.py /var/tmp/herdr-app-demo/raw/<name>.png` lists its borders. A box is `[x, y, width, height]`, borders included.
4. **Place it** in `pictures.json`: a card's `at` is where its top left goes on the canvas, and a card may go past the bottom or the side. Then `./make.sh <name>`.
5. **Show it** in the README's tour or on the feature's page.

A change to a zoom, to a panel's width or to how a pane is split moves the boxes of every shot it touches: measure them again.

## What trips the staging up

- **In the background nothing is drawn**, and a mod takes a request left in shared state only when it draws. A shot makes it draw, which is what `draw` and `req` do. A request not taken within about ten seconds is dropped as stale.
- **The mods read nothing while Herdr is not the active app.** `build.sh` tells the sandbox's copies that it always is.
- **A pointer over the window leaves hover marks** in the shots, and they stay once the window is minimized. If a shot shows one, take the pointer away from the screen's bottom right corner and run the step again in a fresh sandbox.
- **The Usage dialog keeps its layout through a zoom change:** close it and open it again.
- **The diff step selects Split explicitly.** It produces the same layout if the step is run again in the same sandbox.
- **An overlay's `at` is in window pixels**, not in the app's own.
- **The usage data is made relative to now:** "Burning now" is the last hour, so shoot within a few minutes of `gen-usage.mjs`. The home is given to it as `/var/tmp/...`, not `/private/var/tmp/...`: the dialog files the second under "Other folders".
- **The demo repository's uncommitted change is written against `packages/git-panel/mods/git-panel/git.js` as it is now.** When that file's `ago()`, `initials()` or `MONTHS` change, `build.sh` stops and says which: write the demo change again.
- **A mod first seen without a `mod.json` is docked into the layout:** `stage/` has one, and goes in whole.

---

[Back to the README](../../README.md)
