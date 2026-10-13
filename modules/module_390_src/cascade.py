#!/usr/bin/env python3
"""Cascade — окремий ротатор snapshot (не чіпає src.py)."""
import hashlib, io, json, os, sys, tarfile, time
from pathlib import Path

SRC = Path.home() / ".cybra_src"
SNAPS = SRC / "snapshots"

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def dirs():
    return {
        "recent": SNAPS,
        "hist_l1": SRC / "history_l1",
        "hist_l2": SRC / "history_l2",
        "hist_l3": SRC / "history_l3",
        "hist_l4": SRC / "history_l4",
    }

def combine_batch(batch, out_dir, level=1):
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%d_%H%M%S")
    out = out_dir / f"hist_L{level}_{ts}.tar.gz"
    tmp = out.with_suffix(".tar.gz.tmp")
    try:
        with tarfile.open(tmp, "w:gz", compresslevel=9) as tar:
            for b in batch:
                tar.add(b, arcname=f"batches/{b.name}")
                meta = json.dumps({"source": b.name, "size": b.stat().st_size}).encode()
                info = tarfile.TarInfo(name=f"batches/{b.name}.meta.json")
                info.size = len(meta)
                tar.addfile(info, io.BytesIO(meta))
        os.replace(tmp, out)
        out.with_suffix(".json").write_text(json.dumps({
            "file": out.name, "size": out.stat().st_size, "level": level,
            "combined": len(batch), "sources": [b.name for b in batch],
            "at": _now(),
        }, indent=2))
        return out
    except Exception as e:
        print(f"  ✗ combine: {e}")
        return None

def rotate():
    d = dirs()
    for p in d.values(): p.mkdir(parents=True, exist_ok=True)

    # Recent → 5
    for level_dir, level in [("hist_l1", 1), ("hist_l2", 2), ("hist_l3", 3), ("hist_l4", 4)]:
        src_dir = SNAPS if level == 1 else d[f"hist_l{level-1}"]
        pattern = "snap_*.tar.gz" if level == 1 else "hist_*.tar.gz"
        files = sorted(src_dir.glob(pattern), key=lambda p: p.stat().st_mtime, reverse=True)
        while len(files) > 5:
            batch = files[-5:]
            combine_batch(batch, d[level_dir], level=level)
            for b in batch:
                b.unlink(missing_ok=True)
                b.with_suffix(".json").unlink(missing_ok=True)
            files = sorted(src_dir.glob(pattern), key=lambda p: p.stat().st_mtime, reverse=True)

def status():
    d = dirs()
    out = {}
    for name, p in d.items():
        if not p.exists(): p.mkdir(parents=True, exist_ok=True)
        files = sorted(p.glob("*.tar.gz"), key=lambda x: x.stat().st_mtime, reverse=True)
        out[name] = {
            "count": len(files),
            "mb": sum(f.stat().st_size for f in files) // (1024*1024)
        }
    return out

def force():
    """Примусово: recent > 5 → каскад."""
    rotate()

if __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; B='\033[36m'; BOLD='\033[1m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "rotate" or cmd == "force":
        rotate()
        print(f"  {G}✓{N} cascade виконано")

    elif cmd == "status":
        s = status()
        print(f"\n  {B}{BOLD}Cascade Status{N}\n")
        labels = {
            "recent": "Recent (макс 5)",
            "hist_l1": "L1 · 5 recent → 1",
            "hist_l2": "L2 · 5 L1 → 1",
            "hist_l3": "L3 · 5 L2 → 1",
            "hist_l4": "L4 · 5 L3 → 1",
        }
        for name, info in s.items():
            col = G if info["count"] <= 5 else R
            mark = "✓" if info["count"] <= 5 else "✗"
            print(f"  {col}{mark}{N} {labels.get(name, name):28s}  {info['count']:>2}/5  {info['mb']} MB")
        print()

    elif cmd == "json":
        print(json.dumps(status(), indent=2))
