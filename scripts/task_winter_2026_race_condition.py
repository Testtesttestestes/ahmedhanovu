#!/usr/bin/env python3
"""Reproduce and explain a shared-counter race, then compare a mutex fix."""
from __future__ import annotations

import argparse
import json
import threading
import time
from pathlib import Path


def run_once(workers: int, increments: int, locked: bool) -> tuple[int, float]:
    counter = 0
    mutex = threading.Lock()

    def worker() -> None:
        nonlocal counter
        for index in range(increments):
            if locked:
                with mutex:
                    counter += 1
            else:
                current = counter
                if index % 8 == 0:
                    time.sleep(0)
                counter = current + 1

    started = time.perf_counter()
    threads = [threading.Thread(target=worker, name=f"worker-{n}") for n in range(workers)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    return counter, time.perf_counter() - started


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workers", type=int, default=10)
    parser.add_argument("--increments", type=int, default=100_000)
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--output", type=Path, default=Path("reports/winter-2026-task1/results.json"))
    args = parser.parse_args()
    if min(args.workers, args.increments, args.runs) <= 0:
        raise SystemExit("workers, increments and runs must be positive")
    expected = args.workers * args.increments
    unsafe = [run_once(args.workers, args.increments, locked=False) for _ in range(args.runs)]
    safe = [run_once(args.workers, args.increments, locked=True) for _ in range(args.runs)]
    result = {
        "workers": args.workers,
        "increments_per_worker": args.increments,
        "runs": args.runs,
        "expected": expected,
        "unsafe": [{"value": value, "seconds": round(seconds, 6)} for value, seconds in unsafe],
        "mutex": [{"value": value, "seconds": round(seconds, 6)} for value, seconds in safe],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
