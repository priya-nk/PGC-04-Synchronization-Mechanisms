#!/usr/bin/env bash
# benchmark.sh - Run the compare_sync benchmark several times and summarize.
#
# Usage:
#   ./benchmark.sh [RUNS]
#
# Examples:
#   ./benchmark.sh        # 5 runs (default)
#   ./benchmark.sh 10     # 10 runs
#
# Output (in ./results/):
#   run_<timestamp>.log       raw output of every run
#   run_<timestamp>.csv       parsed data: run,mechanism,threads,final_count,correctness,time_s
#   summary_<timestamp>.txt   average time per mechanism and thread count

set -euo pipefail

RUNS="${1:-5}"
SRC="compare_sync.c"
BIN="./compare_sync"
OUT_DIR="results"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOG="$OUT_DIR/run_$STAMP.log"
CSV="$OUT_DIR/run_$STAMP.csv"
SUMMARY="$OUT_DIR/summary_$STAMP.txt"

if ! [[ "$RUNS" =~ ^[1-9][0-9]*$ ]]; then
    echo "RUNS must be a positive integer."
    exit 1
fi

if [[ ! -f "$SRC" ]]; then
    echo "Error: $SRC not found in $(pwd)"
    exit 1
fi

mkdir -p "$OUT_DIR"

echo "Compiling $SRC ..."
gcc "$SRC" -fopenmp -o compare_sync

echo "CPU cores available: $(nproc)"
echo "Running $RUNS benchmark run(s) ..."
echo "run,mechanism,threads,final_count,correctness,time_s" > "$CSV"
: > "$LOG"

for ((r = 1; r <= RUNS; r++)); do
    echo "  run $r/$RUNS"
    {
        echo "===== Run $r ====="
        "$BIN"
        echo
    } >> "$LOG"

    # Parse table rows: Mechanism | Threads | Final Count | Correctness | Time
    "$BIN" | awk -F'|' -v run="$r" '
        NF == 5 && $2 ~ /^[ ]*[0-9]+[ ]*$/ {
            for (i = 1; i <= 5; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i)
            printf "%d,%s,%s,%s,%s,%s\n", run, $1, $2, $3, $4, $5
        }' >> "$CSV"
done

# Average time per mechanism and thread count, plus correctness rate
awk -F',' '
    NR == 1 { next }
    {
        key = $2 "," $3
        sum[key] += $6
        cnt[key]++
        if ($5 == "Correct") ok[key]++
        if (!(key in seen)) { seen[key] = 1; order[++n] = key }
    }
    END {
        printf "%-10s | %7s | %12s | %10s\n", "Mechanism", "Threads", "Avg Time (s)", "Correct"
        print "------------------------------------------------------"
        for (i = 1; i <= n; i++) {
            k = order[i]
            split(k, p, ",")
            printf "%-10s | %7s | %12.4f | %4d/%-4d\n", p[1], p[2], sum[k] / cnt[k], ok[k] + 0, cnt[k]
        }
    }' "$CSV" | tee "$SUMMARY"

echo
echo "Saved:"
echo "  $LOG"
echo "  $CSV"
echo "  $SUMMARY"
