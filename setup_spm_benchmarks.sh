#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_POOL_DIR="$WORKSPACE_DIR/swift_tasks_7000"
BENCHMARKS_DIR="$WORKSPACE_DIR/Benchmarks"
FILE_PREFIX="GeneratedTask"
TOTAL_FILES=7000

PROJECT1_DIR="$BENCHMARKS_DIR/Project1_1Target_7000"
PROJECT2_DIR="$BENCHMARKS_DIR/Project2_2Targets_3500x2"
PROJECT3_DIR="$BENCHMARKS_DIR/Project3_4Targets_1750x4"
PROJECT4_DIR="$BENCHMARKS_DIR/Project4_8Targets_875x8"
PROJECT5_DIR="$BENCHMARKS_DIR/Project5_16Targets_Approx438x16"
PROJECT6_DIR="$BENCHMARKS_DIR/Project6_32Targets_Approx218x32"
PROJECT7_DIR="$BENCHMARKS_DIR/Project7_64Targets_Approx110x64"
PROJECT8_DIR="$BENCHMARKS_DIR/Project8_12Targets_Approx583x12"
PROJECT9_DIR="$BENCHMARKS_DIR/Project9_24Targets_Approx291x24"

print_usage() {
  cat <<EOF
Usage: $(basename "$0")

Create and populate all SwiftPM benchmark projects from the shared 7000-file pool.

Expected source pool:
  $SOURCE_POOL_DIR

Run this first if needed:
  ./generate_swift_tasks.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

count_files() {
  local dir="$1"
  find "$dir" -maxdepth 1 -type f -name "${FILE_PREFIX}*.swift" | wc -l | tr -d ' '
}

copy_range() {
  local src_dir="$1"
  local dst_dir="$2"
  local start_idx="$3"
  local end_idx="$4"
  local i

  mkdir -p "$dst_dir"
  rm -f "$dst_dir"/*.swift

  for ((i=start_idx; i<=end_idx; i++)); do
    cp "$src_dir/${FILE_PREFIX}${i}.swift" "$dst_dir/"
  done
}

write_project1_package() {
  cat > "$PROJECT1_DIR/Package.swift" <<'EOF'
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Project1_1Target_7000",
    products: [
        .library(name: "BenchmarkCore", targets: ["BenchmarkCore"])
    ],
    targets: [
        .target(name: "BenchmarkCore")
    ]
)
EOF
}

write_project2_package() {
  cat > "$PROJECT2_DIR/Package.swift" <<'EOF'
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Project2_2Targets_3500x2",
    products: [
        .library(name: "BenchmarkTop", targets: ["BenchmarkTop"])
    ],
    targets: [
        .target(name: "BenchmarkBase"),
        .target(name: "BenchmarkTop", dependencies: ["BenchmarkBase"])
    ]
)
EOF
}

target_name_for_index() {
  local index="$1"
  local total="$2"
  local width="${#total}"

  printf "BenchmarkT%0${width}d" "$index"
}

write_split_project_package() {
  local project_dir="$1"
  local project_name="$2"
  local target_count="$3"
  local i

  local top_target
  top_target="$(target_name_for_index "$target_count" "$target_count")"

  cat > "$project_dir/Package.swift" <<EOF
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "$project_name",
    products: [
        .library(name: "BenchmarkTop", targets: ["$top_target"])
    ],
    targets: [
EOF

  for ((i=1; i<=target_count; i++)); do
    local current_target
    current_target="$(target_name_for_index "$i" "$target_count")"

    if (( i == 1 )); then
      cat >> "$project_dir/Package.swift" <<EOF
        .target(name: "$current_target")
EOF
    else
      local previous_target
      previous_target="$(target_name_for_index "$((i - 1))" "$target_count")"
      cat >> "$project_dir/Package.swift" <<EOF
        .target(name: "$current_target", dependencies: ["$previous_target"])
EOF
    fi

    if (( i < target_count )); then
      echo "        ," >> "$project_dir/Package.swift"
    fi
  done

  cat >> "$project_dir/Package.swift" <<'EOF'
    ]
)
EOF
}

setup_split_project() {
  local project_dir="$1"
  local project_name="$2"
  local target_count="$3"
  local i

  mkdir -p "$project_dir/Sources"
  write_split_project_package "$project_dir" "$project_name" "$target_count"

  local base_count
  local remainder
  base_count="$((TOTAL_FILES / target_count))"
  remainder="$((TOTAL_FILES % target_count))"

  local start_idx=1
  for ((i=1; i<=target_count; i++)); do
    local per_target_count="$base_count"
    if (( i <= remainder )); then
      per_target_count="$((per_target_count + 1))"
    fi

    local end_idx="$((start_idx + per_target_count - 1))"
    local target_name
    target_name="$(target_name_for_index "$i" "$target_count")"
    local target_dir="$project_dir/Sources/$target_name"

    copy_range "$SOURCE_POOL_DIR" "$target_dir" "$start_idx" "$end_idx"
    start_idx="$((end_idx + 1))"
  done
}

ensure_source_pool() {
  if [[ ! -d "$SOURCE_POOL_DIR" ]]; then
    echo "Missing source pool directory: $SOURCE_POOL_DIR" >&2
    echo "Run ./generate_swift_tasks.sh first." >&2
    exit 1
  fi

  local found_count
  found_count="$(count_files "$SOURCE_POOL_DIR")"
  if [[ "$found_count" -ne "$TOTAL_FILES" ]]; then
    echo "Expected $TOTAL_FILES source files in $SOURCE_POOL_DIR, found $found_count" >&2
    echo "Regenerate with ./generate_swift_tasks.sh" >&2
    exit 1
  fi
}

setup_project1() {
  mkdir -p "$PROJECT1_DIR/Sources/BenchmarkCore"
  write_project1_package
  copy_range "$SOURCE_POOL_DIR" "$PROJECT1_DIR/Sources/BenchmarkCore" 1 7000
}

setup_project2() {
  mkdir -p "$PROJECT2_DIR/Sources/BenchmarkBase"
  mkdir -p "$PROJECT2_DIR/Sources/BenchmarkTop"
  write_project2_package
  copy_range "$SOURCE_POOL_DIR" "$PROJECT2_DIR/Sources/BenchmarkBase" 1 3500
  copy_range "$SOURCE_POOL_DIR" "$PROJECT2_DIR/Sources/BenchmarkTop" 3501 7000
}

setup_project3() {
  setup_split_project "$PROJECT3_DIR" "Project3_4Targets_1750x4" 4
}

setup_project4() {
  setup_split_project "$PROJECT4_DIR" "Project4_8Targets_875x8" 8
}

setup_project5() {
  setup_split_project "$PROJECT5_DIR" "Project5_16Targets_Approx438x16" 16
}

setup_project6() {
  setup_split_project "$PROJECT6_DIR" "Project6_32Targets_Approx218x32" 32
}

setup_project7() {
  setup_split_project "$PROJECT7_DIR" "Project7_64Targets_Approx110x64" 64
}

setup_project8() {
  setup_split_project "$PROJECT8_DIR" "Project8_12Targets_Approx583x12" 12
}

setup_project9() {
  setup_split_project "$PROJECT9_DIR" "Project9_24Targets_Approx291x24" 24
}

mkdir -p "$BENCHMARKS_DIR"
ensure_source_pool
setup_project1
setup_project2
setup_project3
setup_project4
setup_project5
setup_project6
setup_project7
setup_project8
setup_project9

echo "Created benchmark projects:"
echo "- $PROJECT1_DIR"
echo "- $PROJECT2_DIR"
echo "- $PROJECT3_DIR"
echo "- $PROJECT4_DIR"
echo "- $PROJECT5_DIR"
echo "- $PROJECT6_DIR"
echo "- $PROJECT7_DIR"
echo "- $PROJECT8_DIR"
echo "- $PROJECT9_DIR"
echo
echo "Build commands:"
echo "- (cd \"$PROJECT1_DIR\" && swift build -c release)"
echo "- (cd \"$PROJECT2_DIR\" && swift build -c release)"
echo "- (cd \"$PROJECT3_DIR\" && swift build -c release)"
echo "- (cd \"$PROJECT4_DIR\" && swift build -c release)"
echo "- (cd \"$PROJECT5_DIR\" && swift build -c release)"
echo "- (cd \"$PROJECT6_DIR\" && swift build -c release)"
echo "- (cd \"$PROJECT7_DIR\" && swift build -c release)"
echo "- (cd \"$PROJECT8_DIR\" && swift build -c release)"
echo "- (cd \"$PROJECT9_DIR\" && swift build -c release)"
