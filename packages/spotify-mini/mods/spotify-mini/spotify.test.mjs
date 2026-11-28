import assert from "node:assert/strict";
import test from "node:test";
import vm from "node:vm";
import { readFileSync } from "node:fs";
import { pinPlaylist, playlistId, readPins } from "./pins.js";
import { coverAsset, scrollDistance, statusWidth } from "./display.js";

test("pausing keeps the transport visible while a closed or empty player folds to its launcher", () => {
  const state = { running: true, track: { id: "spotify:track:demo" } };
  assert.equal(statusWidth({ ...state, playing: true }), 320);
  assert.equal(statusWidth({ ...state, playing: false }), 320);
  assert.equal(statusWidth({ running: false }), 32);
  assert.equal(statusWidth({ running: true, track: null }), 32);
});

test("the marquee scrolls only the clipped width at the current Herdr zoom", () => {
  assert.equal(scrollDistance(500, 250, 2), 125);
  assert.equal(scrollDistance(249, 250, 1), 0);
  assert.equal(scrollDistance(undefined, 250, 1), 0);
  assert.equal(scrollDistance(200, undefined, 1), 0);
});

test("artwork cache paths are keyed by Spotify's CDN image ID", () => {
  const key = "a".repeat(40);
  assert.equal(coverAsset("https://i.scdn.co/image/" + key), "data/spotify-mini/art/" + key + ".jpg");
  for (const url of ["https://example.com/image/" + key, "file:///tmp/a.jpg", "https://i.scdn.co/image/../secret"]) {
    assert.equal(coverAsset(url), null);
  }
});

const id = "a234567890123456789012";
const uri = "spotify:playlist:" + id;
test("Spotify share links and URIs update the same pin without saving tracking parameters", () => {
  const first = pinPlaylist([], "First name", "https://open.spotify.com/intl-it/playlist/" + id + "?si=private");
  assert.deepEqual(first, [{ id, name: "First name" }]);
  assert.deepEqual(pinPlaylist(first, " New name ", uri), [{ id, name: "New name" }]);
  assert.deepEqual(readPins(JSON.stringify(first)), first);
  assert.deepEqual(readPins(null), []);
});

test("a different host, track, corrupted store, or empty name cannot replace the pins", () => {
  for (const url of ["https://open.spotify.com.example/playlist/" + id, "spotify:track:" + id,
    "https://open.spotify.com/playlist/" + id + "/more", "file:///tmp/playlist"]) {
    assert.equal(playlistId(url), null);
  }
  assert.throws(() => pinPlaylist([], " ", uri));
  for (const bad of ["", "{}", '[{"id":"x","name":"track"}]']) assert.throws(() => readPins(bad));
});

const helper = readFileSync(new URL("./macos.jxa", import.meta.url), "utf8");
function desktop({ changed = false, denied = false, switchAway = false } = {}) {
  const track = "spotify:track:" + id;
  const presses = [];
  let front = "Herdr", current = track;
  const previous = { bundleIdentifier: "Herdr", activateWithOptions() { front = "Herdr"; } };
  const workspace = { get frontmostApplication() { return front === "Herdr" ? previous : { bundleIdentifier: front }; } };
  const app = {
    running: () => true,
    activate() { front = "com.spotify.client"; if (changed) current = "spotify:track:new"; },
    playerState: () => "playing", soundVolume: () => 40,
    currentTrack: { id: () => current, name: () => "Demo", artist: () => "Demo" },
  };
  const events = { applicationProcesses: { whose(query) {
    assert.equal(query.bundleIdentifier, "com.spotify.client");
    return [{ keystroke(key, { using }) {
      if (denied) throw new Error("not allowed to send keystrokes");
      assert.equal(front, "com.spotify.client");
      presses.push([key, ...using]);
      if (switchAway) front = "Other app";
    } }];
  } } };
  const ctx = vm.createContext({
    ObjC: { import() {}, unwrap: s => s },
    $: { NSWorkspace: { sharedWorkspace: workspace }, NSRunningApplication: { runningApplicationsWithBundleIdentifier: () => ({ count: 1 }) },
      NSRunLoop: { currentRunLoop: { runModeBeforeDate() {} } }, NSDate: { dateWithTimeIntervalSinceNow() {} } },
    Application: bundle => bundle === "com.spotify.client" ? app : events,
  });
  vm.runInContext(helper, ctx);
  return { send: (cmd, value) => JSON.parse(ctx.run([cmd, value])), track, presses, front: () => front };
}

test("Like targets the displayed song and restores focus after Spotify receives the shortcut", () => {
  const d = desktop();
  assert.equal(d.send("like", d.track).ok, true);
  assert.deepEqual(d.presses, [["b", "option down", "shift down"]]);
  assert.equal(d.front(), "Herdr");
  const other = desktop({ switchAway: true });
  other.send("like", other.track);
  assert.equal(other.front(), "Other app");
});

