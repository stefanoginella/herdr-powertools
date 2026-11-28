import { div, svg, image } from "gpui-kit";
import { h_flex, v_flex, Input, Slider, SliderTrack, SliderIndicator, SliderThumb } from "gpui-base";

import { keys, settings } from "herdr";
import { scrollDistance } from "./display.js";

const GREEN = "#1ed760";
const icon = (name, size) => svg("mods/spotify-mini/" + name + ".svg").size(size).flex_none();
const label = (text, size, color) => div().min_w(0).truncate().text_size(size).text_color(color).child(text);
const canLike = s => Boolean(s.track?.id?.startsWith("spotify:track:"));
const likeTip = "Like / unlike this song in Spotify";
const keySymbols = { ctrl: "⌃", cmd: "⌘", alt: "⌥", shift: "⇧", left: "←", right: "→", up: "↑", down: "↓" };
function globalChord(command, bindings) {
  const key = bindings.find(binding => binding.section === "global" && binding.action === "spotify-mini." + command);
  return key?.keys.split("-").map(part => keySymbols[part] || part.toUpperCase()).join("");
}

// Measure the natural unwrapped label and the actual space left by its siblings.
// GPUI animates the offset between layout changes without a JavaScript frame timer.
function marquee(v, id, text, size, color, bold = false) {
  let m = v.marquees.get(id);
  if (!m || m.text !== text) {
    m = { text, generation: (m?.generation ?? 0) + 1 };
    v.marquees.set(id, m);
  }
  const key = id + "-" + m.generation;
  const measure = part => (bounds, cx) => {
    if (v.marquees.get(id) !== m || bounds.width === m[part]) return;
    m[part] = bounds.width;
    cx.notify();
  };
  const distance = scrollDistance(m.natural, m.clip, settings()?.zoom);
  const line = div().id(key + "-text").flex_none().relative().whitespace_nowrap()
    .text_size(size).text_color(color).when(bold, el => el.font_semibold())
    .on_size_change(measure("natural")).child(text);
  if (distance > 1) line.loop("left", { from: 0, to: -distance, period: Math.max(2600, distance * 75), easing: "linear" });
  return h_flex().id(key + "-clip").w_full().min_w(0).overflow_hidden()
    .on_size_change(measure("clip")).child(line);
}

function button(t, id, title, action, { glyph, size = 24, primary = false, disabled = false, pressed = false, text } = {}) {
  let el = h_flex().id(id).h(size).flex_none().items_center().justify_center().rounded(primary ? size / 2 : 5)
    .text_size(12).gap(6).text_color(primary ? "#082412" : t.foreground)
    .role("button").accessibility_label(title).tooltip(title);
  el = text ? el.px(8) : el.w(size);
  if (primary) el = el.bg(GREEN);
  else if (pressed) el = el.bg(t.hover);
  if (glyph) el = el.child(icon(glyph, size >= 36 ? 19 : 14));
  if (text) el = el.child(text);
  if (disabled) return el.opacity(0.4);
  return el.cursor_pointer().hover(s => primary ? s.opacity(0.85) : s.bg(t.hover))
    .on_click((_e, cx) => { cx.stop_propagation(); action(cx); });
}

function controls(v, t, small) {
  const s = v.player;
  const group = h_flex().items_center().gap(small ? 1 : 6).flex_none();
  const items = [
    ["previous", "previous", "Previous track", "←", !s.running],
    ["toggle", s.playing ? "pause" : "play", s.playing ? "Pause" : "Play", "Space", false],
    ["next", "next", "Next track", "→", !s.running],
    ["like", "like", likeTip, "L", !canLike(s)],
  ];
  const bindings = keys();
  for (const [cmd, glyph, tip, localKey, disabled] of items) {
    const global = globalChord(cmd, bindings);
    const key = small ? global : [localKey + " in player", global && (global + " in Herdr")].filter(Boolean).join(" · ");
    // A click belongs to the glyph that was drawn. A delayed/duplicate Pause
    // callback must still send Pause even if the underlying model now says paused.
    const action = cmd === "toggle" && s.running && s.track ? (s.playing ? "pause" : "play") : cmd;
    group.child(button(t, cmd, key ? tip + " (" + key + ")" : tip, cx => v.control(action, cx), {
      glyph, disabled: !v.mac || disabled, pressed: v.pressed === cmd || v.desktopAction === cmd,
      size: small ? 27 : cmd === "toggle" ? 46 : 36, primary: !small && cmd === "toggle",
    }));
  }
  return group;
}

