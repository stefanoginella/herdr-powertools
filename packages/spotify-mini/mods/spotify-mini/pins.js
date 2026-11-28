// Accept Spotify's Share link (including localized links) or a playlist URI.
// Keeping only the ID discards share/tracking parameters.
export function playlistId(link) {
  const value = String(link ?? "").trim();
  const uri = /^spotify:playlist:([A-Za-z0-9]{22})$/.exec(value);
  const web = /^https:\/\/open\.spotify\.com\/(?:intl-[a-zA-Z-]+\/)?playlist\/([A-Za-z0-9]{22})\/?(?:[?#][^\s]*)?$/.exec(value);
  return (uri ?? web)?.[1] ?? null;
}

export function readPins(text) {
  if (text === null) return [];
  const list = JSON.parse(text);
  if (!Array.isArray(list) || list.some(p => !p || typeof p.name !== "string" || !p.name.trim() ||
      typeof p.id !== "string" || !/^[A-Za-z0-9]{22}$/.test(p.id))) {
    throw new Error("The pinned playlists file contains an invalid entry.");
  }
  return list;
}

export function pinPlaylist(pins, name, link) {
  const id = playlistId(link);
  if (!id) throw new Error("Paste a Spotify playlist link or spotify:playlist: URI.");
  name = String(name ?? "").trim();
  if (!name) throw new Error("Give the playlist a name.");
  if (pins.some(p => p.id === id)) return pins.map(p => p.id === id ? { id, name } : p);
  return [...pins, { id, name }];
}
