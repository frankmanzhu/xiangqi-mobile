#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$project_root/.derived/rules-differential"
mkdir -p "$output_dir"
xcrun swiftc -O -parse-as-library \
  "$project_root/XiangqiMobile/Core/Domain.swift" \
  "$project_root/XiangqiMobile/Core/Position.swift" \
  "$project_root/XiangqiMobile/Core/Rules.swift" \
  "$project_root/Tests/EngineBridgeTests/RulesPlayouts.swift" \
  -o "$output_dir/positions"
sources=()
while IFS= read -r source; do sources+=("$source"); done < <(
  find "$project_root/Vendor/Pikafish/src" -name '*.cpp' \
    -not -path '*/universal/*' -not -name 'main.cpp' | sort
)
xcrun clang++ -std=c++17 -O2 -pthread -DIS_64BIT -DUSE_NEON=8 \
  -I"$project_root/Vendor/Pikafish/src" \
  "$project_root/Tests/EngineBridgeTests/RulesDifferential.cpp" \
  "${sources[@]}" -o "$output_dir/compare"
"$output_dir/positions" | "$output_dir/compare"
