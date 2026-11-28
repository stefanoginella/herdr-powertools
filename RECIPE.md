# Herdr Power Tools

Keep your agents, their code and the change you are reviewing in one Herdr window. The sidebar shows which projects need attention and whether Claude Code and Codex will have enough weekly quota. Open a file beside its terminal, search the project, and follow a branch from a commit to a word-level diff.

![Weekly usage, project folders and a Git commit graph in the demo workspace](preview.png)

## What you see

Start with a 268 px left sidebar. Under the window chrome put a 62 px usage widget, then spaces grouped into folders and the Agents list. Keep the 42 px tab bar above the work area. Terminal and mod panes have a 30 px header, an 8 px gap and a softer background when inactive. A resizable 368 px panel on the right switches among Files, Git and Search. A 28 px status bar runs under the work area.

## How it behaves

- File spaces into a folder, fold it, or start and stop its project's containers. Mark an idle agent unread to revisit it later. Blocked, done, working and idle agents retain their distinct indicators and keyboard order.
- Click the usage widget for weekly projections and project costs. Agent Usage and the optional commit-message writer support Claude Code and Codex. File editing, project navigation, Git and the sidebar work with ordinary terminals and Herdr's other agents.
- Cmd-click a source path or use Cmd+O to open a file. Cmd+Shift+F searches across the project. The editor keeps unsaved drafts and asks before saving over a change. Search keeps one undo step per project within its memory budget.
- Open the Git Panel with the Git button beside Files and Search. Select a commit, stash or working-tree file to read its diff. Review an entire branch from its common ancestor, mark a revision reviewed and copy line notes. The next review can start at that revision. Go to a checked-out branch’s open space or inspect a failed CI step from the panel. Stage and commit in the panel. Cmd+Shift+H disguises names around the content for screen sharing.

## Built from

Install the mod packages under `packages/`, then install `layouts/herdr-powertools.json` and merge the root `keys.json`. Follow the full install in the [README](README.md). Keep Herdr's `workspace-chrome`, its block IDs and its active-tab content. Replace the Spaces, Agents, Tabs, pane header, Status, Files and Changes mod references as shown in the layout. Add the usage block, the search child and its always-present zero-height key receiver. Register `editor-links` at the layout root. The status row includes Spotify Mini, Back and Forward and the Quick Actions launcher. The individual Power Tools recipes under `packages/` describe each part, its dependencies and its acceptance checks.

## Watch out

Run Git and ripgrep on the machine holding the project. Agent Usage needs Node 18+ on each machine it reads. Claude's quota needs the statusline cache described in the usage guide. GitHub marks use an authenticated `gh`. The optional message writer sends the change to the chosen provider when requested. Finder, Trash and the system clipboard integrations are Mac-specific. Keep real identifiers for actions while drawing disguised names. Screenshots use a separate demo workspace.

## Done when

Switch to `herdr-powertools` and open Files, Git and Search from the same tab. Follow a search match to the editor, save it and review the working-tree diff beside the terminal. Mark an agent unread and revisit it. Switch name hiding on and off and confirm the same spaces and files still open. Switch back to the previous layout.
