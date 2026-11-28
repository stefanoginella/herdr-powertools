#!/bin/bash
# shoot.sh [step ...]: the raw shots the pictures are made from, each the whole window as the app
# drew it, into the sandbox's raw/. After scene.sh. With no step named, all of them, in this order:
#   diff editor guides files search goto git sidebar window usage review ci tools spotify
# A step sets the zoom and the panels it needs. The crop boxes in pictures.json are in these shots'
# pixels: a step that changes a zoom, a panel's width or a pane's place moves them.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[ -n "${T1:-}" ] || { echo "shoot: no scene (scene.sh first)"; exit 1; }
N=$D/fieldnotes
h window.minimize # it stays so through every step; a pointer over the window would leave marks in the shots

# The diff pane, side by side: one file ticked as viewed, the next one shown.
s_diff() {
  zoom 1.1; h layout.show '{"id":"sidebar"}'; h layout.show '{"id":"panel"}'
  h layout.select '{"stack":"panel-body","child":"files"}'; h layout.resize '{"id":"panel","px":330}'
  h pane.focus "{\"terminal\":\"$TERM1\"}"
  local pane; pane=$(herdr-app do pane.split "{\"direction\":\"right\",\"mod\":\"git-diff\",\"props\":{\"tab\":\"$T1\"}}" | py -c 'import json, sys; print(json.load(sys.stdin).get("pane", ""))')
  nap 1.5; h pane.zoom "{\"pane\":\"$pane\"}"; draw 3
  req "[{\"shared\":[\"git-diff.open\",{\"tab\":\"$T1\",\"root\":\"$R\",\"on\":null,\"source\":{\"kind\":\"work\"},\"path\":\"packages/git-panel/mods/git-panel/lanes.js\",\"group\":\"staged\",\"at\":\"now\"}]}]" 6
  h git-diff.split
  h git-diff.viewed; nap 1; draw 5
  shot diff
  h pane.close "{\"pane\":\"$pane\"}"; nap 1.5
}

# The editor: a Markdown note, as text and as its preview.
s_editor() {
  zoom 1.6; h layout.hide '{"id":"sidebar"}'; h layout.show '{"id":"panel"}'
  h layout.select '{"stack":"panel-body","child":"files"}'; h layout.resize '{"id":"panel","px":347}'
  h pane.focus "{\"terminal\":\"$TERM1\"}"; draw 3
  open_file "$N/2026/11-week-48.md"; h file-editor.toggle-pin; shot ed-source
  h file-editor.preview; nap 1; draw 5; shot ed-preview
  h file-editor.preview; h file-editor.toggle-pin; nap 0.5; draw 2
}

# Same-named tabs and a long, tab-indented line beside its guides.
s_guides() {
  if [ ! -f "$DEMO/patched-guides" ]; then
    echo "Skipping the native guide picture. Build the sandbox with HERDR_SHOTS_APP pointing at patched Herdr."
    return
  fi
  zoom 1.6; h layout.hide '{"id":"sidebar"}'; h layout.hide '{"id":"panel"}'
  h file-editor.close-all
  local example="$D/fieldnotes/examples"
  mkdir -p "$example/client" "$example/server"
  printf '%s\n' 'export const rules = [];' > "$example/client/rules.js"
  printf '%b\n' 'export function check(project) {' '\tfor (const rule of project.rules) {' \
    '\t\tif (rule.required) {' \
    '\t\t\tconst message = "The project must include a description before this rule can be enabled for everyone in the workspace."; ' \
    '\t\t\tproject.report(rule, message);' '\t\t}' '\t}' '}' > "$example/server/rules.js"
  open_file "$example/client/rules.js"; open_file "$example/server/rules.js"
  shot editor-guides
  h file-editor.close-all
}

# Reveal the editor file and show its menu.
s_files() {
  zoom 1.45; h layout.hide '{"id":"sidebar"}'; h layout.show '{"id":"panel"}'
  h layout.select '{"stack":"panel-body","child":"files"}'; h layout.resize '{"id":"panel","px":340}'; nap 1; draw 3
  open_file "$R/packages/git-panel/mods/git-panel/git.js" 131
  h file-editor.reveal; nap 1; draw 6
  # `at` is in window pixels: left of the file's row, as the menu opens when there is no room below.
  req "[{\"overlay\":{\"mod\":\"file-explorer\",\"kind\":\"popup\",\"width\":236,\"height\":620,\"at\":{\"x\":1330,\"y\":215},\"props\":{\"menu\":{\"root\":\"$R\",\"on\":null,\"path\":\"packages/git-panel/mods/git-panel/git.js\",\"dir\":false,\"project\":\"$R\",\"repo\":\"$R\"}}}}]" 5
  shot file-actions
  h overlay.close; nap 0.8
}

