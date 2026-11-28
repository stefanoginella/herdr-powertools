# Spotify Mini

A macOS-only local player for the Power Tools status row. Its playback notification listener in `macos.jxa` is adapted from the MIT-licensed macOS helper in [jeffarese/herdr-spotify](https://github.com/jeffarese/herdr-spotify/blob/4eef56bb58d70e858a52c257936a56b5a57a79cb/mods/spotify/macos.jxa). The upstream notice is in the mod's LICENSE.

## Files and state

- `main.js` reads the block ID and overlay ID in init, handles commands and input, resizes the status block and owns the pin form. The status copy waits for Spotify notifications with a 20-second fallback. The open dialog rereads while active. Track details stay in memory.
- `views.js` draws the status item, player and pin form with native controls and the small SVGs beside it. `mod.json` declares the player and palette entry. The root keymap supplies Ctrl+Cmd+M to open the player and Ctrl+Cmd with P, Left/Right, Up/Down or L for playback, track navigation, volume or Like. Herdr 0.1.18 broadcasts mod commands to all shown copies. The status block handles global keys when mounted, and a standalone dialog handles them in a layout without that block.
- `macos.jxa` runs locally through osascript. Read and wait check for a running app without launching it. Like checks the track identity before and after bringing Spotify to the front, targets its process and restores the previous app if Spotify still owns focus. My Playlists deliberately leaves Spotify in front. The two shortcuts come from [Spotify Support](https://support.spotify.com/us/article/keyboard-shortcuts/).
- `pins.js` validates playlist links, discards tracking parameters and upserts by ID. `data/spotify-mini/playlists.json` is the private pin list. Saving rereads the current file and uses its text as the expected value. A write conflict or malformed file keeps the form open with an error. `spotify.test.mjs` covers pin identity and the JXA shortcut behavior with a simulated desktop.

## Behavior to preserve

Playing and paused both use 320 px with the same title, artist and four buttons. The equalizer animates while playing and rests otherwise. Empty or closed uses a 32 px equalizer launcher. `display.js` defines these widths, the zoom-adjusted overflow distance and the cache path for Spotify CDN covers. The heart means toggle and shows a neutral outline because Spotify does not report a dependable saved state. A different song or an advertisement cannot receive a pending Like. A failed shortcut must leave an actionable error and keep the user's library untouched.

Measure the clipped box and unwrapped text separately. The GPU loops the horizontal offset only when there is overflow. Keep controls outside the moving labels. The player asks for the CDN image when the cover changes, caches eight images in private `data/spotify-mini/art/` and shows its record sleeve on errors. A late cover response cannot replace a newer track's cover. The full Spotify wordmark in the player comes from the official [brand downloads](https://developer.spotify.com/documentation/design#using-our-logo).

Use the local OS to detect macOS. On cold start the status block initializes before `window().platform` is available. Using the window there leaves the status bar empty until a reload.

The status block's title and tooltip respect Hide Names. The open player shows the content the user selected. Typing a playlist name or pasting a link must never trigger playback. Opening or removing a pin only navigates to it or removes its local shortcut. All music commands act on this Mac even in remote project spaces.

Transport commands update the visible play/pause state on press, queue skips in order and coalesce only adjacent pending volume values. A readback runs after dispatch and never holds the input queue. Ignore observations that predate a later action or a newer snapshot. A paused observation without metadata retains the last loaded track. A rendered Pause button sends only Pause. The handler holds its requested state through stale observations and confirms it twice. If the same track is still playing, it can queue one more explicit Pause. Newer input supersedes that check. Like and My Playlists can require an OS permission dialog and run independently of transport.

## Trying it

Run `node --test packages/spotify-mini/mods/spotify-mini/spotify.test.mjs` and the native mod check. For the screenshot sandbox, use the `spotify` step. The stand-in supplies the requested Stargazer recording and fictional playlist pins. Physical typing, slider dragging and the live account's Like/Dislike toggle require a manual check.

Herdr 0.1.18 rendered the playing and idle status item and the panel in an isolated window. A test copy exercised the real input states, saved and removed a pin, opened its canonical URI and dispatched play/pause, both track changes, both volume steps, Like and My Playlists to the stand-in. The native macOS helper also read the installed player's state and completed its notification wait.

Successive native frames at 2× zoom showed the changing slices of a long title and artist with the status controls stationary. A fresh launch showed the status block independently of the dialog. Both states keep the Play/Pause center at the same window coordinate. The production artwork helper also downloaded and decoded a cover from the installed Spotify app into temporary storage.

A focused terminal in the isolated Herdr window dispatched all six modified shortcuts. Native mouse clicks exercised Play/Pause, Previous, Next and Like against the stand-in. A single click on the final Pause button emitted exactly one Pause and left the fixture paused. One Pause through the same handler against the real Spotify desktop app left it paused throughout a six-second observation.
