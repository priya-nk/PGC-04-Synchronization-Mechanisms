# Analyze Synchronization Mechanisms in Parallel Programs

A shared-memory parallel programming experiment that implements and compares common synchronization mechanisms in C using **OpenMP** and **POSIX threads**. It evaluates each mechanism on **correctness**, **execution time**, and **scalability** as the number of threads increases.

## Objective

To implement and study:

- Race Conditions
- Critical sections
- Atomic operations
- Barriers
- Semaphores / locks

and to measure how they behave with 1, 2, 4, and 8 threads.

## Environment

| Component | Details |
|-----------|---------|
| Host virtualization | VMware Workstation Pro |
| Guest OS | Ubuntu 22.04 LTS |
| Compiler | GCC (`build-essential`) |
| Parallel runtime | OpenMP (`libgomp`, bundled with GCC) |
| Threads / semaphores | POSIX Threads (`pthread`, `semaphore.h`) |
| Recommended VM resources | 4+ CPU cores, 2-4 GB RAM, 20 GB disk |


## Directory Structure
```
├── scripts/
│   ├── benchmark.sh
│   └── scripts.sh
├── README.md
├── atomic.c
├── barrier.c
├── compare_sync.c
├── critical.c
├── file_run_results_of_counter.jpeg     # Terminal output of Programs 1-5
├── race.c
├── results.jpeg
└── semaphore.c                          # Terminal output of the compare_sync benchmark
```


## Setup

```bash
sudo apt update
sudo apt install build-essential -y

# Verify GCC and OpenMP
gcc --version
echo '#include <omp.h>' | gcc -E -fopenmp -xc - > /dev/null && echo OpenMP OK
```

Or use the helper script:
``` bash
chmod +x scripts/*.sh
./scripts/scripts.sh setup
```

## Programs

| # | File | Mechanism | Description |
|---|------|-----------|-------------|
| 1 | `race.c` | None | 10,000,000 increments of a shared counter with no protection. Produces wrong, non-repeatable results. |
| 2 | `critical.c` | `#pragma omp critical` | Only one thread at a time executes the increment. Correct but serializes all threads. |
| 3 | `atomic.c` | `#pragma omp atomic` | Uses an indivisible hardware instruction for the increment. Correct and low overhead. |
| 4 | `barrier.c` | `#pragma omp barrier` | All threads print "before barrier", wait for each other, then print "after barrier". |
| 5 | `semaphore.c` | `sem_wait` / `sem_post` | Two pthreads increment a counter 100,000 times each, guarded by a binary semaphore. |
| 6 | `compare_sync.c` | None / Critical / Atomic / Lock | Benchmarks all strategies over 1, 2, 4, 8 threads using `omp_get_wtime()` and verifies correctness. |

## Compile

```bash
gcc race.c         -fopenmp -o race
gcc critical.c     -fopenmp -o critical
gcc atomic.c       -fopenmp -o atomic
gcc barrier.c      -fopenmp -o barrier
gcc semaphore.c    -pthread -o semaphore
gcc compare_sync.c -fopenmp -o compare_sync
```

## Run

```bash
./race
./critical
./atomic
./barrier
./semaphore
./compare_sync
```

To choose the thread count for any OpenMP program:

```bash
OMP_NUM_THREADS=4 ./atomic
# or
export OMP_NUM_THREADS=8
./critical
```

Using the helper scripts
``` bash
chmod +x scripts/*.sh               # one-time: make the scripts executable

./scripts/scripts.sh setup          # install GCC / OpenMP and verify
./scripts/scripts.sh compile        # compile all programs
./scripts/scripts.sh run            # run all programs
./scripts/scripts.sh all            # compile + run (default)
./scripts/scripts.sh clean          # remove compiled binaries

THREADS=4 ./scripts/scripts.sh run  # run everything with 4 threads

./scripts/benchmark.sh              # run compare_sync 5 times and average
./scripts/benchmark.sh 10           # run compare_sync 10 times and average
```


## Results

### Individual programs

| Program | Output | Verdict |
|---------|--------|---------|
| `race` | `Counter=15570075` (expected 10,000,000+ ... varies each run) | Incorrect / non-deterministic |
| `critical` | `Counter=40000000` | Correct |
| `atomic` | `Counter=40000000` | Correct |
| `barrier` | All "before barrier" lines print before any "after barrier" line | Phases synchronized |
| `semaphore` | `Counter=200000` | Correct |

<img width="620" height="413" alt="file_run_results_of_counter" src="https://github.com/user-attachments/assets/ad58db76-5243-4d64-92f6-9e48a35b15a4" />


### Benchmark (`compare_sync`, 10,000,000 increments)
<img width="619" height="572" alt="results" src="https://github.com/user-attachments/assets/60ebb46b-d8ee-4b74-b8bd-de4ba1e093e6" />

Timings vary with machine, VM, and core count.

## Observations

| Mechanism | Correctness | Performance | Scalability |
|-----------|-------------|-------------|-------------|
| None (race) | Incorrect | Fastest (no overhead) | Poor: wrong result, gets worse with more threads |
| Critical | Correct | Slow (serializes threads) | Poor: contention grows with thread count |
| Atomic | Correct | Fast (hardware-level) | Good: low overhead as threads increase |
| Lock (`omp_lock_t`) | Correct | Slow (similar to or worse than critical) | Poor to moderate |
| Barrier | Synchronization only | Waiting overhead | Moderate: limited by slowest thread |
| Semaphore | Correct | Moderate (system-call overhead) | Moderate |

Key takeaways from the measured run:

- **None** is fastest but gives wrong answers as soon as more than one thread is used (lost updates).
- **Critical** and **Lock** are always correct, but their time grows sharply from 1 to 4 threads because threads wait in line.
- **Atomic** stays correct and is far faster than critical/lock at 2+ threads (about 0.18-0.20 s versus 0.35-1.08 s).
- Adding threads does not speed up a heavily contended shared counter; it can make it slower.

## Concepts

- **Race condition**: `counter++` is read, increment, write. If two threads read the same old value, one update is lost.
- **Critical section**: a block only one thread may execute at a time. Simple and general, but a bottleneck.
- **Atomic operation**: a hardware-supported indivisible read-modify-write. Limited to simple operations.
- **Barrier**: a point every thread must reach before any proceeds. Synchronizes phases, does not protect data.
- **Semaphore**: a counter-based OS-level primitive. A binary semaphore acts as a mutex; a counting semaphore can admit N threads.

## Conclusion

Atomic operations offer the best balance of correctness and performance for simple shared-variable updates. Critical sections and locks guarantee correctness but limit scalability. Barriers coordinate phases rather than protect data. Semaphores generalize mutual exclusion at moderate overhead. Unsynchronized access is fastest but unreliable, so the choice of mechanism is a trade-off between strength of guarantee, overhead, and scalability.


