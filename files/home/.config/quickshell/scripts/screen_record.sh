#!/bin/bash
RECORD_DIR="$HOME/Videos/Record"
mkdir -p "$RECORD_DIR"

get_latest() { find "$RECORD_DIR" -name "*.mkv" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-; }
is_recording() { pidof gpu-screen-recorder >/dev/null; }

get_focused_monitor() {
  hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

is_valid_monitor() {
  local monitor="$1"
  [[ -z "$monitor" ]] && return 1
  hyprctl monitors -j | jq -r '.[].name' | grep -qx "$monitor"
}

notify() {
  local summary="$1" body="$2" file_path="$3"

  # If there's a file path, show actions
  if [[ -n "$file_path" ]] && [[ -f "$file_path" ]]; then
    (
      action=$(notify-send \
        --app-name="Screen Recording" \
        --icon="replay-record" \
        --expire-time=0 \
        --hint=string:body-markup:true \
        --action="open=Play Video" \
        --action="folder=Open Folder" \
        --action="convert=Convert to MP4" \
        "$summary" \
        "$body")

      case "$action" in
      open)
        xdg-open "$file_path"
        ;;
      convert)
        if [[ "$file_path" == *.mkv ]]; then
          mp4_path="${file_path%.mkv}.mp4"
          (
            if ffmpeg -i "$file_path" \
              -c:v copy \
              -c:a aac \
              -b:a 160k \
              -movflags +faststart \
              "$mp4_path"; then
              conv_action=$(notify-send \
                --app-name="Screen Recording" \
                --icon="replay-record" \
                --expire-time=0 \
                --hint=string:body-markup:true \
                --action="open=Play MP4" \
                --action="folder=Open Folder" \
                --action="delete=Delete Original MKV" \
                "Conversion Complete" \
                "Saved to <b>$mp4_path</b>")

              case "$conv_action" in
              open)
                xdg-open "$mp4_path"
                ;;
              folder)
                xdg-open "$RECORD_DIR"
                ;;
              delete)
                rm -f "$file_path"
                notify-send \
                  --app-name="Screen Recording" \
                  --icon="replay-record" \
                  --expire-time=2000 \
                  "Original Deleted" \
                  "$(basename "$file_path")"
                ;;
              esac
            else
              notify-send \
                --app-name="Screen Recording" \
                --icon="replay-record" \
                --expire-time=0 \
                --hint=string:body-markup:true \
                "Conversion Failed" \
                "Could not convert <b>$(basename "$file_path")</b>"
            fi
          ) &
        fi
        ;;
      folder)
        xdg-open "$RECORD_DIR"
        ;;
      esac
    ) &
  else
    # Simple notification without actions
    notify-send \
      --app-name="Screen Recording" \
      --icon="replay-record" \
      --expire-time=2000 \
      --hint=string:body-markup:true \
      "$summary" \
      "$body" &
  fi
}

start_recording() {
  is_recording && {
    echo "Recording is already active"
    return 1
  }

  [[ " $* " =~ " quickshell " ]] && sleep 0.1 && { update_quickshell "started" & }

  local monitor=$(get_focused_monitor)
  local filepath="$RECORD_DIR/Video_$(date +"%Y-%m-%d_%H-%M-%S").mkv"
  local capture_target="$monitor"
  local region_arg=""
  local region_desc=""
  local specified_monitor=""
  local has_region=false

  # Check arguments for monitor name, region, or other modifiers
  for arg in "$@"; do
    # Skip known modifiers
    if [[ "$arg" == "quickshell" ]] || [[ "$arg" == "notif" ]] || [[ "$arg" == "mic" ]]; then
      continue
    fi

    # Check if it's a region argument (format: WxH+X+Y)
    if [[ "$arg" =~ ^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$ ]]; then
      has_region=true

      # If a monitor was specified, calculate absolute coordinates
      if [[ -n "$specified_monitor" ]]; then
        # Get monitor position from hyprctl
        local monitor_info=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$specified_monitor\") | .x, .y")
        local monitor_x=$(echo "$monitor_info" | head -1)
        local monitor_y=$(echo "$monitor_info" | tail -1)

        # Parse region coordinates
        local width=$(echo "$arg" | cut -d'x' -f1)
        local rest=$(echo "$arg" | cut -d'x' -f2)
        local height=$(echo "$rest" | cut -d'+' -f1)
        local region_x=$(echo "$rest" | cut -d'+' -f2)
        local region_y=$(echo "$rest" | cut -d'+' -f3)

        # Calculate absolute coordinates
        local abs_x=$((monitor_x + region_x))
        local abs_y=$((monitor_y + region_y))

        region_arg="-region ${width}x${height}+${abs_x}+${abs_y}"
        region_desc=" (monitor: $specified_monitor, region: $arg → absolute: ${width}x${height}+${abs_x}+${abs_y})"
      else
        region_arg="-region $arg"
        region_desc=" (region: $arg)"
      fi

      # When we have a region, we must use '-w region'
      capture_target="region"
      continue
    fi

    # Check if it's a valid monitor name
    if is_valid_monitor "$arg"; then
      specified_monitor="$arg"
      # Only use the monitor as capture target if we don't have a region
      if [[ "$has_region" == false ]]; then
        capture_target="$arg"
        region_desc=" (monitor: $specified_monitor)"
      fi
      continue
    fi
  done

  # Build the command
  local audio_arg
  if [[ " $* " =~ " mic " ]]; then
    audio_arg="-a default_output|default_input"
    echo "Recording started with microphone on $capture_target$region_desc: $(basename "$filepath")"
    [[ " $* " =~ " notif " ]] && notify "Recording Started (mic)" "Saving to <b>$filepath</b>"
  else
    audio_arg="-a default_output"
    echo "Recording started on $capture_target$region_desc: $(basename "$filepath")"
    [[ " $* " =~ " notif " ]] && notify "Recording Started" "Saving to <b>$filepath</b>"
  fi

  # Execute the recording command
  gpu-screen-recorder -w "$capture_target" $region_arg -q ultra -cr full -fm cfr -k h264 -ac aac -f 60 -c mkv $audio_arg -o "$filepath" &
}

