"""Repository size budget: fail when tracked content grows past the agreed limits.

Counts the files git tracks (or would track: tracked + untracked-not-ignored), so
local-only outputs in review/ and art_src/generated/ never count. Audio is
excluded from the per-file limit (music stems are legitimately large) but still
counts toward the total.

Usage:
    python3 tools/art/review/repo_budget.py                 # default 60 MB / 3 MB
    python3 tools/art/review/repo_budget.py --total-mb 60 --file-mb 3 --top 15
Exit code 1 when a budget is exceeded.
"""
from __future__ import annotations

import argparse
import logging
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
AUDIO_EXT = {".ogg", ".wav", ".mp3", ".flac", ".opus"}
log = logging.getLogger("repo_budget")


def tracked_files(root: Path) -> list[Path]:
    """Files git tracks plus untracked files that are not ignored (i.e. would be committed)."""
    try:
        out = subprocess.run(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd=root, check=True, capture_output=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        log.error("git unavailable (%s); cannot measure the repo", exc)
        raise SystemExit(2)
    files = [root / p for p in out.decode("utf-8", "replace").split("\0") if p]
    return [f for f in files if f.is_file()]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--total-mb", type=float, default=60.0)
    ap.add_argument("--file-mb", type=float, default=3.0)
    ap.add_argument("--top", type=int, default=10, help="list the N biggest directories")
    ap.add_argument("--root", type=Path, default=ROOT)
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")

    files = tracked_files(args.root)
    total = 0
    per_dir: dict[str, int] = defaultdict(int)
    too_big: list[tuple[int, Path]] = []
    for f in files:
        size = f.stat().st_size
        total += size
        rel = f.relative_to(args.root)
        per_dir["/".join(rel.parts[:2]) if len(rel.parts) > 2 else rel.parts[0]] += size
        if f.suffix.lower() not in AUDIO_EXT and size > args.file_mb * 1024 * 1024:
            too_big.append((size, rel))
    mb = total / 1024 / 1024
    log.info("tracked: %d files, %.1f MB (budget %.0f MB)", len(files), mb, args.total_mb)
    for d, s in sorted(per_dir.items(), key=lambda kv: -kv[1])[: args.top]:
        log.info("  %7.2f MB  %s", s / 1024 / 1024, d)
    ok = True
    if mb > args.total_mb:
        log.error("REPO BUDGET EXCEEDED: %.1f MB > %.0f MB", mb, args.total_mb)
        ok = False
    for size, rel in sorted(too_big, reverse=True):
        log.error("FILE BUDGET EXCEEDED: %s is %.2f MB > %.1f MB", rel, size / 1024 / 1024, args.file_mb)
        ok = False
    print("REPO_BUDGET", "OK" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
