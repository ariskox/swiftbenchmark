#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATED_DIR="$WORKSPACE_DIR/SlowCompilationExample/generated"
FILE_PREFIX="GeneratedTask"

print_usage() {
  cat <<EOF
Usage: $(basename "$0") <task_count>

Create numbered Swift files in SlowCompilationExample/generated.

Arguments:
  task_count   Number of Swift files to create (positive integer)

Notes:
  - Existing files are never overwritten.
  - If files already exist, numbering continues from the highest index.

Example:
  $(basename "$0") 50
EOF
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  echo "Expected exactly 1 argument: <task_count>" >&2
  print_usage
  exit 1
fi

TASK_COUNT="$1"
if ! is_positive_integer "$TASK_COUNT"; then
  echo "task_count must be a positive integer, got: $TASK_COUNT" >&2
  exit 1
fi

mkdir -p "$GENERATED_DIR"

max_index=0
shopt -s nullglob
for path in "$GENERATED_DIR"/${FILE_PREFIX}*.swift; do
  file_name="$(basename "$path")"
  if [[ "$file_name" =~ ^${FILE_PREFIX}([0-9]+)\.swift$ ]]; then
    current_index="${BASH_REMATCH[1]}"
    if (( current_index > max_index )); then
      max_index="$current_index"
    fi
  fi
done
shopt -u nullglob

created_count=0
next_index=$((max_index + 1))

for ((i=1; i<=TASK_COUNT; i++)); do
  while [[ -e "$GENERATED_DIR/${FILE_PREFIX}${next_index}.swift" ]]; do
    next_index=$((next_index + 1))
  done

  output_file="$GENERATED_DIR/${FILE_PREFIX}${next_index}.swift"

  cat > "$output_file" <<EOF
import Foundation

struct ${FILE_PREFIX}${next_index}: Equatable {
    let id: Int
    let name: String
    let values: [Int]
}

@inline(never)
func run${FILE_PREFIX}${next_index}(seed: Int) -> Int {
    let base = ${FILE_PREFIX}${next_index}(id: seed, name: "task_\(seed)", values: Array(0..<8).map { \$0 + seed })
    let mirror = ${FILE_PREFIX}${next_index}(id: seed, name: "task_\(seed)", values: Array(0..<8).map { \$0 + seed })
    return base == mirror ? base.values.reduce(0, +) : -1
}
EOF

  created_count=$((created_count + 1))
  next_index=$((next_index + 1))
done

echo "Created $created_count file(s) in: $GENERATED_DIR"
