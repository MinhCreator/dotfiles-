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
