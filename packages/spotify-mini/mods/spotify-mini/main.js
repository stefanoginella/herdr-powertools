import { View } from "gpui-kit";
import { InputState, SliderState } from "gpui-base";
import { appHome, checking, closeOverlay, exec, layout, nextCommand, notify, props, readTextFile, run, shared, theme, window, writeTextFile } from "herdr";
import * as fs from "fs/promises";
import { platform } from "os";
import { pinPlaylist, readPins } from "./pins.js";
import { coverAsset, statusWidth } from "./display.js";
import { panel, statusBar } from "./views.js";

const MOD = "spotify-mini";
const directory = () => appHome() + "/data/" + MOD;
const pinFile = () => directory() + "/playlists.json";
const message = e => String(e?.message ?? e);
const transportKeys = ["toggle", "play", "pause", "previous", "next", "louder", "quieter", "like"];
function hasStatus(node) {
  if (!node || node.hidden) return false;
  if (node.type === "stack") return hasStatus(node.children?.find(child => child.id === node.active));
  return node?.content?.mod === MOD && Boolean(node.content.props?.statusBlock) ||
    Boolean(node?.children?.some(hasStatus));
}

async function spotify(command, ...args) {
  // Leave time for macOS's first Automation / Accessibility prompts on a deliberate press.
  const timeout = command === "wait" ? 30000 : command === "state" ? 15000 : 90000;
  const r = await exec("osascript", ["-l", "JavaScript", appHome() + "/mods/" + MOD + "/macos.jxa", command, ...args],
    { timeout });
  if (r.code !== 0) throw new Error(r.stderr?.trim() || "The Spotify helper did not answer.");
  const result = JSON.parse(r.stdout.trim());
  if (!result.ok) throw new Error(result.error || "Spotify did not answer.");
  return result;
}

export default class SpotifyMini extends View {
  init(_p, cx) {
    const p = props() ?? {};
    this.block = p.statusBlock;
    this.overlay = p.overlay;
    // The status block can initialize before Herdr's first window snapshot exists.
    const localOS = platform();
    this.mac = localOS === "darwin" || localOS === "macos";
    this.player = {};
    this.revision = 0;
    this.observed = 0;
    this.requests = [];
    this.pins = [];
    this.marquees = new Map();
    if (!this.block) {
      this.focus = cx.focus_handle();
      this.volume = SliderState.new({ min: 0, max: 100, step: 1, value: 0 });
      this.volume.on("change", (v, cx) => { this.dragVolume = Number(v); cx.notify(); });
      this.volume.on("release", (v, cx) => { this.dragVolume = null; this.control("volume", cx, Number(v)); });
    }
    if (checking()) return;
    if (!this.block) {
      this.focus.focus();
      cx.spawn(async cx => {
        try { this.pins = readPins(await readTextFile(pinFile())); }
        catch (e) { this.pinError = message(e); }
        cx.notify();
      });
    }
    if (!this.mac) return;
    cx.spawn(async cx => {
      for (;;) {
        const command = await nextCommand();
        // Herdr broadcasts to shown copies. The mounted status block owns the
        // global binding; an independently installed dialog can handle it too.
        if (transportKeys.includes(command) && (this.block || !hasStatus(layout())))
          this.control(command, cx);
      }
    });
    cx.spawn(async cx => {
      await this.refresh(cx);
      for (;;) {
        if (this.block && !this.player.error) {
          // The helper sleeps on Spotify's playback notification and rereads on timeout.
          await this.refresh(cx, "wait");
        } else {
          await cx.sleep(this.player.error ? 10000 : 3500);
          if (window()?.active !== false) await this.refresh(cx);
        }
      }
    });
  }

