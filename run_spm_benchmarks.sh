#!/usr/bin/env bash

# ariskox@192 CompilationBenchmark % echo $TOOLCHAIN
# /Users/ariskox/Library/Developer/Toolchains/swift-DEVELOPMENT-SNAPSHOT-2026-03-02-a.xctoolchain
# ariskox@192 CompilationBenchmark % echo $TOOLCHAINS
# org.swift.62202603021a

set -uo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARKS_DIR="$WORKSPACE_DIR/Benchmarks"

CONFIGURATION="debug"
TARGET_FILTER=""
BUILD_VARIANT="default"
BATCH_SIZE_LIMIT=""
SWIFT_BUILD_EXTRA_ARGS=()

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [--configuration <debug|release>] [--targets <list>] [--build-variant <default|batch|batch-size-limit>] [--batch-size-limit <XX>]

Compile SwiftPM benchmark projects one by one, starting from the highest target count.

Options:
  -c, --configuration   Build configuration: debug or release (default: debug)
  -t, --targets         Comma-separated target counts to run (examples: 64 or 64,32,8)
  -b, --build-variant   swift build variant: default, batch, or batch-size-limit (default: default)
      --batch-size-limit Value for -driver-batch-size-limit (required with --build-variant batch-size-limit)
  -h, --help            Show this help message
EOF
}

benchmark_name_for_target_count() {
  local target_count="$1"

  case "$target_count" in
    1)
      echo "Project1_1Target_7000"
      ;;
    2)
      echo "Project2_2Targets_3500x2"
      ;;
    4)
      echo "Project3_4Targets_1750x4"
      ;;
    8)
      echo "Project4_8Targets_875x8"
      ;;
    16)
      echo "Project5_16Targets_Approx438x16"
      ;;
    12)
      echo "Project8_12Targets_Approx583x12"
      ;;
    32)
      echo "Project6_32Targets_Approx218x32"
      ;;
    24)
      echo "Project9_24Targets_Approx291x24"
      ;;
    64)
      echo "Project7_64Targets_Approx110x64"
      ;;
    *)
      return 1
      ;;
  esac
}

resolve_selected_benchmarks() {
  local raw_list="$1"
  local item
  local benchmark_name

  SELECTED_BENCHMARK_NAMES=()

  IFS=',' read -r -a requested_targets <<< "$raw_list"
  for item in "${requested_targets[@]}"; do
    local trimmed="${item//[[:space:]]/}"
    if [[ -z "$trimmed" ]]; then
      continue
    fi

    if ! [[ "$trimmed" =~ ^[0-9]+$ ]]; then
      echo "Invalid target count in --targets: $trimmed" >&2
      echo "Allowed values: 64,32,24,16,12,8,4,2,1" >&2
      exit 1
    fi

    if ! benchmark_name="$(benchmark_name_for_target_count "$trimmed")"; then
      echo "Unsupported target count in --targets: $trimmed" >&2
      echo "Allowed values: 64,32,24,16,12,8,4,2,1" >&2
      exit 1
    fi

    # Preserve user order exactly as provided.
    SELECTED_BENCHMARK_NAMES+=("$benchmark_name")
  done

  if [[ "${#SELECTED_BENCHMARK_NAMES[@]}" -eq 0 ]]; then
    echo "--targets was provided but no valid values were found." >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--configuration)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for $1" >&2
          exit 1
        fi
        CONFIGURATION="$2"
        shift 2
        ;;
      -t|--targets)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for $1" >&2
          exit 1
        fi
        TARGET_FILTER="$2"
        shift 2
        ;;
      -b|--build-variant)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for $1" >&2
          exit 1
        fi
        BUILD_VARIANT="$2"
        shift 2
        ;;
      --batch-size-limit)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for $1" >&2
          exit 1
        fi
        BATCH_SIZE_LIMIT="$2"
        shift 2
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        print_usage >&2
        exit 1
        ;;
    esac
  done

  if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
    echo "Invalid configuration: $CONFIGURATION (expected: debug or release)" >&2
    exit 1
  fi

  if [[ -n "$TARGET_FILTER" ]]; then
    resolve_selected_benchmarks "$TARGET_FILTER"
  fi

  if [[ "$BUILD_VARIANT" != "default" && "$BUILD_VARIANT" != "batch" && "$BUILD_VARIANT" != "batch-size-limit" ]]; then
    echo "Invalid build variant: $BUILD_VARIANT (expected: default, batch, or batch-size-limit)" >&2
    exit 1
  fi

  if [[ "$BUILD_VARIANT" == "batch-size-limit" ]]; then
    if [[ -z "$BATCH_SIZE_LIMIT" ]]; then
      echo "--batch-size-limit is required when --build-variant=batch-size-limit" >&2
      exit 1
    fi
    if ! [[ "$BATCH_SIZE_LIMIT" =~ ^[0-9]+$ ]]; then
      echo "Invalid --batch-size-limit: $BATCH_SIZE_LIMIT (expected a positive integer)" >&2
      exit 1
    fi
  elif [[ -n "$BATCH_SIZE_LIMIT" ]]; then
    echo "--batch-size-limit can only be used with --build-variant=batch-size-limit" >&2
    exit 1
  fi

  case "$BUILD_VARIANT" in
    default)
      SWIFT_BUILD_EXTRA_ARGS=()
      ;;
    batch)
      SWIFT_BUILD_EXTRA_ARGS=(
        -Xswiftc -enable-batch-mode
      )
      ;;
    batch-size-limit)
      SWIFT_BUILD_EXTRA_ARGS=(
        -Xswiftc -enable-batch-mode
        -Xswiftc -driver-batch-size-limit
        -Xswiftc "$BATCH_SIZE_LIMIT"
      )
      ;;
  esac
}

