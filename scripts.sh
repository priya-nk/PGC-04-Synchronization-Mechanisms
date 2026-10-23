#!/usr/bin/env bash
# scripts.sh - Build and run all synchronization programs.
#
# Usage:
#   ./scripts.sh setup     Install GCC / OpenMP (Ubuntu) and verify
#   ./scripts.sh compile   Compile all programs
#   ./scripts.sh run       Run all programs (uses THREADS if set)
#   ./scripts.sh clean     Remove compiled binaries
#   ./scripts.sh all       compile + run (default)
#
# Example:
#   THREADS=4 ./scripts.sh run

set -euo pipefail

OMP_PROGRAMS=(race critical atomic barrier compare_sync)
PTHREAD_PROGRAMS=(semaphore)

setup() {
    echo "== Installing build tools =="
    sudo apt update
    sudo apt install build-essential -y
    gcc --version | head -n 1
    echo '#include <omp.h>' | gcc -E -fopenmp -xc - > /dev/null && echo "OpenMP OK"
}

compile() {
    echo "== Compiling =="
    for p in "${OMP_PROGRAMS[@]}"; do
        if [[ ! -f "$p.c" ]]; then
            echo "Skipping $p (missing $p.c)"
            continue
        fi
        echo "gcc $p.c -fopenmp -o $p"
        gcc "$p.c" -fopenmp -o "$p"
    done
    for p in "${PTHREAD_PROGRAMS[@]}"; do
        if [[ ! -f "$p.c" ]]; then
            echo "Skipping $p (missing $p.c)"
            continue
        fi
        echo "gcc $p.c -pthread -o $p"
        gcc "$p.c" -pthread -o "$p"
    done
    echo "Compilation finished."
}

run() {
    echo "== Running =="
    if [[ -n "${THREADS:-}" ]]; then
        export OMP_NUM_THREADS="$THREADS"
        echo "Using OMP_NUM_THREADS=$OMP_NUM_THREADS"
    fi
    for p in "${OMP_PROGRAMS[@]}" "${PTHREAD_PROGRAMS[@]}"; do
        if [[ -x "./$p" ]]; then
            echo
            echo "--- ./$p ---"
            "./$p"
        else
            echo "Skipping $p (not compiled)"
        fi
    done
}

clean() {
    echo "== Cleaning =="
    for p in "${OMP_PROGRAMS[@]}" "${PTHREAD_PROGRAMS[@]}"; do
        rm -f "$p"
    done
    echo "Removed binaries."
}

case "${1:-all}" in
    setup)   setup ;;
    compile) compile ;;
    run)     run ;;
    clean)   clean ;;
    all)     compile; run ;;
    *)
        echo "Usage: $0 {setup|compile|run|clean|all}"
        exit 1
        ;;
esac
