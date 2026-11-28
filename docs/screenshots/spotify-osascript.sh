#!/bin/sh
# This executable only runs in the screenshot sandbox.
case "$3" in
  */spotify-mini/macos.jxa) ;;
  *) printf '%s\n' "$0 $*" >> "$(dirname "$0")/../stub.log"; exit 1 ;;
esac
file="$HERDR_APP_HOME/data/spotify-demo.json"
case "$4" in
  wait) sleep 2 ;;
  state) ;;
  *) printf '%s\n' "$4" >> "$HERDR_APP_HOME/data/spotify-demo-actions"; echo '{"ok":true}'; exit ;;
esac
if [ -f "$file" ]; then cat "$file"; else echo '{"ok":true,"running":false}'; fi