test("Like handles a changed track and denied Accessibility without sending another key", () => {
  for (const options of [{ changed: true }, { denied: true }]) {
    const d = desktop(options);
    assert.equal(d.send("like", d.track).ok, false);
    assert.deepEqual(d.presses, []);
    assert.equal(d.front(), "Herdr");
  }
  const d = desktop();
  assert.equal(d.send("like", "spotify:ad:x").ok, false);
  assert.deepEqual(d.presses, []);
});

test("My Playlists opens Spotify and leaves it focused", () => {
  const d = desktop();
  assert.equal(d.send("playlists").ok, true);
  assert.deepEqual(d.presses, [["1", "option down", "shift down"]]);
  assert.equal(d.front(), "com.spotify.client");
});

const viewScript = readFileSync(new URL("./main.js", import.meta.url), "utf8")
  .replace(/^import .*;\n/gm, "").replace("export default class SpotifyMini", "class SpotifyMini");

function controlHarness() {
  const calls = [], warnings = [], tasks = [];
  const track = { id: "spotify:track:" + id };
  const state = { ok: true, running: true, playing: true, volume: 60, track };
  const viewType = vm.runInNewContext(viewScript + "\nSpotifyMini", {
    View: class {}, appHome: () => "/demo", statusWidth, run() {},
    notify: n => warnings.push(n.body),
    exec: (_bin, args) => new Promise(resolve => calls.push({ name: args[3], args: args.slice(4),
      reply: (result = { ok: true }) => resolve({ code: 0, stdout: JSON.stringify(result) }) })),
  });
  const v = Object.assign(new viewType(), { mac: true, block: "spotify-status", player: state, requests: [], revision: 0, observed: 0 });
  const cx = { notify() {}, async sleep() {}, spawn(fn) { tasks.push(fn(cx)); } };
  return { v, cx, calls, tasks, warnings, state };
}

test("rapid transport presses survive a pending command and a slow readback", async () => {
  const { v, cx, calls, tasks, state } = controlHarness();
  const tick = () => new Promise(resolve => setImmediate(resolve));
  v.control("toggle", cx);
  assert.equal(v.player.playing, false);
  v.control("toggle", cx);
  assert.equal(v.player.playing, true);
  v.control("next", cx);
  v.control("next", cx);
  v.control("louder", cx);
  v.control("louder", cx);
  assert.equal(v.player.volume, 80);
  for (const [i, expected] of ["pause", "play", "next", "next", "volume"].entries()) {
    assert.equal(calls[i].name, expected);
    if (expected === "volume") assert.equal(calls[i].args[0], "80");
    calls[i].reply();
    await tick();
  }
  assert.equal(calls[5].name, "state");
  v.control("toggle", cx);
  assert.equal(calls[6].name, "pause");
  calls[5].reply(state);
  await tick();
  assert.equal(v.player.playing, false);
  calls[6].reply();
  await tick();
  calls[7].reply({ ...state, playing: false, paused: true, track: null });
  await tick();
  calls[8].reply({ ...state, playing: false, paused: true, track: null });
  await Promise.all(tasks);
  assert.equal(v.player.track.id, state.track.id);
});

test("a Like permission dialog leaves playback available", async () => {
  const { v, cx, calls, tasks, warnings, state } = controlHarness();
  v.control("like", cx);
  v.control("toggle", cx);
  assert.deepEqual(calls.map(c => c.name), ["like", "pause"]);
  calls[0].reply({ ok: false, error: "Accessibility permission needed" });
  calls[1].reply();
  await new Promise(resolve => setImmediate(resolve));
  calls[2].reply({ ...state, playing: false });
  await new Promise(resolve => setImmediate(resolve));
  calls[3].reply({ ...state, playing: false });
  await Promise.all(tasks);
  assert.deepEqual(warnings, ["Accessibility permission needed"]);
});

test("one Pause survives stale playing reports and a duplicate click on the same rendered glyph", async () => {
  const { v, cx, calls, tasks, state } = controlHarness();
  const tick = () => new Promise(resolve => setImmediate(resolve));
  v.control("pause", cx);
  v.control("pause", cx);
  assert.equal(calls.length, 1);
  calls[0].reply();
  await tick();
  // Spotify initially confirms the command but continues reporting Playing.
  for (let i = 1; i <= 3; i++) {
    assert.equal(calls[i].name, "state");
    calls[i].reply(state);
    await tick();
    assert.equal(v.player.playing, false);
  }
  assert.equal(calls[4].name, "pause");
  calls[4].reply();
  await tick();
  for (let i = 5; i <= 6; i++) {
    calls[i].reply({ ...state, playing: false });
    await tick();
  }
  await Promise.all(tasks);
  assert.deepEqual(calls.filter(c => c.name !== "state").map(c => c.name), ["pause", "pause"]);
  assert.equal(v.player.track.id, state.track.id);
  assert.equal(v.playIntent, null);
});
