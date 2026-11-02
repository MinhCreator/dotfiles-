#!/usr/bin/env bash

# The script combines all arguments into the yay command string
YAY_CMD="$*"

if eval "$YAY_CMD"; then
  notify-send --app-name=Updates --icon=update-manager "Update finished" "All updates completed successfully."
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "title:quickshell-system-update" }))' >/dev/null
  qs ipc call update refresh >/dev/null

  mapfile -t deps < <(yay -Qdtq 2>/dev/null || true)
  if [[ ${#deps[@]} -gt 0 ]]; then
    yay -Rns "${deps[@]}"
  else
    echo "No orphaned packages found"
  fi

  pkexec paccache -r
else
  notify-send --app-name=Updates --icon=update-manager "Update failed" "Some updates did not complete."
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "title:quickshell-system-update" }))' >/dev/null
  qs ipc call update refresh >/dev/null
fi

echo -en "\nPress any key to exit..."
read -n1 -s -r
