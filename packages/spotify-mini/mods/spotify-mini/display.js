// Keep the whole row in place through play/pause and transient reads with no track.
export function statusWidth(state) {
  if (!state.running || !state.track) return 32;
  return 320;
}

export function coverAsset(url) {
  const match = /^https:\/\/i\.scdn\.co\/image\/([a-fA-F0-9]{40})$/.exec(url || "");
  return match ? "data/spotify-mini/art/" + match[1].toLowerCase() + ".jpg" : null;
}

export function scrollDistance(textWidth, clipWidth, zoom) {
  if (!textWidth || !clipWidth) return 0;
  return Math.max(0, (textWidth - clipWidth) / (zoom || 1));
}
