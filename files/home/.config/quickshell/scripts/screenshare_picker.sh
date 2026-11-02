#!/bin/bash

# This script is called by xdg-desktop-portal-hyprland
# It uses quickshell to display a picker and waits for the result.

# The list of windows is passed in the XDPH_WINDOW_SHARING_LIST environment variable.

# 1. Trigger the picker in quickshell
qs ipc call screensharepicker start "$XDPH_WINDOW_SHARING_LIST"

notify-send "XDP Hyprland" "$XDPH_WINDOW_SHARING_LIST"

# 2. Wait for the selection
SELECTION=$(qs ipc wait screensharepicker wait)

# 3. Handle cancellation or selection
if [ -n "$SELECTION" ]; then
  echo "$SELECTION"
  exit 0
else
  exit 1
fi
