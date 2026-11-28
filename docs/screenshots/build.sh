#!/bin/bash
# build.sh: the sandbox, from nothing. A second Herdr's whole world in /var/tmp/herdr-app-demo:
# stubs for the programs that would answer with real projects, a fake home with this setup's mods
# and layout, six fake projects, and a copy of this repository with branches to draw.
# It deletes the sandbox that is there. Nothing of your own Herdr is read but this repository.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for p in hc herdr-app node rg git rsync cwebp; do real "$p" >/dev/null || { echo "build: $p is not on your PATH"; exit 1; }; done
py -c 'import PIL' 2>/dev/null || { echo "build: python3 has no Pillow (pip install pillow)"; exit 1; }

# A sandbox that still runs is stopped first, then everything goes.
[ -x "$DEMO/bin/herdr-app" ] && quit_sandbox
rm -rf "${DEMO:?}"
mkdir -p "$DEMO/bin" "$DEMO/raw" "$DEMO/gh" "$DEMO/agents" "$DEMO/state" "$A/layouts" "$A/mods" "$D"

# ---- bin: the real programs the sandbox may use, by link, and stubs for the rest ----
link() { ln -sf "$(real "$1")" "$DEMO/bin/$1"; }
link hc; link node; link rg
renderer=${HERDR_SHOTS_APP:-}
local_build="$REPO/build/Herdr Power Tools.app/Contents/MacOS/Herdr"
if [ -z "$renderer" ] && [ -x "$local_build" ]; then renderer=$local_build; fi
if [ -n "$renderer" ]; then
  [[ "$renderer" = /* && -x "$renderer" ]] || { echo "build: HERDR_SHOTS_APP must be an absolute executable path"; exit 1; }
  ln -s "$renderer" "$DEMO/bin/herdr-app"
  touch "$DEMO/patched-guides"
else
  link herdr-app
fi
real herdr-core >/dev/null && link herdr-core
for p in claude codex code open osascript textedit trash; do
  printf '#!/bin/sh\nprintf "%%s\\n" "$0 $*" >>%s/stub.log\nexit 1\n' "$DEMO" > "$DEMO/bin/$p"
done
cp "$SHOTS/spotify-osascript.sh" "$DEMO/bin/osascript"
cat > "$DEMO/bin/docker" <<X
#!/bin/sh
echo "docker \$*" >> $DEMO/stub.log
[ "\$1" = ps ] && exit 0
[ "\$1 \$2" = "compose ls" ] || exit 1
printf '%s\n' '[{"Name":"atlas-api","Status":"running(3)","ConfigFiles":"$D/atlas-api/compose.yaml"}]'
X
cat > "$DEMO/bin/ddev" <<X
#!/bin/sh
echo "ddev \$*" >> $DEMO/stub.log
case "\$1" in
  list) printf '%s\n' '{"raw":[{"name":"nimbus-web","approot":"$D/nimbus-web","status":"running","primary_url":"https://nimbus-web.ddev.site","mailpit_https_url":"https://nimbus-web.ddev.site:8026"}]}' ;;
  describe) [ "\$PWD" = "$D/nimbus-web" ] || exit 1
    printf '%s\n' '{"raw":{"status":"running","services":{"adminer":{"status":"running","https_url":"https://nimbus-web.ddev.site:9101"}}}}' ;;
  *) exit 1 ;;
esac
X
cat > "$DEMO/bin/gh" <<X
#!/bin/sh
echo "gh \$* (\$PWD)" >> $DEMO/stub.log
case "\$PWD" in $R*) ;; *) exit 1 ;; esac
if [ "\$1 \$2" = "run view" ]; then
  case " \$* " in
    *" --json jobs "*) cat "$DEMO/gh/jobs.json" ;;
    *" --log-failed "*) cat "$DEMO/gh/failed.log" ;;
    *) exit 1 ;;
  esac
  exit
fi
case "\$1" in repo|pr|run|release) cat $DEMO/gh/\$1.json ;; *) exit 1 ;; esac
X
chmod +x "$DEMO"/bin/*
cp "$SHOTS"/agents/* "$DEMO/agents/"; chmod +x "$DEMO/agents/run.sh"

# ---- the fake home ----
for f in .zshenv .zprofile; do printf 'export PATH=%s/bin:$PATH\n' "$DEMO" > "$HOME/$f"; done
cat > "$HOME/.zshrc" <<X
export PATH=$DEMO/bin:\$PATH
PROMPT='%F{6}%1~%f %F{5}❯%f '
unsetopt beep
X
cat > "$HOME/.gitconfig" <<'X'
[user]
	name = Robin Vale
	email = robin@example.com
[init]
	defaultBranch = main
[advice]
	detachedHead = false
X

# ---- the app's home: this setup's own files, as they are in the working folder ----
cp "$REPO/keys.json" "$A/keys.json"
cat > "$A/external-apps.json" <<'X'
{"apps":["vscode",{"id":"textedit","label":"TextEdit","targets":["file"],"launch":{"macos":{"command":"textedit","args":["{path}"]}}}]}
X
cp "$REPO/layouts/herdr-powertools.json" "$A/layouts/"
py "$REPO/docs/sync-mods.py" --home "$A"
cp -R "$SHOTS/stage" "$A/mods/stage"
mkdir -p "$A/data"
cat > "$A/data/quick-actions.json" <<'X'
{"actions":[
  {"id":"site-tests","name":"Run PHP tests","script":"ddev exec vendor/bin/pest","where":"tab","filter":"nimbus-web","icon":"play"},
  {"id":"site-logs","name":"Follow web logs","script":"ddev logs -f","where":"tab","filter":"nimbus-web","icon":"terminal"},
  {"id":"project-info","name":"Describe the project","script":"ddev describe","where":"tab","icon":"server"}
]}
X
# The pictures' own settings: this setup's, with a font the fake home has, one zoom to start from,
# and nothing that makes a sound or reports.
py - "$REPO/settings.json" "$A/settings.json" <<'P'
import json, sys
d = json.load(open(sys.argv[1]))
d.update({"zoom": 1.3, "font": "JetBrains Mono", "font_size": 14, "font_weight": 400, "terminal_line_height": 1.3,
          "appearance": "dark", "telemetry": False, "sounds": {"enabled": False}})
json.dump(d, open(sys.argv[2], "w"), indent=2)
P
# As after a first start: without it the app says "Updated" in a corner for the whole run.
printf '{\n  "last_run": "%s",\n  "presented": []\n}\n' "$(herdr-app --version | awk '{ print $2 }')" > "$A/update-notes.json"
cat > "$A/shared.json" <<'X'
{"layout":"herdr-powertools","workspace.panels":["files","changes","search"],"frame.welcomed":"finished","agents.sort":"priority"}
X
# 2220x1410 on a display of one pixel a point: pictures.json's boxes are in that window's pixels.
# It opens with only its corner on screen, at the desktop's bottom right, out of the pointer's way:
# a pointer over the window leaves hover marks in the shots. (scene.sh then minimizes it.)
at=$(/usr/bin/osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null | awk -F', ' 'NF == 4 { print $3 - 120 ".0," $4 - 90 ".0" }' || true)
printf '{"state":"windowed","bounds":[%s,2220.0,1410.0]}\n' "${at:-60.0,40.0}" > "$A/window.json"
# The mods read nothing while Herdr is not the active app, and the sandbox never is one for long:
# its copies are told that it is.
grep -rlE '(window|app)\(\)\?\.active' "$A/mods" --include='*.js' | while read -r f; do
  sed -i '' -E \
    -e 's/(window|app)\(\)\?\.active === false/false/g' \
    -e 's/(window|app)\(\)\?\.active !== false/true/g' \
    -e 's/!(window|app)\(\)\?\.active/false/g' \
    -e 's/(window|app)\(\)\?\.active/true/g' "$f"
done

# ---- the fake projects ----
now=$(date +%s)
# commit <minutes ago> <author> <message>: everything in the folder, at that time
commit() {
  local t=$((now - $1 * 60)); git add -A
  GIT_AUTHOR_NAME="$2" GIT_AUTHOR_EMAIL="dev@example.com" GIT_COMMITTER_NAME="$2" GIT_COMMITTER_EMAIL="dev@example.com" \
    GIT_AUTHOR_DATE="@$t" GIT_COMMITTER_DATE="@$t" git commit -q --allow-empty -m "$3"
}
w() { mkdir -p "$(dirname "$1")"; cat > "$1"; }
H=60 # minutes in an hour

# atlas-api: a small TypeScript service, with a compose stack
mkdir -p "$D/atlas-api" && cd "$D/atlas-api" && git init -q
w package.json <<'X'
{ "name": "atlas-api", "version": "2.4.0", "type": "module", "scripts": { "dev": "tsx watch src/server.ts", "test": "vitest run" } }
X
w compose.yaml <<'X'
services:
  api: { build: ., ports: ["8080:8080"], depends_on: [db, cache] }
  db: { image: postgres:17 }
  cache: { image: valkey/valkey:8 }
X
w src/server.ts <<'X'
import { createServer } from "node:http";
import { route } from "./router.ts";

createServer(route).listen(8080, () => console.log("atlas-api on :8080"));
X
w src/router.ts <<'X'
export function route(req, res) {
  res.writeHead(200, { "content-type": "application/json" });
  res.end(JSON.stringify({ ok: true, path: req.url }));
}
X
w README.md <<'X'
# atlas-api

The geocoding and tiles API.
X
commit $((400 * H)) "Noor Haddad" "feat: serve tiles from the cache"
w src/limits.ts <<'X'
const WINDOW = 60_000;
export const limiter = (max: number) => new Map<string, number[]>();
X
commit $((90 * H)) "Jun Park" "feat(limits): count requests per key"
git checkout -q -b feat/rate-limits
w src/limits.ts <<'X'
const WINDOW = 60_000;
export const limiter = (max: number) => new Map<string, number[]>();
export const allowed = (hits: number[], max: number, now: number) => hits.filter((t) => now - t < WINDOW).length < max;
X
commit $((20 * H)) "Jun Park" "feat(limits): refuse over the limit with 429"
echo "// TODO: per-plan limits" >> src/limits.ts
echo "RATE_LIMIT=120" > .env.example

# nimbus-web: a site under DDEV
mkdir -p "$D/nimbus-web" && cd "$D/nimbus-web" && git init -q
w .ddev/config.yaml <<'X'
name: nimbus-web
type: wordpress
docroot: web
X
w web/index.php <<'X'
<?php require __DIR__ . '/wp/wp-blog-header.php';
X
w theme/style.css <<'X'
:root { --sky: #7fb4ff; }
body { font: 16px/1.5 system-ui; }
X
commit $((300 * H)) "Robin Vale" "feat(theme): start the Nimbus theme"
w theme/header.php <<'X'
<header class="site-header"><?php bloginfo('name'); ?></header>
X
commit $((50 * H)) "Robin Vale" "feat(theme): add the header"

# ledger-cli: a Rust command line tool
mkdir -p "$D/ledger-cli" && cd "$D/ledger-cli" && git init -q
w Cargo.toml <<'X'
[package]
name = "ledger-cli"
version = "0.9.2"
edition = "2024"
X
w src/main.rs <<'X'
mod money;

fn main() {
    let total = money::sum(&[1999, 501]);
    println!("{}", money::format(total));
}
X
w src/money.rs <<'X'
pub fn sum(cents: &[i64]) -> i64 { cents.iter().sum() }
pub fn format(cents: i64) -> String { format!("{}.{:02}", cents / 100, cents % 100) }
X
commit $((200 * H)) "Robin Vale" "feat: print a ledger's total"
git checkout -q -b fix/rounding
sed -i '' 's/cents % 100)/(cents % 100).abs())/' src/money.rs
commit $((6 * H)) "Robin Vale" "fix(money): keep the sign out of the cents"

# fieldnotes: Markdown notes; the week's note is the one the editor picture shows
mkdir -p "$D/fieldnotes" && cd "$D/fieldnotes" && git init -q
w inbox.md <<'X'
# Inbox
X
w 2026/11-week-48.md <<'X'
# Week 48

- [x] Ship the tiles cache
- [ ] Write up the rounding bug
X
commit $((30 * H)) "Robin Vale" "docs: notes for week 48"
w 2026/11-week-48.md <<'X'
# Week 48

Three things this week: the **tiles cache**, the rounding bug in `ledger-cli`,
and a first look at the *Parquet* export.

## Done

- [x] Ship the tiles cache
- [x] Refuse requests over the limit with a `429`
- [ ] Write up the rounding bug
- [ ] Review the minimap branch

## The rounding bug

Negative amounts printed their sign twice: `-5` cents came out as `0.-5`.
The fix keeps the sign out of the cents:

```rust
pub fn format(cents: i64) -> String {
    format!("{}.{:02}", cents / 100, (cents % 100).abs())
}
```

> Worth a test for every amount between -100 and 100.

## Next week

1. Per-plan limits in `atlas-api`
2. The warehouse schema for [quarry](https://example.com/quarry)
3. A header for the Nimbus theme
X

# quarry: a Python data tool, with a compose file never brought up
mkdir -p "$D/quarry" && cd "$D/quarry" && git init -q
w pyproject.toml <<'X'
[project]
name = "quarry"
version = "0.3.0"
X
w quarry/export.py <<'X'
def to_csv(rows, out):
    for row in rows:
        out.write(",".join(map(str, row)) + "\n")
X
w docker-compose.yml <<'X'
services:
  warehouse: { image: clickhouse/clickhouse-server:25 }
X
commit $((500 * H)) "Mika Sato" "feat: export to CSV"
git checkout -q -b feat/parquet-export
w quarry/parquet.py <<'X'
import pyarrow as pa, pyarrow.parquet as pq

def to_parquet(rows, schema, path):
    pq.write_table(pa.Table.from_pylist(rows, schema=schema), path)
X
commit $((12 * H)) "Mika Sato" "feat(export): write Parquet files"

# ---- herdr-app: this repository as it is committed, with a working day drawn on top ----
git clone -q --no-hardlinks "$REPO" "$R" && cd "$R"
# The Files picture shows this checkout's Git badge while it is folded.
git init -q "$R/demo-checkout"
printf '\n/demo-checkout/\n' >> "$R/.git/info/exclude"
git remote remove origin
git checkout -q -B main

# Its last commits get times of minutes and hours ago, newest first, so that the graph reads like
# a day of work whenever the pictures are taken. Their messages and authors stay.
AGES=(31 37 44 50 56 59 1320 1325 1335 1380 1385 1390)
n=${#AGES[@]}
[ "$(git rev-list --count HEAD)" -gt "$n" ] || { echo "build: the repository has too few commits to draw"; exit 1; }
parent=$(git rev-parse "HEAD~$n")
for ((i = n - 1; i >= 0; i--)); do
  c=$(git rev-parse "HEAD~$i"); t=$((now - AGES[i] * 60))
  parent=$(GIT_AUTHOR_NAME="$(git log -1 --format=%an "$c")" GIT_AUTHOR_EMAIL="$(git log -1 --format=%ae "$c")" \
    GIT_COMMITTER_NAME="$(git log -1 --format=%cn "$c")" GIT_COMMITTER_EMAIL="$(git log -1 --format=%ce "$c")" \
    GIT_AUTHOR_DATE="@$t" GIT_COMMITTER_DATE="@$t" git commit-tree "$c^{tree}" -p "$parent" -m "$(git log -1 --format=%B "$c")")
done
git reset -q --hard "$parent"
git tag herdr-0.1.18 "HEAD~9"
git tag herdr-0.1.17 "HEAD~$n"

# a branch that was merged: a curve in the graph
git checkout -q -b fix/search-escape HEAD~4
# Use a fixture file to keep this merge independent of edits to the real project-search code.
printf 'Escape from the list gives the keyboard back to the pane it came from.\n' > docs/search-escape-demo.txt
commit 55 "Jun Park" "fix(project-search): give the keyboard back on Escape"
printf 'Tried with a remote project too.\n' >> docs/search-escape-demo.txt
commit 53 "Jun Park" "test(project-search): cover Escape on another machine"
git checkout -q main
t=$((now - 6 * 60)); GIT_AUTHOR_DATE="@$t" GIT_COMMITTER_DATE="@$t" git merge -q --no-ff fix/search-escape -m "Merge branch 'fix/search-escape'"
git branch -q -d fix/search-escape

# a branch with an open pull request
git checkout -q -b feat/editor-minimap main~2
w packages/file-editor/mods/file-editor/minimap.js <<'X'
// The whole file at a glance, right of the text: one row of the map for every `STEP` lines.
const STEP = 4;

export function rows(text) {
  const lines = text.split("\n"), out = [];
  for (let i = 0; i < lines.length; i += STEP) out.push(lines.slice(i, i + STEP).reduce((n, l) => Math.max(n, l.trimEnd().length), 0));
  return out;
}
X
commit 27 "Noor Haddad" "feat(file-editor): work out a minimap's rows"
printf '\nexport const width = (row, most) => Math.min(1, row / most);\n' >> packages/file-editor/mods/file-editor/minimap.js
commit 18 "Noor Haddad" "feat(file-editor): scale the minimap to the longest line"
printf '\n// Not drawn yet: the editor gives a mod no scroll position.\n' >> packages/file-editor/mods/file-editor/minimap.js
commit 9 "Noor Haddad" "docs(file-editor): say why the minimap is not drawn"

# a local branch nobody pushed
git checkout -q -b feat/usage-export main~1
w packages/agent-usage/mods/agent-usage/export.js <<'X'
// The shown range as CSV: one line a day and project.
export const csv = (rows) => rows.map((r) => [r.day, r.project, r.tokens, r.cost ?? ""].join(",")).join("\n");
X
commit 14 "Mika Sato" "feat(usage): export the shown range as CSV"
git checkout -q main

# a remote that is one commit behind main, and has the pull request's branch
git init -q --bare "$DEMO/remotes/herdr-app.git"
git remote add origin "$DEMO/remotes/herdr-app.git"
git push -q origin main~1:refs/heads/main feat/editor-minimap herdr-0.1.17 herdr-0.1.18 2>/dev/null
git fetch -q origin
git branch -q --set-upstream-to=origin/main main
git branch -q --set-upstream-to=origin/feat/editor-minimap feat/editor-minimap

# a stash, then what is not committed: one staged file, one changed, one new. The changed one has a
# hunk of short lines, which the diff picture shows side by side, and one of long lines.
edit_git_js() { # $1: the comment's wording, so that the stash and the working copy differ
  py - "$1" <<'P'
import sys
p = "packages/git-panel/mods/git-panel/git.js"; t = open(p).read()
old = '''  if (!words.length) return "?";
  const first = Array.from(words[0]), last = words.length > 1 ? Array.from(words[words.length - 1]) : [];
  return (first[0] + (last[0] ?? first[1] ?? "")).toUpperCase();'''
new = '''  if (!words.length) return "?";
  const first = Array.from(words[0]), last = words.length > 1 ? Array.from(words.at(-1)) : [];
  // %s
  return (first[0] + (last[0] ?? first[1] ?? "")).toLocaleUpperCase();''' % sys.argv[1]
assert old in t, "build: initials() in packages/git-panel/mods/git-panel/git.js is not as the demo change expects"
open(p, "w").write(t.replace(old, new))
P
}
edit_git_js 'One word: its first two letters. "robin" is RO, never R alone.'
t=$((now - 17 * 60)); GIT_AUTHOR_DATE="@$t" GIT_COMMITTER_DATE="@$t" git stash push -q -m "try wider rulers in the usage dialog"
edit_git_js 'One word gives its first two letters: "robin" is RO, never R alone.'
py - <<'P'
p = "packages/git-panel/mods/git-panel/git.js"; t = open(p).read()
old = 'const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];'
assert old in t, "build: MONTHS in packages/git-panel/mods/git-panel/git.js is not as the demo change expects"
t = t.replace(old, 'const MONTHS = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split(" ");')
old = '''  if (s < 86400) return `${Math.floor(s / 3600)}h`;
  if (s < 86400 * 14) return `${Math.floor(s / 86400)}d`;
  if (s < 86400 * 60) return `${Math.floor(s / (86400 * 7))}w`;
  if (s < 86400 * 365) return `${Math.floor(s / (86400 * 30))}mo`;
  return `${Math.floor(s / (86400 * 365))}y`;
'''
head = "export function ago(seconds, now = Date.now() / 1000) {\n"
assert old in t and head in t, "build: ago() in packages/git-panel/mods/git-panel/git.js is not as the demo change expects"
t = t.replace(old, old.replace("86400", "DAY")).replace(head, head + "  const DAY = 86400;\n")
open(p, "w").write(t)
p = "packages/git-panel/mods/git-panel/lanes.js"; t = open(p).read().split("\n")
t.insert(1, "// A lane that ends is left empty, never taken out: that keeps a passing line straight.")
open(p, "w").write("\n".join(t))
P
git add packages/git-panel/mods/git-panel/lanes.js
w packages/git-panel/mods/git-panel/initials.test.mjs <<'X'
import { test } from "node:test";
import assert from "node:assert/strict";
import { initials } from "./git.js";

test("two words give their first letters", () => assert.equal(initials("Noor Haddad"), "NH"));
test("one word gives its first two", () => assert.equal(initials("robin"), "RO"));
X

# ---- what `gh` answers: one open pull request, checks on main's last commits, two releases ----
r() { git -C "$R" rev-parse "$1"; }
cat > "$DEMO/gh/repo.json" <<'X'
{"nameWithOwner":"example/herdr-app","url":"https://github.com/example/herdr-app"}
X
cat > "$DEMO/gh/release.json" <<'X'
[{"tagName":"herdr-0.1.18","isLatest":true,"isPrerelease":false,"isDraft":false},{"tagName":"herdr-0.1.17","isLatest":false,"isPrerelease":false,"isDraft":false}]
X
py - "$DEMO/gh" "$(r feat/editor-minimap)" "$(r main~1)" "$(r main~2)" "$(r main~3)" "$(r main~4)" "$(r main~5)" <<'P'
import json, sys
out, pr, *m = sys.argv[1:]
u = "https://github.com/example/herdr-app"
json.dump([{"number": 42, "title": "Editor minimap", "headRefName": "feat/editor-minimap", "headRefOid": pr, "isDraft": False, "isCrossRepository": False,
            "url": u + "/pull/42", "statusCheckRollup": [{"status": "COMPLETED", "conclusion": "SUCCESS"}]}], open(out + "/pr.json", "w"))
st = [("in_progress", ""), ("completed", "success"), ("completed", "success"), ("completed", "failure"), ("completed", "success")]
runs = [{"databaseId": i, "headSha": s, "status": a, "conclusion": b, "workflowName": "check", "url": u + "/actions/runs/%d" % i} for i, (s, (a, b)) in enumerate(zip(m, st), 1)]
runs.append({"headSha": pr, "status": "completed", "conclusion": "success", "workflowName": "check", "url": u + "/actions/runs/9"})
json.dump(runs, open(out + "/run.json", "w"))
P
cat > "$DEMO/gh/jobs.json" <<'X'
{"jobs":[{"databaseId":107,"name":"Unit tests","status":"completed","conclusion":"failure","steps":[{"number":1,"name":"Checkout","conclusion":"success"},{"number":2,"name":"Install dependencies","conclusion":"success"},{"number":3,"name":"Run tests","conclusion":"failure"}]}]}
X
printf 'Unit tests\tRun tests\t%s\n' 'FAIL initials.test.mjs' 'Expected "NH", received "N".' '1 test failed, 18 passed.' > "$DEMO/gh/failed.log"

# ---- usage: a year of fake sessions, so that the sidebar's widget has something to say from the start ----
node "$SHOTS/gen-usage.mjs" "$DEMO/home"

echo "built $DEMO"
git -C "$R" status --short; git -C "$R" log --graph --all --format='%h %cr %an: %s' -9 | cut -c1-100