export function statusBar(v, t, hidden) {
  const s = v.player;
  const bar = h_flex().size_full().min_w(0).px(3).items_center().bg(t.chrome).border_t(1).border_color(t.border);
  if (!v.mac) return bar;
  const open = h_flex().id("open-spotify-mini").h_full().min_w(0).flex_1().items_center().gap(6).px(3).rounded(4)
    .cursor_pointer().role("button").accessibility_label("Open Spotify Mini")
    .hover(h => h.bg(t.hover)).on_click(() => v.openPanel()).child(playingMark(s.playing, t.muted));
  if (s.running && s.track) {
    const song = hidden ? "Spotify" : [s.track.title, s.track.artist].filter(Boolean).join(" · ") || "Spotify";
    open.tooltip(song + " — Open player").child(div().flex_1().min_w(0)
      .child(marquee(v, "status-title", song, 11.5, t.foreground)));
  } else open.tooltip("Open Spotify Mini");
  bar.child(open);
  if (s.running && s.track) bar.child(controls(v, t, true));
  return bar;
}

function volume(v, t) {
  const level = v.dragVolume ?? v.player.volume ?? 0;
  return h_flex().gap(12).items_center().h(24)
    .child(label("Volume", 12, t.muted))
    .child(div().flex_1().min_w(0).child(Slider.new(v.volume).w_full().child(
      SliderTrack.new(v.volume).h(20).w_full().flex().items_center().cursor_pointer().child(
        SliderIndicator.new(v.volume).relative().w_full().h(4).rounded(2).bg(t.border)
          .range_style(fill => fill.bg(GREEN).rounded(2))
          .child(SliderThumb.new(v.volume).id("volume-thumb").size(12).rounded(6).bg(t.foreground).ml(-6).mt(-4))))))
    .child(div().w(36).text_right().text_size(11).text_color(t.muted).child(level + "%"));
}

function pinList(v, t) {
  const area = v_flex().flex_1().min_h(0).gap(6);
  if (v.editing) {
    const field = state => Input.new(state).w_full().h(30).px(9).rounded(6).bg(t.background)
      .border_1().border_color(t.input).text_size(13).text_color(t.foreground);
    area.child(field(v.nameField)).child(field(v.linkField))
      .child(h_flex().gap(4).justify_end()
        .child(button(t, "cancel", "Cancel", cx => v.endEdit(cx), { text: "Cancel", disabled: v.saving }))
        .child(button(t, "save", "Save pinned playlist", cx => v.savePin(cx), { text: "Save pin", primary: true, disabled: v.saving })));
  } else {
    const list = v_flex().id("pins").w_full().flex_1().min_h(0).overflow_y_scrollbar();
    const hues = ["#2b594b", "#61455b", "#635035", "#355269", "#564a70"];
    for (const pin of v.pins) {
      const color = hues[parseInt(pin.id.slice(-4), 36) % hues.length];
      list.child(h_flex().items_center().h(39).flex_none().gap(6)
        .child(h_flex().id("pin-" + pin.id).h_full().flex_1().min_w(0).gap(10).px(3).items_center()
          .rounded(5).cursor_pointer().hover(h => h.bg(t.hover)).tooltip("Open " + pin.name + " in Spotify")
          .on_click((_e, cx) => v.openUri("spotify:playlist:" + pin.id, cx))
          .child(h_flex().size(29).flex_none().rounded(4).bg(color).text_color("#ffffff").items_center().justify_center().child(icon("playlist", 16)))
          .child(label(pin.name, 13, t.foreground).font_medium()))
        .child(button(t, "remove-" + pin.id, "Unpin " + pin.name, cx => v.updatePins(cx, pins => pins.filter(p => p.id !== pin.id)),
          { text: "−", disabled: v.saving })));
    }
    if (!v.pins.length) list.child(label("Pin a playlist with its Spotify share link.", 12, t.muted));
    area.child(list);
  }
  if (v.pinError) area.child(div().text_size(12).text_color(t.blocked).child(v.pinError));
  return area;
}