stop_recording() {
  [[ " $* " =~ " quickshell " ]] && sleep 0.1 && { update_quickshell "stopped" & }
  is_recording || {
    echo "No recording is currently active"
    return 1
  }
  pkill -SIGINT -f gpu-screen-recorder
  echo "Recording stopped"
  if [[ " $* " =~ " notif " ]]; then
    local latest_file=$(get_latest)
    [[ -n "$latest_file" ]] && notify "Recording Stopped" "Saved to <b>$latest_file</b>" "$latest_file" || notify "Recording Stopped" "Saved to <b>$RECORD_DIR</b>"
  fi
}

toggle_recording() { is_recording && stop_recording "$@" || start_recording "$@"; }

update_quickshell() {
  local state="$1" # "started" or "stopped"

  if [[ "$state" == "stopped" ]]; then
    qs ipc call data set "isRecording" false &
  else
    qs ipc call data set "isRecording" true &
  fi
}

case "$1" in
start) start_recording "$@" ;;
stop) stop_recording "$@" ;;
toggle) toggle_recording "$@" ;;
status | notif)
  if is_recording; then
    echo "Currently recording"
    [[ " $* " =~ " notif " ]] || [[ "$1" == "notif" ]] && notify "Recording Active" "Saving to <b>$RECORD_DIR</b>"
  else
    echo "Not currently recording"
    if [[ " $* " =~ " notif " ]] || [[ "$1" == "notif" ]]; then
      latest_file=$(get_latest)
      [[ -n "$latest_file" ]] && notify "Not Recording" "Last: <b>$latest_file</b>" "$latest_file" || notify "Not Recording" "No recordings in <b>$RECORD_DIR</b>"
    fi
  fi
  ;;
open)
  latest_file=$(get_latest)
  [[ -n "$latest_file" ]] && {
    xdg-open "$latest_file"
    echo "Opened: $("$latest_file")"
  } || {
    xdg-open "$RECORD_DIR"
    echo "Opened recordings folder"
  }
  ;;
folder)
  xdg-open "$RECORD_DIR"
  echo "Opened recordings folder: $RECORD_DIR"
  ;;
*)
  cat <<'EOF'
Usage: $0 [start|stop|toggle|status|open|folder|quickshell] [modifiers...] [monitor|region]

Commands:
  start      - Start screen recording (focused monitor by default)
  stop       - Stop screen recording
  toggle     - Toggle recording on/off
  status     - Show current recording status
  open       - Open latest recording or recordings folder
  folder     - Open recordings folder

Modifiers:
  notif      - Send notifications (can be combined with other commands)
  quickshell - Update QuickShell config (can be combined with other commands)
  mic        - Include microphone input in recording (can be combined with other commands)

Monitor/Region:
  MONITOR    - Specify monitor name (e.g., HDMI-A-1, DP-1, eDP-1)
               To list available monitors: hyprctl monitors
  WxH+X+Y    - Record specific region (e.g., 1920x1080+0+0)
               Can be obtained from tools like slurp or slop
               Format: width x height + X offset + Y offset
               Can be combined with monitor name to record region on specific monitor

Examples:
  $0 start notif                         - Start recording focused monitor with notification
  $0 start HDMI-A-1                      - Start recording specific monitor
  $0 start HDMI-A-1 1920x1080+0+0        - Start recording region on specific monitor
  $0 start HDMI-A-1 1920x1080+0+0 mic    - Start recording region on monitor with mic
  $0 start DP-1 mic notif                - Start recording DP-1 with microphone and notification
  $0 start mic                           - Start recording with microphone
  $0 start mic notif                     - Start recording with microphone and notification
  $0 start 1920x1080+0+0                 - Start recording specific region on focused monitor
  $0 start 1920x1080+0+0 mic notif       - Start recording region with mic and notification
  $0 start $(slurp -f "%wx%h+%x+%y")     - Start recording region selected with slurp
  $0 toggle quickshell                   - Toggle recording and update QuickShell
  $0 stop notif quickshell               - Stop recording with notification and update QuickShell
  $0 status notif                        - Check status with notification
  $0 open                                - Open latest recording
EOF
  exit 1
  ;;
esac
