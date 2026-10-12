#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-"$project_dir/build/web"}"
odin_bin="${ODIN:-odin}"
odin_root="$("$odin_bin" root)"

if ! command -v wasm-ld >/dev/null; then
  echo 'Missing wasm-ld. Install LLVM lld before building for the browser.' >&2
  exit 1
fi

mkdir -p "$output_dir/assets/fonts"
"$odin_bin" build "$project_dir" -target:js_wasm32 -o:size -vet -strict-style \
  -out:"$output_dir/game.wasm" -extra-linker-flags:"--strip-all"
cp "$odin_root/core/sys/wasm/js/odin.js" "$output_dir/odin.js"
cp "$project_dir/web/index.html" "$project_dir/web/app.js" "$output_dir/"
for asset in example-tiles example-factory example-player-board light-wood-table; do
  cp "$project_dir/assets/$asset.webp" "$output_dir/assets/"
done
for asset in spectral-semibold.png spectral-semibold.fnt OFL.txt; do
  cp "$project_dir/assets/fonts/$asset" "$output_dir/assets/fonts/"
done
printf 'Built %s (%s bytes of WASM)\n' "$output_dir" "$(wc -c < "$output_dir/game.wasm")"
