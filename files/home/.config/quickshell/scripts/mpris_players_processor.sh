#!/bin/bash
set -euo pipefail

# Check arguments
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <player_name> <art_url>" >&2
  exit 1
fi

PLAYER="$1"
ART_URL="$2"
STATE_DIR="$HOME/.local/state/bnsplit"
STATE_FILE="$STATE_DIR/mpris-players.json"
ART_DIR="$HOME/.cache/bnsplit/mpris-arts"

# Fast path: Check if this exact state already exists
# This avoids all processing if nothing changed
if [[ -f "$STATE_FILE" ]]; then
  CURRENT_URL=$(jq -r --arg player "$PLAYER" '.[$player].artUrl // empty' "$STATE_FILE" 2>/dev/null || true)
  if [[ "$CURRENT_URL" == "$ART_URL" ]]; then
    # Nothing changed, exit immediately
    exit 0
  fi
fi

mkdir -p "$STATE_DIR" "$ART_DIR"

# Initialize state file if it doesn't exist
[[ ! -s "$STATE_FILE" ]] && echo '{}' >"$STATE_FILE"

# Safe jq update - never leaves empty file
jq() {
  local temp="${STATE_FILE}.tmp.$$"
  if /usr/bin/jq "$@" "$STATE_FILE" >"$temp" 2>/dev/null && [[ -s "$temp" ]]; then
    mv "$temp" "$STATE_FILE"
  else
    rm -f "$temp"
    return 1
  fi
}

# Lightweight validation - only on new downloads
validate_image() {
  local image_path="$1"
  [[ -s "$image_path" ]] || return 1

  # Only validate if identify exists, otherwise trust file size
  if command -v identify &>/dev/null; then
    identify -format "%w" "$image_path" &>/dev/null
  else
    return 0
  fi
}

# Process art URL and determine local path
process_art() {
  local art_url="$1"

  if [[ -z "$art_url" ]]; then
    echo ""
    return
  fi

  if [[ "$art_url" == file://* ]]; then
    # Local file URL - strip file:// prefix
    echo "${art_url#file://}"
  else
    # Remote URL
    local unique_name
    unique_name="$(echo -n "$art_url" | md5sum | awk '{print $1}')"

    local art_file="$ART_DIR/$unique_name"
    local validation_marker="$ART_DIR/${unique_name}.ok"

    # Fast path: already downloaded and validated
    if [[ -f "$art_file" && -f "$validation_marker" ]]; then
      echo "$art_file"
      return
    fi

    # Clean up any partial downloads
    rm -f "$art_file" "$validation_marker"

    # Try downloading with retries
    local temp_file="${art_file}.tmp.$$"
    local attempt=1

    while [[ $attempt -le 3 ]]; do
      if curl -sf --max-time 10 -o "$temp_file" "$art_url" 2>/dev/null; then
        if validate_image "$temp_file"; then
          mv "$temp_file" "$art_file"
          touch "$validation_marker"
          echo "$art_file"
          return
        fi
        rm -f "$temp_file"
      fi
      attempt=$((attempt + 1))
      [[ $attempt -le 3 ]] && sleep 0.5
    done

    # Download failed, return empty string
    echo ""
  fi
}

# Main execution
LOCAL_PATH=$(process_art "$ART_URL")

# Update state file
jq --arg player "$PLAYER" \
  --arg url "$ART_URL" \
  --arg path "$LOCAL_PATH" \
  '.[$player] = {artUrl: $url, localPath: $path}' >/dev/null

# Silent success - only output on actual changes
[[ "$CURRENT_URL" != "$ART_URL" ]] && echo "Updated $PLAYER"