# Project search with a replacement, opened from the editor.
s_search() {
  zoom 1.45; h layout.hide '{"id":"sidebar"}'; h layout.show '{"id":"panel"}'; h layout.resize '{"id":"panel","px":340}'
  open_file "$R/packages/git-panel/mods/git-panel/git.js" 131
  req "[{\"shared\":[\"project-search.ask\",{\"query\":\"initials\",\"to\":\"monogram\",\"focus\":false,\"at\":\"now\"}]},{\"run\":[\"project-search.open\",{}]}]" 8
  nap 2; draw 4
  shot search
}

# Go to file, with two words typed.
s_goto() {
  zoom 1.8
  req '[{"overlay":{"mod":"go-to-file","kind":"popup","at":"top","offset":40,"width":640,"height":0.66,"props":{"query":"main git"}}}]' 7
  shot goto
  h overlay.close; nap 0.8
}

# The Git panel: the graph in its place, the Refs view in a window of the same size.
s_git() {
  zoom 1.6; h layout.hide '{"id":"sidebar"}'; h layout.show '{"id":"panel"}'
  h layout.select '{"stack":"panel-body","child":"changes"}'; h layout.resize '{"id":"panel","px":430}'
  nap 2; draw 6; nap 3; draw 4
  shot git-graph
  req "[{\"overlay\":{\"mod\":\"git-panel\",\"kind\":\"window\",\"key\":\"refs\",\"width\":430,\"height\":794,\"at\":{\"x\":120,\"y\":70},\"props\":{\"root\":\"$R\",\"view\":\"refs\"}}}]" 6
  # The pull request and the releases are read from `gh` a moment after the window opens.
  nap 6; draw 6; nap 6; draw 4
  shot git-refs
  h overlay.close --id "$(py -c 'import json, sys; print(json.load(open(sys.argv[1]))["stage.last"])' "$A/shared.json")"
}

# The sidebar, close: the folders open and folded, the agents before and after one is marked unread.
s_sidebar() {
  h layout.show '{"id":"sidebar"}'; h layout.hide '{"id":"panel"}'; zoom 2.5
  req "$(folders_json)" 3
  h layout.hide '{"id":"agents"}'; nap 1.5; draw 4; shot side-spaces
  h spaces-sidebar.fold-all; nap 1; draw 4; shot side-folded
  h spaces-sidebar.unfold-all; req "$(folders_json)" 3
  h layout.show '{"id":"agents"}'; h layout.hide '{"id":"spaces"}'; nap 1.5; draw 4; shot side-agents-before
  # The mark is made while looking at the agent, and counts once you have left.
  h agent.focus "{\"terminal\":\"$(terminal_of nimbus-web 'theme header')\"}"; nap 1.5; draw 2
  h mark-agents-unread.toggle; nap 1; draw 2
  h space.select "{\"id\":\"$S1\"}"; h tab.select '{"index":1}'; nap 2; draw 4; shot side-agents-after
  h layout.show '{"id":"spaces"}'
}

# The whole window, with its names shown and hidden.
s_window() {
  zoom 1.3; h layout.show '{"id":"sidebar"}'; h layout.resize '{"id":"sidebar","px":290}'; h layout.show '{"id":"panel"}'
  h layout.select '{"stack":"panel-body","child":"changes"}'; h layout.resize '{"id":"panel","px":430}'
  h pane.focus "{\"terminal\":\"$TERM1\"}"; draw 3
  open_file "$R/packages/git-panel/mods/git-panel/git.js" 145; nap 3; draw 4
  shot hero
  h hide-names.toggle; nap 1.5; draw 4; shot hidden
  h hide-names.toggle; nap 1; draw 3
}

# Usage, with figures made just now ("Burning now" is the last hour): the whole dialog, then the
# sidebar's widget and the dialog's top one after the other, so that both say the same. The dialog
# keeps its layout through a zoom change: it is opened again after each.
s_usage() {
  node "$SHOTS/gen-usage.mjs" "$DEMO/home"
  usage_open() { herdr-app do mod.open '{"name":"agent-usage"}' >/dev/null; nap 2; draw 6; nap 4; draw 6; nap 2; draw 4; }
  h layout.show '{"id":"sidebar"}'
  zoom 1.1; usage_open; shot usage-whole; h overlay.close; nap 0.8
  zoom 2.5; h layout.hide '{"id":"agents"}'; nap 1.5; draw 3; shot widget; h layout.show '{"id":"agents"}'
  zoom 1.2; usage_open; shot usage-top; h overlay.close
  zoom 1.3
}

