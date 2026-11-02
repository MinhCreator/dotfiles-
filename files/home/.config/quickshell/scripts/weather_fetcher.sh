#!/bin/bash

CACHE_DIR="$HOME/.cache/bnsplit/weather"
LOCATION_CACHE="$CACHE_DIR/location.cache"
WEATHER_CACHE="$CACHE_DIR/weather.cache"
OUTPUT_FILE="$HOME/.local/state/bnsplit/weather.json"
CACHE_TTL=600
LOOP_INTERVAL=1800
UPDATE_THRESHOLD=1800

ONE_SHOT=false
FORCE_UPDATE=false

while [[ $# -gt 0 ]]; do
  case $1 in
  --once | -o)
    ONE_SHOT=true
    shift
    ;;
  --force | -f)
    FORCE_UPDATE=true
    shift
    ;;
  *)
    echo "Usage: $0 [--once|-o] [--force|-f]"
    echo "  --once, -o    Run once and exit"
    echo "  --force, -f  Force update (only with --once)"
    exit 1
    ;;
  esac
done

if [[ "$FORCE_UPDATE" == true && "$ONE_SHOT" == false ]]; then
  echo "Error: --force can only be used with --once" >&2
  exit 1
fi

mkdir -p "$CACHE_DIR"
mkdir -p "$(dirname "$OUTPUT_FILE")"

