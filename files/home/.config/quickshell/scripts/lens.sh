#!/bin/sh
# usage: lens.sh [--legacy|--uguu] /path/to/image.png
#   default  : auto-submitting local HTML page, POSTs straight to Google Lens
#   --legacy : upload to uguu.se, then open Lens with uploadbyurl

mode=direct
img=

while [ $# -gt 0 ]; do
  case "$1" in
  --legacy | --uguu) mode=legacy ;;
  -h | --help)
    sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  --)
    shift
    img="$1"
    break
    ;;
  -*)
    echo "lens.sh: unknown option: $1" >&2
    exit 2
    ;;
  *) img="$1" ;;
  esac
  shift
done

[ -n "$img" ] && [ -f "$img" ] || {
  echo "lens.sh: missing or invalid image path" >&2
  exit 2
}

if [ "$mode" = legacy ]; then
  url=$(curl -sF "files[]=@$img" https://uguu.se/upload | jq -r '.files[0].url // empty')
  [ -n "$url" ] || {
    echo "lens.sh: uguu upload failed" >&2
    exit 1
  }
  exec xdg-open "https://lens.google.com/uploadbyurl?url=$url"
fi

out=/tmp/bnsplit/screenshots/lens.html
b64=$(base64 -w0 "$img")

cat >"$out" <<EOF
<!doctype html>
<meta charset="utf-8">
<meta name="color-scheme" content="dark">
<title></title>
<style>
  html, body { margin: 0; height: 100%; color-scheme: dark; overflow: hidden; }
  form, input { display: none; }
</style>
<form id="f" method="POST" action="https://lens.google.com/v3/upload" enctype="multipart/form-data">
  <input type="file" name="encoded_image" id="i">
</form>
<script>
  const b = atob("$b64");
  const a = new Uint8Array(b.length);
  for (let k = 0; k < b.length; k++) a[k] = b.charCodeAt(k);
  const dt = new DataTransfer();
  dt.items.add(new File([a], "image.png", { type: "image/png" }));
  document.getElementById("i").files = dt.files;
  document.getElementById("f").submit();
</script>
EOF

xdg-open "$out"
