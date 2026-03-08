# SwiftPM Compilation Benchmark (7000 Swift Files)

This workspace benchmarks Swift compilation time across 9 Swift Package Manager project shapes, while keeping the total source file count constant (7000 files).

## What Is Implemented

The benchmark matrix is generated under `Benchmarks/`:

1. `Project1_1Target_7000`: 1 target, 7000 files
2. `Project2_2Targets_3500x2`: 2 targets, 3500 files each
3. `Project3_4Targets_1750x4`: 4 targets, 1750 files each
4. `Project4_8Targets_875x8`: 8 targets, 875 files each
5. `Project5_16Targets_Approx438x16`: 16 targets, approx 438 files each
6. `Project6_32Targets_Approx218x32`: 32 targets, approx 218 files each
7. `Project7_64Targets_Approx110x64`: 64 targets, approx 110 files each
8. `Project8_12Targets_Approx583x12`: 12 targets, approx 583 files each
9. `Project9_24Targets_Approx291x24`: 24 targets, approx 291 files each

All projects reuse the same shared source pool from `swift_tasks_7000/`.

For multi-target projects, each target depends on the previous target in a chain, so one `swift build` compiles the full graph.

## Scripts

- `setup_spm_benchmarks.sh`
	Creates or refreshes all 9 benchmark projects from `swift_tasks_7000/`.

- `run_spm_benchmarks.sh`
	Cleans each project and compiles benchmarks one by one, measures compile duration, and prints a tab-separated summary that is aligned for terminal readability.

## Run In A Clean Directory

This section assumes you are in the repository root.

### 1. Ensure the shared 7000-file source pool exists

Required folder:

- `swift_tasks_7000/`

Validate count:

```bash
find swift_tasks_7000 -maxdepth 1 -type f -name 'GeneratedTask*.swift' | wc -l
```

Expected result: `7000`

If this is a fresh clone and `swift_tasks_7000/` is missing, first generate or copy the 7000 files into that folder before continuing.

### 2. Clean previous benchmark output

```bash
rm -rf Benchmarks
```

### 3. Generate all benchmark projects

```bash
./setup_spm_benchmarks.sh
```

This creates all 9 project folders under `Benchmarks/` and distributes files according to each target layout.

## Validate Setup Output

### Validate project directories were created

```bash
find Benchmarks -mindepth 1 -maxdepth 1 -type d | wc -l
```

Expected result: `9`

### Validate each package resolves

```bash
for p in \
	Benchmarks/Project1_1Target_7000 \
	Benchmarks/Project2_2Targets_3500x2 \
	Benchmarks/Project3_4Targets_1750x4 \
	Benchmarks/Project4_8Targets_875x8 \
	Benchmarks/Project5_16Targets_Approx438x16 \
	Benchmarks/Project6_32Targets_Approx218x32 \
	Benchmarks/Project7_64Targets_Approx110x64 \
	Benchmarks/Project8_12Targets_Approx583x12 \
	Benchmarks/Project9_24Targets_Approx291x24
do
	echo "== $p =="
	(cd "$p" && swift package describe >/dev/null && echo OK)
done
```

Expected result: all projects print `OK`.

## Execute The Benchmark

### Full run (default: debug)

```bash
./run_spm_benchmarks.sh
```

Equivalent explicit variant selection:

```bash
./run_spm_benchmarks.sh --build-variant default
```

### Full run in release mode

```bash
./run_spm_benchmarks.sh --configuration release
```

### Run with Swift batch mode enabled

```bash
./run_spm_benchmarks.sh --build-variant batch
./run_spm_benchmarks.sh --configuration release --build-variant batch
```

### Run with Swift batch mode and batch-size limit

Use `--build-variant batch-size-limit` and pass `XX` through `--batch-size-limit`.

```bash
./run_spm_benchmarks.sh --build-variant batch-size-limit --batch-size-limit 75
./run_spm_benchmarks.sh --configuration release --build-variant batch-size-limit --batch-size-limit 100
```

### Run specific benchmark shapes only

Use target counts with `--targets`.

```bash
./run_spm_benchmarks.sh --targets 32
./run_spm_benchmarks.sh --targets 64,24,12,8
./run_spm_benchmarks.sh --targets 64,24,16,12,2 --configuration release
```

Notes:

- Allowed values: `64,32,24,16,12,8,4,2,1`
- Comma-separated values are executed in exactly the order you provide.

Build variant notes:

- `--build-variant` allowed values: `default`, `batch`, `batch-size-limit`
- `--batch-size-limit` is required only with `--build-variant batch-size-limit`
- `--batch-size-limit` must not be used with other build variants

## What The Runner Reports

For each selected benchmark:

1. Clean step (`swift package clean`) is executed and reported.
2. Compile step is timed (`swift build -c <configuration>` plus any selected build-variant flags).
3. On failure, a short error excerpt is shown.

At the end, the script prints:

- Per-benchmark tab-separated rows (`#`, `Benchmark`, `Status`, `Duration`, `Seconds`) with terminal-aligned display when `column` is available
- Total measured compile time
- Overall success or failure result

Duration format example: `02:37 (157s)`

The clean step duration is intentionally not included in measured compile time.