should_update() {
  if [[ "$FORCE_UPDATE" == true ]]; then
    echo "Force update requested, proceeding..." >&2
    return 0
  fi
  if [[ ! -f "$OUTPUT_FILE" ]]; then return 0; fi
  local is_updating
  is_updating=$(jq -r '.is_updating // false' "$OUTPUT_FILE" 2>/dev/null)
  if [[ "$is_updating" == "true" ]]; then
    echo "Another instance is already updating, skipping..." >&2
    return 1
  fi
  local last_updated
  last_updated=$(jq -r '.last_updated // empty' "$OUTPUT_FILE" 2>/dev/null)
  if [[ -z "$last_updated" ]]; then return 0; fi
  local last_epoch now_epoch time_diff
  last_epoch=$(date -d "$last_updated" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  time_diff=$((now_epoch - last_epoch))
  if ((time_diff >= UPDATE_THRESHOLD)); then
    return 0
  else
    echo "Last update was $time_diff seconds ago (threshold: $UPDATE_THRESHOLD), skipping..." >&2
    return 1
  fi
}

set_updating_flag() {
  local flag=$1
  if [[ -f "$OUTPUT_FILE" ]]; then
    local tmpf=$(mktemp)
    jq --argjson updating "$flag" '.is_updating = $updating' "$OUTPUT_FILE" >"$tmpf" && mv "$tmpf" "$OUTPUT_FILE"
  else
    echo "{\"is_updating\": $flag}" >"$OUTPUT_FILE"
  fi
}

check_connection() {
  if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then return 1; fi
}

get_location() {
  if [[ -f "$LOCATION_CACHE" ]]; then
    local now=$(date +%s)
    local modified=$(stat -c %Y "$LOCATION_CACHE" 2>/dev/null)
    if ((now - modified < CACHE_TTL)); then
      cat "$LOCATION_CACHE"
      return 0
    fi
  fi
  local location_data
  if ! location_data=$(curl -s -f --max-time 5 "http://ip-api.com/json"); then
    echo "Location service unavailable" >&2
    return 1
  fi
  jq -r '"\(.lat),\(.lon)"' <<<"$location_data" | tee "$LOCATION_CACHE"
}

assoc_to_json() {
  local -n arr=$1
  echo -n '{'
  local first=true
  for key in "${!arr[@]}"; do
    if [[ "$first" == true ]]; then first=false; else echo -n ','; fi
    printf '"%s":"%s"' "$key" "${arr[$key]}"
  done
  echo '}'
}

# --- Weather Mappings ---
declare -A weather_descriptions=(
  [0]="Clear sky" [1]="Mainly clear" [2]="Partly cloudy" [3]="Overcast"
  [45]="Fog" [48]="Depositing rime fog"
  [51]="Light drizzle" [53]="Moderate drizzle" [55]="Dense drizzle"
  [56]="Light freezing drizzle" [57]="Dense freezing drizzle"
  [61]="Slight rain" [63]="Moderate rain" [65]="Heavy rain"
  [66]="Light freezing rain" [67]="Heavy freezing rain"
  [71]="Slight snow fall" [73]="Moderate snow fall" [75]="Heavy snow fall"
  [77]="Snow grains"
  [80]="Slight rain showers" [81]="Moderate rain showers" [82]="Violent rain showers"
  [85]="Slight snow showers" [86]="Heavy snow showers"
  [95]="Slight thunderstorm" [96]="Thunderstorm with slight hail" [99]="Thunderstorm with heavy hail"
)

declare -A weather_icons=(
  [0]="clear_day" [1]="mostly_clear_night" [2]="partly_cloudy_day" [3]="cloudy"
  [45]="haze_fog" [48]="haze_fog"
  [51]="drizzle" [53]="drizzle" [55]="drizzle"
  [56]="wintry_mix" [57]="wintry_mix"
  [61]="rain_showers" [63]="rain_showers" [65]="heavy_rain"
  [66]="sleet_hail" [67]="sleet_hail"
  [71]="snow_showers" [73]="heavy_snow" [75]="heavy_snow"
  [77]="flurries"
  [80]="scattered_rain_showers_day" [81]="rain_showers" [82]="heavy_rain"
  [85]="scattered_snow_showers_day" [86]="snow_showers"
  [95]="thunderstorms" [96]="strong_thunderstorms" [99]="strong_thunderstorms"
)

declare -A weather_material_symbols=(
  [0]="sunny" [1]="partly_cloudy_day" [2]="partly_cloudy_day" [3]="cloud"
  [45]="foggy" [48]="foggy"
  [51]="rainy_light" [53]="rainy_light" [55]="rainy"
  [56]="weather_mix" [57]="weather_mix"
  [61]="rainy" [63]="rainy" [65]="rainy"
  [66]="weather_mix" [67]="weather_mix"
  [71]="weather_snowy" [73]="weather_snowy" [75]="severe_cold"
  [77]="snowing"
  [80]="rainy" [81]="rainy" [82]="rainy"
  [85]="snowing" [86]="snowing"
  [95]="thunderstorm" [96]="thunderstorm" [99]="thunderstorm"
)

# --- Wind speed icons ---
declare -A wind_speed_icons=([calm]="windy" [light]="windy" [moderate]="windy" [strong]="windy" [storm]="tornado")
declare -A wind_speed_material_symbols=([calm]="air" [light]="air" [moderate]="wind_power" [strong]="wind_power" [storm]="tornado")

# --- Humidity icons ---
declare -A humidity_icons=([low]="humidity_low" [moderate]="humidity_mid" [high]="humidity_high")
declare -A humidity_material_symbols=([low]="humidity_low" [moderate]="humidity_mid" [high]="humidity_high")

# --- Apparent temperature icons ---
declare -A apparent_temp_icons=([very_cold]="ac_unit" [cold]="ac_unit" [comfortable]="thermostat" [warm]="wb_sunny" [hot]="local_fire_department")
declare -A apparent_temp_material_symbols=([very_cold]="ac_unit" [cold]="device_thermostat" [comfortable]="thermostat" [warm]="wb_sunny" [hot]="local_fire_department")

# --- Rain icons ---
declare -A rain_icons=([none]="clear_day" [light]="drizzle" [moderate]="rain_showers" [heavy]="heavy_rain")
declare -A rain_material_symbols=([none]="clear_day" [light]="rainy_light" [moderate]="rainy" [heavy]="rainy")

process_weather() {
  local descs_json icons_json material_json update_time
  descs_json=$(assoc_to_json weather_descriptions)
  icons_json=$(assoc_to_json weather_icons)
  material_json=$(assoc_to_json weather_material_symbols)

  local wind_icons_json wind_material_json
  wind_icons_json=$(assoc_to_json wind_speed_icons)
  wind_material_json=$(assoc_to_json wind_speed_material_symbols)

  local humidity_icons_json humidity_material_json
  humidity_icons_json=$(assoc_to_json humidity_icons)
  humidity_material_json=$(assoc_to_json humidity_material_symbols)

  local apparent_icons_json apparent_material_json
  apparent_icons_json=$(assoc_to_json apparent_temp_icons)
  apparent_material_json=$(assoc_to_json apparent_temp_material_symbols)

  local precip_icons_json precip_material_json
  precip_icons_json=$(assoc_to_json rain_icons)
  precip_material_json=$(assoc_to_json rain_material_symbols)

  update_time=$(date -Iseconds)

  jq --argjson descs "$descs_json" \
    --argjson icons "$icons_json" \
    --argjson material "$material_json" \
    --argjson wind_icons "$wind_icons_json" \
    --argjson wind_material "$wind_material_json" \
    --argjson hum_icons "$humidity_icons_json" \
    --argjson hum_material "$humidity_material_json" \
    --argjson app_icons "$apparent_icons_json" \
    --argjson app_material "$apparent_material_json" \
    --argjson precip_icons "$precip_icons_json" \
    --argjson precip_material "$precip_material_json" \
    --arg updated "$update_time" '

  def get_desc(code): $descs[code | tostring] // "Unknown";
  def get_icon(code): $icons[code | tostring] // "clear_day";
  def get_material(code): $material[code | tostring] // "sunny";

  def wind_bucket(spd):
    if spd < 5 then "calm"
    elif spd < 20 then "light"
    elif spd < 40 then "moderate"
    elif spd < 60 then "strong"
    else "storm" end;

  def humidity_bucket(h):
    if h < 40 then "low"
    elif h < 70 then "moderate"
    else "high" end;

  def apparent_bucket(t):
    if t < 0 then "very_cold"
    elif t < 10 then "cold"
    elif t < 25 then "comfortable"
    elif t < 35 then "warm"
    else "hot" end;

  def precip_bucket(r):
    if r == 0 then "none"
    elif r < 2 then "light"
    elif r < 10 then "moderate"
    else "heavy" end;

  {
    last_updated: $updated,
    is_updating: false,
    latitude,
    longitude,
    generationtime_ms,
    utc_offset_seconds,
    timezone,
    timezone_abbreviation,
    elevation,
    current: {
      time: .current.time,
      is_day: .current.is_day,
      temperature: .current.temperature_2m,
      weather_code: .current.weather_code,
      weather_description: get_desc(.current.weather_code),
      weather_icon: get_icon(.current.weather_code),
      weather_material_symbol: get_material(.current.weather_code),

      apparent_temperature: .current.apparent_temperature,
      apparent_temperature_icon: $app_icons[apparent_bucket(.current.apparent_temperature)],
      apparent_temperature_material_symbol: $app_material[apparent_bucket(.current.apparent_temperature)],

      wind_speed: .current.wind_speed_10m,
      wind_speed_icon: $wind_icons[wind_bucket(.current.wind_speed_10m)],
      wind_speed_material_symbol: $wind_material[wind_bucket(.current.wind_speed_10m)],

      humidity: .current.relative_humidity_2m,
      humidity_icon: $hum_icons[humidity_bucket(.current.relative_humidity_2m)],
      humidity_material_symbol: $hum_material[humidity_bucket(.current.relative_humidity_2m)],

      precipitation: .current.precipitation,
      precipitation_icon: $precip_icons[precip_bucket(.current.precipitation)],
      precipitation_material_symbol: $precip_material[precip_bucket(.current.precipitation)]
    },
    hourly: [.hourly.time, .hourly.temperature_2m, .hourly.weather_code] |
            transpose | map({
              time: .[0],
              temperature: .[1],
              weather_code: .[2],
              weather_description: get_desc(.[2]),
              weather_icon: get_icon(.[2]),
              weather_material_symbol: get_material(.[2])
            }),
    daily: [.daily.time, .daily.weather_code, .daily.temperature_2m_min, .daily.temperature_2m_max] |
           transpose | map({
             time: .[0],
             weather_code: .[1],
             weather_description: get_desc(.[1]),
             weather_icon: get_icon(.[1]),
             weather_material_symbol: get_material(.[1]),
             temperature_min: .[2],
             temperature_max: .[3]
           })
  }'
}

get_weather_data() {
  if ! check_connection; then
    echo "No internet connection" >&2
    return 1
  fi

  local coords
  if ! coords=$(get_location); then
    echo "Failed to get location" >&2
    return 1
  fi

  IFS=',' read -r LAT LON <<<"$coords"

  local weather_json=""
  if [[ -f "$WEATHER_CACHE" ]]; then
    local now=$(date +%s)
    local modified=$(stat -c %Y "$WEATHER_CACHE" 2>/dev/null)
    if ((now - modified < CACHE_TTL)); then
      weather_json=$(cat "$WEATHER_CACHE")
    fi
  fi

  if [[ -z "$weather_json" ]]; then
    if ! weather_json=$(curl -s -f --max-time 5 \
      "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&daily=weather_code,temperature_2m_min,temperature_2m_max&hourly=temperature_2m,weather_code&current=temperature_2m,weather_code,apparent_temperature,wind_speed_10m,relative_humidity_2m,precipitation,is_day&timezone=GMT"); then
      echo "Weather service unavailable" >&2
      return 1
    fi
    echo "$weather_json" >"$WEATHER_CACHE"
  fi

  process_weather <<<"$weather_json"
}

perform_update() {
  set_updating_flag true

  local tmpf=$(mktemp)
  local success=false

  if get_weather_data >"$tmpf"; then
    mv "$tmpf" "$OUTPUT_FILE"
    echo "Weather data updated successfully"
    success=true
  else
    echo "Weather update failed" >&2
    rm -f "$tmpf"
    set_updating_flag false
  fi

  return $([ "$success" = true ] && echo 0 || echo 1)
}

cleanup() {
  echo "Weather monitor stopping..."
  set_updating_flag false
  exit 0
}

trap cleanup INT TERM EXIT

if [[ "$ONE_SHOT" == true ]]; then
  echo "Running in one-shot mode..."
  if should_update; then
    if perform_update; then exit 0; else exit 1; fi
  else
    echo "Update not needed, exiting..."
    exit 0
  fi
fi

echo "Starting weather monitor..."

if should_update; then
  perform_update
else
  echo "Skipping initial update (too soon)"
fi

while true; do
  sleep "$LOOP_INTERVAL"
  if should_update; then
    perform_update
  else
    echo "Skipping update (too soon or another instance is updating)"
  fi
done
