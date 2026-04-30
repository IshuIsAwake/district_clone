"""Shared helpers for the ablation benchmark scripts.

Every script in this folder loads .env from the project root, opens a
mysql-connector connection against zomato_district, and prints results as
plain ASCII tables so screenshots are clean.
"""
from __future__ import annotations

import os
import statistics
import time
from contextlib import contextmanager
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", "3306")),
    "user":     os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME", "zomato_district"),
    "autocommit": False,
}


def connect(autocommit: bool = False):
    cfg = dict(DB_CONFIG)
    cfg["autocommit"] = autocommit
    return mysql.connector.connect(**cfg)


@contextmanager
def cursor(autocommit: bool = False, dictionary: bool = False):
    cn = connect(autocommit=autocommit)
    try:
        cur = cn.cursor(dictionary=dictionary)
        yield cn, cur
        cn.commit()
    finally:
        cur.close()
        cn.close()


def banner(title: str, char: str = "=") -> None:
    bar = char * 78
    print(f"\n{bar}\n{title}\n{bar}")


def section(title: str) -> None:
    print(f"\n--- {title} ---")


def time_query(cur, sql: str, params=None, repeats: int = 5) -> dict:
    """Run sql `repeats` times, return min / median / mean (ms) and row count."""
    timings = []
    rows = 0
    for _ in range(repeats):
        t0 = time.perf_counter()
        cur.execute(sql, params or ())
        result = cur.fetchall()
        timings.append((time.perf_counter() - t0) * 1000.0)
        rows = len(result)
    return {
        "rows":    rows,
        "min_ms":  min(timings),
        "med_ms":  statistics.median(timings),
        "mean_ms": statistics.mean(timings),
        "max_ms":  max(timings),
    }


def explain(cur, sql: str, params=None) -> list[dict]:
    cur.execute("EXPLAIN " + sql, params or ())
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, row)) for row in cur.fetchall()]


def print_table(headers: list[str], rows: list[list]) -> None:
    """Tiny ASCII table printer - no third-party dep needed."""
    cols = list(zip(headers, *rows))
    widths = [max(len(str(v)) for v in col) for col in cols]
    fmt = " | ".join(f"{{:<{w}}}" for w in widths)
    sep = "-+-".join("-" * w for w in widths)
    print(fmt.format(*headers))
    print(sep)
    for r in rows:
        print(fmt.format(*[str(v) for v in r]))


def print_explain(plan: list[dict]) -> None:
    if not plan:
        print("(empty plan)")
        return
    headers = list(plan[0].keys())
    rows = [[r.get(h, "") if r.get(h) is not None else "NULL" for h in headers]
            for r in plan]
    print_table(headers, rows)