  async refresh(cx, command = "state") {
    const revision = this.revision;
    const started = Date.now();
    let state;
    try { state = await spotify(command); }
    catch (e) { state = { error: message(e) }; }
    const observed = state.observed ?? (state.error ? started : Date.now());
    if (this.sending || revision !== this.revision || observed < this.observed) return;
    this.observed = observed;
    if (state.paused && !state.track && this.player.track) state.track = this.player.track;
    const intent = this.playIntent;
    if (intent && (!state.running || state.error || (state.track && state.track.id !== intent.track)))
      this.playIntent = null;
    this.player = this.playIntent ? { ...state, playing: this.playIntent.playing } : state;
    if (this.volume && this.dragVolume == null) this.volume.set_value(state.volume ?? 0);
    if (this.block) {
      const width = statusWidth(state);
      if (width !== this.barWidth) {
        this.barWidth = width;
        run("layout.resize", { id: this.block, px: width });
      }
    } else {
      this.loadCover(cx, state.track?.art);
    }
    cx.notify();
    return state;
  }

  loadCover(cx, url) {
    const path = coverAsset(url);
    if (path === this.coverRequest && (this.cover || Date.now() < this.coverRetry)) return;
    this.coverRequest = path;
    this.cover = null;
    if (!path) return;
    this.coverRetry = Date.now() + 60000;
    cx.spawn(async cx => {
      const file = appHome() + "/" + path;
      try {
        if (!await fs.exists(file)) await spotify("cover", url, file);
        const available = await fs.exists(file);
        if (available && this.coverRequest === path) {
          this.cover = path;
          cx.notify();
        }
      } catch (_) { /* Keep the record sleeve while the art is unavailable. */ }
    });
  }

  openPanel() { run("mod.open", { name: MOD }); }
  closePanel() { if (this.overlay) closeOverlay(this.overlay); }

  control(command, cx, value) {
    if (!this.mac) return;
    const s = this.player;
    if (command === "like" && !s.track?.id?.startsWith("spotify:track:")) return;
    if (command === "louder" || command === "quieter") {
      value = Math.max(0, Math.min(100, (s.volume ?? 0) + (command === "louder" ? 10 : -10)));
      command = "volume";
    }
    if (["previous", "next", "volume"].includes(command) && !s.running) return;
    const args = command === "like" ? [s.track.id] : value == null ? [] : [String(value)];
    if (command === "like" || command === "playlists") {
      // A first-time Accessibility prompt must not hold up playback commands.
      if (this.desktopAction) {
        notify({ title: "Spotify", body: "Waiting for Spotify to finish the previous shortcut." });
        return;
      }
      this.desktopAction = command;
      cx.notify();
      cx.spawn(async cx => {
        try {
          await spotify(command, ...args);
          if (command === "like") notify({ title: "Spotify", body: "Sent Like / Dislike to Spotify.", timeout: 1800 });
        } catch (e) { notify({ title: "Spotify", body: message(e), level: "warning" }); }
        finally { this.desktopAction = null; cx.notify(); }
      });
      return;
    }
    if (command === "toggle" && s.running && s.track) {
      command = s.playing ? "pause" : "play";
    }
    const playback = command === "play" || command === "pause";
    const button = playback ? "toggle" : command;
    if (playback) {
      const playing = command === "play";
      if (this.playIntent?.playing === playing) return;
      this.playIntent = { playing, track: s.track?.id };
      this.player = { ...s, playing };
    } else if (command === "volume") {
      this.player = { ...s, volume: value };
      this.volume?.set_value(value);
    } else {
      this.playIntent = null;
    }
    this.revision++;
    // Slider releases and repeated volume keys can replace an unsent level.
    // Every skip and play/pause press keeps its place in the sequence.
    if (command === "volume" && this.requests.at(-1)?.command === "volume") this.requests.pop();
    this.requests.push({ command, button, args, intent: playback ? this.playIntent : null });
    cx.notify();
    this.drain(cx);
  }