function clock(seconds) {
  const whole = Math.max(0, Math.floor(seconds || 0));
  return Math.floor(whole / 60) + ":" + String(whole % 60).padStart(2, "0");
}

const PLAYER = { foreground: "#f5fff6", background: "#101b17", muted: "#b6c8bf", border: "#3b4b43", hover: "#2f4237" };

function playingMark(playing, restingColor = PLAYER.muted) {
  const bars = h_flex().flex_none().gap(2).h(13).items_end();
  for (const [i, height] of [7, 12, 9].entries()) {
    bars.child(div().id("beat-" + i).w(2).h(height).rounded(1).bg(playing ? GREEN : restingColor)
      .when(playing, el => el.loop("height", { from: 3, to: height, period: 700 + i * 190 })));
  }
  return bars;
}

export function panel(v, t) {
  const s = v.player, track = s.track;
  const status = !v.mac ? "Requires macOS" : s.error ? "Unavailable" : s.playing ? "Now playing" :
    track ? "Paused" : s.running ? "Idle" : s.running === false ? "Spotify closed" : "Connecting";
  const title = track?.title || "Spotify Mini";
  const subtitle = track?.artist || s.error || (s.running === false ? "Press Play to resume in Spotify" : "");
  const root = v_flex().id("spotify-panel").size_full().min_h(0).bg(t.popover).text_color(t.foreground)
    .track_focus(v.focus).on_key_down((e, cx) => v.key(e, cx));
  const head = h_flex().h(46).flex_none().px(17).gap(10).items_center().bg("#101512")
    .child(image("mods/spotify-mini/spotify-logo.svg").w(84).h(23).flex_none())
    .child(div().flex_1()).child(playingMark(s.playing)).child(label(status, 11, PLAYER.muted))
    .child(button(PLAYER, "close", "Close (Escape)", () => v.closePanel(), { text: "×" }));
  const info = v_flex().flex_1().min_w(0).gap(5)
    .child(marquee(v, "player-title", title, 22, PLAYER.foreground, true));
  if (subtitle) info.child(track ? marquee(v, "player-artist", subtitle, 14, "#cee6d6") :
    div().text_size(12).text_color(PLAYER.muted).child(subtitle));
  if (track?.album && track.album !== title) info.child(label(track.album, 11, "#a8c0af").tooltip(track.album));
  const sleeve = v.cover ? image(v.cover) : image("mods/spotify-mini/record.svg");
  const hero = v_flex().flex_none().px(18).py(12).gap(10).bg("#1b3328")
    .child(h_flex().gap(17).items_center().child(sleeve.size(88).flex_none().rounded(4)).child(info));
  if (track?.duration > 0) {
    const fraction = Math.min(1, Math.max(0, (track.position || 0) / track.duration));
    hero.child(h_flex().gap(8).items_center().h(13)
      .child(label(clock(track.position), 10, "#cee6d6"))
      .child(div().flex_1().min_w(0).h(3).rounded(2).bg("#435b4b")
        .child(div().w((fraction * 100) + "%").h_full().rounded(2).bg("#b8e7c6")))
      .child(label(clock(track.duration), 10, "#cee6d6")));
  }
  const deck = h_flex().h(62).flex_none().px(18).gap(16).items_center().bg(PLAYER.background)
    .child(controls(v, PLAYER, false));
  if (s.running) deck.child(div().flex_1().min_w(0).child(volume(v, PLAYER)));
  return root.child(head).child(hero).child(deck)
    .child(v_flex().flex_1().min_h(0).px(18).pt(10).pb(5).gap(6)
      .child(h_flex().h(28).items_center().justify_between().child(label("Pinned playlists", 14, t.foreground).font_semibold())
        .when(!v.editing, el => el.child(button(t, "new-pin", "Pin a playlist", cx => v.editPin(cx), { text: "+ Pin" }))))
      .child(pinList(v, t)))
    .child(h_flex().h(38).px(10).items_center().justify_between().border_t(1).border_color(t.border)
      .child(button(t, "search", "Open search in Spotify", cx => v.openUri("spotify:search", cx), { text: "Spotify Search ↗", disabled: !v.mac }))
      .child(button(t, "playlists", "Open playlists in Spotify", cx => v.control("playlists", cx), { text: "My Playlists ↗", disabled: !v.mac })));
}
