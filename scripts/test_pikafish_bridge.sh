#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$project_root/.derived/engine-smoke"
mkdir -p "$output_dir"

sources=()
while IFS= read -r source; do
  sources+=("$source")
done < <(find "$project_root/Vendor/Pikafish/src" -name '*.cpp' \
  -not -path '*/universal/*' -not -name 'main.cpp' | sort)

xcrun clang++ -std=c++17 -O2 -pthread -DIS_64BIT -DUSE_NEON=8 \
  -I"$project_root/EngineBridge" \
  -I"$project_root/Vendor/Pikafish/src" \
  "$project_root/EngineBridge/PikafishBridge.cpp" \
  "$project_root/Tests/EngineBridgeTests/PikafishBridgeSmoke.cpp" \
  "${sources[@]}" \
  -o "$output_dir/pikafish-smoke"

"$output_dir/pikafish-smoke" "$project_root/Resources/Engine/pikafish.nnue"
