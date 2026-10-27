"""Enforce the contributor contract's 60% Flutter line-coverage gate."""
from pathlib import Path
import sys


def main():
    report = Path(sys.argv[1] if len(sys.argv) > 1 else "coverage/lcov.info")
    rows = report.read_text(encoding="utf-8").splitlines()
    found = sum(int(row[3:]) for row in rows if row.startswith("LF:"))
    hit = sum(int(row[3:]) for row in rows if row.startswith("LH:"))
    percentage = 100 * hit / found if found else 0
    print(f"Flutter line coverage: {hit}/{found} = {percentage:.2f}% (minimum 60%)")
    raise SystemExit(0 if percentage >= 60 else 1)


if __name__ == "__main__":
    main()
