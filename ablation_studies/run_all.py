"""Run every ablation benchmark in order. Output is suitable for tee'ing:

    python3 ablation_studies/run_all.py | tee report/screenshots/ablations.txt

Each script is self-contained; this orchestrator just imports and calls
their main() functions so you get one continuous transcript with one
header per study.
"""
from __future__ import annotations

import importlib
import sys
from pathlib import Path

# Make the sibling modules importable when run from project root.
sys.path.insert(0, str(Path(__file__).resolve().parent))

MODULES = [
    "01_concurrency",
    "02_indexing",
    "03_n_plus_one",
    "04_top_booking",
]


def main():
    print("Running all ablation benchmarks. This takes ~30-60 seconds total.")
    print("(Most of it is the 50k-row insert in #2.)\n")
    for name in MODULES:
        mod = importlib.import_module(name)
        mod.main()
    print("\nAll ablations complete.")


if __name__ == "__main__":
    main()