  drain(cx) {
    if (this.sending) return;
    this.sending = true;
    cx.spawn(async cx => {
      while (this.requests.length) {
        const request = this.requests.shift();
        this.pressed = request.button;
        cx.notify();
        try {
          await spotify(request.command, ...request.args);
        } catch (e) {
          if (request.intent && this.playIntent === request.intent) this.playIntent = null;
          notify({ title: "Spotify", body: message(e), level: "warning" });
        }
      }
      this.pressed = null;
      this.sending = false;
      cx.notify();
      // A readback is independent of the next press.
      await this.confirmPlayback(cx);
    });
  }

  async confirmPlayback(cx) {
    const intent = this.playIntent, revision = this.revision;
    if (!intent) { await this.refresh(cx); return; }
    let matches = 0;
    for (let attempt = 0; attempt < 5; attempt++) {
      const state = await this.refresh(cx);
      if (this.playIntent !== intent || revision !== this.revision) return;
      if (state) matches = state.playing === intent.playing ? matches + 1 : 0;
      if (matches === 2) { this.playIntent = null; return; }
      // Spotify can report its old state just after an Apple event. If a Pause
      // actually failed to stick on the same track, send one idempotent Pause.
      if (attempt === 2 && !intent.retried && !intent.playing && state?.playing && state.track?.id === intent.track) {
        intent.retried = true;
        this.requests.push({ command: "pause", button: "toggle", args: [], intent });
        this.drain(cx);
        return;
      }
      await cx.sleep(150);
      if (this.playIntent !== intent || revision !== this.revision) return;
    }
    this.playIntent = null;
    const state = await this.refresh(cx);
    if (revision === this.revision && state?.running && state.playing !== intent.playing)
      notify({ title: "Spotify", body: intent.playing ? "Spotify did not start playing." : "Spotify did not stay paused.", level: "warning" });
  }

  openUri(uri, cx) {
    if (!this.mac) return;
    cx.spawn(async () => {
      try {
        const result = await exec("open", ["-b", "com.spotify.client", uri]);
        if (result.code !== 0) throw new Error("Could not open the Spotify desktop app.");
      } catch (e) { notify({ title: "Spotify", body: message(e), level: "warning" }); }
    });
  }

  editPin(cx) {
    this.pinError = "";
    this.nameField = InputState.new({ placeholder: "Playlist name" });
    this.linkField = InputState.new({ placeholder: "Paste Spotify playlist link" });
    this.nameField.on("submit", () => this.linkField.focus());
    this.linkField.on("submit", (_e, cx) => this.savePin(cx));
    this.editing = true;
    cx.notify();
    this.nameField.focus();
  }

  endEdit(cx) {
    this.editing = false;
    this.pinError = "";
    this.focus.focus();
    cx.notify();
  }

  savePin(cx) {
    const name = this.nameField.value(), link = this.linkField.value();
    this.updatePins(cx, pins => pinPlaylist(pins, name, link));
  }

  updatePins(cx, change) {
    if (this.saving) return;
    this.saving = true;
    cx.spawn(async cx => {
      try {
        await fs.mkdir(directory(), { recursive: true });
        const text = await readTextFile(pinFile());
        const pins = change(readPins(text));
        await writeTextFile(pinFile(), JSON.stringify(pins, null, 2) + "\n", text);
        this.pins = pins;
        this.endEdit(cx);
      } catch (e) { this.pinError = message(e); }
      finally { this.saving = false; cx.notify(); }
    });
  }

  key(e, cx) {
    const key = e.keystroke;
    if (key === "escape") {
      if (this.editing) this.endEdit(cx);
      else this.closePanel();
    } else if (this.editing) return;
    else if (key === "up" || key === "down") {
      this.control(key === "up" ? "louder" : "quieter", cx);
    } else {
      const command = { space: "toggle", left: "previous", right: "next", l: "like" }[key];
      if (!command) return;
      this.control(command, cx);
    }
    cx.stop_propagation();
  }

  render() {
    const t = theme();
    return this.block ? statusBar(this, t, shared("names.hidden") === true) : panel(this, t);
  }
}