format_duration() {
  local seconds="$1"
  local mins
  local rem
  mins=$((seconds / 60))
  rem=$((seconds % 60))
  printf "%02d:%02d (%ds)" "$mins" "$rem" "$seconds"
}

now_epoch_seconds() {
  date +%s
}

parse_args "$@"

if ! command -v swift >/dev/null 2>&1; then
  echo "swift command not found in PATH." >&2
  exit 1
fi

BENCHMARK_NAMES=(
  "Project7_64Targets_Approx110x64"
  "Project6_32Targets_Approx218x32"
  "Project9_24Targets_Approx291x24"
  "Project5_16Targets_Approx438x16"
  "Project8_12Targets_Approx583x12"
  "Project4_8Targets_875x8"
  "Project3_4Targets_1750x4"
  "Project2_2Targets_3500x2"
  "Project1_1Target_7000"
)

if [[ -n "$TARGET_FILTER" ]]; then
  BENCHMARK_NAMES=("${SELECTED_BENCHMARK_NAMES[@]}")
fi

TOTAL_BENCHMARKS="${#BENCHMARK_NAMES[@]}"

STATUS=()
DURATION_SECONDS=()
LOG_PATHS=()

TMP_DIR="$(mktemp -d -t spm-bench-build-XXXXXX)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "SwiftPM benchmark compilation"
echo "Configuration: $CONFIGURATION"
echo "Build variant: $BUILD_VARIANT"
if [[ "$BUILD_VARIANT" == "batch-size-limit" ]]; then
  echo "Batch size limit: $BATCH_SIZE_LIMIT"
fi
if [[ -n "$TARGET_FILTER" ]]; then
  echo "Order: user-specified target counts ($TARGET_FILTER)"
else
  echo "Order: highest target count to lowest"
fi
echo

for ((idx=0; idx<TOTAL_BENCHMARKS; idx++)); do
  benchmark_name="${BENCHMARK_NAMES[$idx]}"
  project_dir="$BENCHMARKS_DIR/$benchmark_name"
  log_file="$TMP_DIR/${benchmark_name}.log"
  run_number=$((idx + 1))

  if [[ ! -d "$project_dir" ]]; then
    echo "[$run_number/$TOTAL_BENCHMARKS] $benchmark_name"
    echo "  Step: clean build artifacts ... skipped (project directory not found)"
    echo "  Step: compile ... FAILED"
    echo
    STATUS+=("missing")
    DURATION_SECONDS+=(0)
    LOG_PATHS+=("-")
    continue
  fi

  echo "[$run_number/$TOTAL_BENCHMARKS] $benchmark_name"
  echo "  Step: clean build artifacts ..."
  if (cd "$project_dir" && swift package clean >/dev/null 2>&1); then
    echo "  Step: clean build artifacts ... done"
  else
    echo "  Step: clean build artifacts ... failed (continuing to compile)"
  fi

  echo "  Step: compile ($CONFIGURATION) ..."
  start_ts="$(now_epoch_seconds)"
  if (cd "$project_dir" && swift build -c "$CONFIGURATION" "${SWIFT_BUILD_EXTRA_ARGS[@]}" >"$log_file" 2>&1); then
    end_ts="$(now_epoch_seconds)"
    elapsed=$((end_ts - start_ts))
    STATUS+=("ok")
    DURATION_SECONDS+=("$elapsed")
    LOG_PATHS+=("$log_file")
    echo "  Step: compile ... done ($(format_duration "$elapsed"))"
  else
    end_ts="$(now_epoch_seconds)"
    elapsed=$((end_ts - start_ts))
    STATUS+=("failed")
    DURATION_SECONDS+=("$elapsed")
    LOG_PATHS+=("$log_file")
    echo "  Step: compile ... FAILED ($(format_duration "$elapsed"))"
    echo "  Error excerpt:"
    tail -n 20 "$log_file" | sed 's/^/    /'
  fi

  echo

done

echo "Compilation results"
RESULTS_TSV="$TMP_DIR/results.tsv"
{
  printf "#\tBenchmark\tStatus\tDuration\tSeconds\n"
  printf "---\t---------\t------\t--------\t-------\n"
} >"$RESULTS_TSV"

all_ok=1
total_elapsed=0

for ((idx=0; idx<TOTAL_BENCHMARKS; idx++)); do
  benchmark_name="${BENCHMARK_NAMES[$idx]}"
  status_value="${STATUS[$idx]:-missing}"
  seconds_value="${DURATION_SECONDS[$idx]:-0}"
  total_elapsed=$((total_elapsed + seconds_value))

  if [[ "$status_value" != "ok" ]]; then
    all_ok=0
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$((idx + 1))" \
    "$benchmark_name" \
    "$status_value" \
    "$(format_duration "$seconds_value")" \
    "$seconds_value" >>"$RESULTS_TSV"
done

if command -v column >/dev/null 2>&1; then
  column -t -s $'\t' "$RESULTS_TSV"
else
  cat "$RESULTS_TSV"
fi

echo
printf "Total measured compile time: %s\n" "$(format_duration "$total_elapsed")"

if [[ "$all_ok" -eq 1 ]]; then
  echo "Overall result: SUCCESS"
  exit 0
fi

echo "Overall result: COMPLETED WITH FAILURES"
echo "Note: each failed benchmark's log was printed as an excerpt during execution."
exit 1