# Review a committed feature even though the terminal is on a different branch.
s_review() {
  zoom 1.45
  req '[{"overlay":{"mod":"git-diff","kind":"window","key":"branch-demo","width":1080,"height":585,"props":{"tab":"branch-demo"}}}]' 3
  req "[{\"shared\":[\"git-diff.open\",{\"tab\":\"branch-demo\",\"root\":\"$R\",\"on\":null,\"source\":{\"kind\":\"branch\",\"branch\":\"refs/heads/feat/editor-minimap\",\"base\":\"refs/heads/main\"},\"path\":\"packages/file-editor/mods/file-editor/minimap.js\",\"at\":\"now\"}]}]" 7
  shot branch-review
  h overlay.close --id "$(py -c 'import json, sys; print(json.load(open(sys.argv[1]))["stage.last"])' "$A/shared.json")"
}

s_ci() {
  zoom 1.8
  req "[{\"overlay\":{\"mod\":\"git-panel\",\"kind\":\"window\",\"key\":\"failed-job-demo\",\"width\":780,\"height\":460,\"props\":{\"failure\":{\"root\":\"$R\",\"on\":null,\"repo\":\"github.com/example/herdr-app\",\"run\":{\"name\":\"Test suite\",\"id\":4,\"url\":\"https://github.com/example/herdr-app/actions/runs/4\",\"state\":\"fail\"}}}}}]" 7
  shot failed-ci
  h overlay.close --id "$(py -c 'import json, sys; print(json.load(open(sys.argv[1]))["stage.last"])' "$A/shared.json")"
}

s_tools() {
  zoom 3
  h space.select "{\"id\":\"$S2\"}"; draw 2
  h space.select "{\"id\":\"$S1\"}"; draw 2
  h space.select "{\"id\":\"$S3\"}"; draw 3
  h back-and-forward.back; draw 3; shot navigation
  h back-and-forward.forward; draw 3
  zoom 1.8
  req "[{\"overlay\":{\"mod\":\"back-and-forward\",\"kind\":\"popup\",\"at\":{\"x\":1000,\"y\":700},\"width\":260,\"props\":{\"recent\":[\"$S3\",\"$S1\",\"$S2\"]}}}]" 3
  shot recent-workspaces
  h overlay.close
  h mod.open '{"name":"quick-actions"}'; draw 6; shot quick-actions
  h overlay.close
  h space.select "{\"id\":\"$S1\"}"; h tab.select "{\"id\":\"$T1\"}"
}

s_spotify() {
  zoom 2
  mkdir -p "$A/data/spotify-mini/art"
  # The requested 5:34 Stray Feathers recording and its public Spotify artwork.
  local art=ab67616d00001e02f776eb6971a41f5a4e969c77
  local cover="$A/data/spotify-mini/art/$art.jpg"
  if [ ! -s "$cover" ]; then
    curl -fsSL --max-time 20 --retry 2 "https://image-cdn-ak.spotifycdn.com/image/$art" -o "$cover.part" &&
      mv "$cover.part" "$cover" || return 1
  fi
  printf '%s\n' '[{"id":"1111111111111111111111","name":"Quiet mornings"},{"id":"2222222222222222222222","name":"After hours"}]' > "$A/data/spotify-mini/playlists.json"
  printf '{"ok":true,"running":true,"playing":true,"volume":60,"track":{"id":"spotify:track:1gWKIOySPIvxvV3GwGA5Rf","title":"Stargazer","artist":"Bird of Prey","album":"Stray Feathers","position":84,"duration":334.647,"art":"https://i.scdn.co/image/%s"}}\n' "$art" > "$A/data/spotify-demo.json"
  nap 3; shot spotify-bar
  h mod.open '{"name":"spotify-mini"}'; draw 3; shot spotify-player
  h overlay.close
  py - "$A/data/spotify-demo.json" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as f: state = json.load(f)
state["playing"] = False
with open(p, "w") as f: json.dump(state, f)
PY
  nap 3; shot spotify-paused
  printf '%s\n' '{"ok":true,"running":false}' > "$A/data/spotify-demo.json"
}

steps=("$@"); [ ${#steps[@]} -gt 0 ] || steps=(diff editor guides files search goto git sidebar window usage review ci tools spotify)
for s in "${steps[@]}"; do
  declare -F "s_$s" >/dev/null || { echo "shoot: no step $s"; exit 1; }
  echo "== $s"; "s_$s"
done
herdr-app status | py -c 'import json, sys; d = json.load(sys.stdin); print("errors", d.get("errors"))'
