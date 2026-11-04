#!/usr/bin/env bash
set -euo pipefail

dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
out=$dir/files

rm -rf -- "$out"
mkdir -p -- "$out"

while IFS= read -r line || [[ -n $line ]]; do
  [[ -z $line || $line == \#* ]] && continue

  src=${line/#\~/$HOME}
  src=${src%/}
  [[ -e $src ]] || continue

  if [[ $src == "$HOME"/* ]]; then
    rel=home/${src#"$HOME"/}
  else
    rel=root/${src#/}
  fi
  dest=$out/$rel

  echo "$src -> files/$rel"
  if [[ -d $src ]]; then
    rsync -a --mkpath --exclude-from="$dir/excludes.txt" "$src/" "$dest/"
  else
    rsync -a --mkpath --exclude-from="$dir/excludes.txt" "$src" "$dest"
  fi
done <"$dir/includes.txt"

# greeter palette from the bundled default wallpaper
asset=$out/home/.config/quickshell/assets/default-wallpaper
cfg=$out/home/.config/bnchroma/config.toml
tpl=$out/home/.config/bnchroma/templates/quickshell.json
colors=$out/home/.config/quickshell/store/colors.json

[[ -f $asset && -f $cfg && -f $tpl ]] || {
  echo "missing default wallpaper or bnchroma config/template" >&2
  exit 1
}
command -v bnchroma >/dev/null || {
  echo "bnchroma not found" >&2
  exit 1
}
command -v ffmpeg >/dev/null || {
  echo "ffmpeg not found" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

awk '/^\[\[templates\]\]/{exit} {print}' "$cfg" >"$tmp/bnchroma.toml"
cat >>"$tmp/bnchroma.toml" <<EOF

[[templates]]
name = "quickshell"
template = "$tpl"
output = "$tmp/colors.json"
EOF

ffmpeg -y -loglevel error -i "$asset" \
  -vf "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080" \
  -vframes 1 -c:v libwebp -quality 88 -compression_level 6 \
  "$tmp/default-wallpaper.webp"
bnchroma --config "$tmp/bnchroma.toml" --path "$tmp/default-wallpaper.webp" \
  --color-index 1 --min-lightness 0.025 --max-lightness 1.0 --force --quiet

[[ -s $tmp/colors.json ]] || {
  echo "bnchroma did not produce colors.json" >&2
  exit 1
}
mkdir -p -- "$(dirname -- "$colors")"
cp -- "$tmp/colors.json" "$colors"
printf 'generated files/%s\n' "${colors#"$out"/}"
