#!/usr/bin/env python3
"""Відкат виконаних дій парламенту. Зберігає стан перед кожною дією."""
import json, os, shutil, time, stat, sys
from pathlib import Path

D = Path(__file__).resolve().parent
UNDO = D / "undo"
UNDO.mkdir(exist_ok=True)
SNAP = UNDO / "snapshots.jsonl"

def _rec(entry):
    entry["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(SNAP, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    # ротація
    try:
        lines = SNAP.read_text().splitlines()
        if len(lines) > 500:
            SNAP.write_text("\n".join(lines[-300:]) + "\n")
    except Exception: pass

def snapshot_before(action_id, target):
    """Перед дією — зберігаємо стан для можливого відкату."""
    s = {"action": action_id, "target": target, "kind": "unknown"}
    try:
        if target and Path(target).exists():
            p = Path(target)
            s["kind"] = "file"
            s["mode"] = stat.S_IMODE(p.stat().st_mode)
            s["size"] = p.stat().st_size
            # бекап вмісту
            bak = UNDO / f"{action_id}_{int(time.time())}.bak"
            shutil.copy2(p, bak)
            s["backup"] = str(bak)
        else:
            s["kind"] = "absent"
    except Exception as e:
        s["error"] = str(e)
    _rec(s)
    return s

def undo_last(n=1):
    """Відкочує останні n дій."""
    if not SNAP.exists():
        return [], "немає знімків"
    lines = [l for l in SNAP.read_text().splitlines() if l.strip()]
    undone, failed = [], []
    count = 0
    for line in reversed(lines):
        if count >= n: break
        try: s = json.loads(line)
        except Exception: continue
        if s.get("undone"): continue
        ok, msg = _do_undo(s)
        s["undone"] = True; s["undo_ok"] = ok; s["undo_msg"] = msg
        _rec(s)
        (undone if ok else failed).append({"action": s["action"], "msg": msg})
        count += 1
    return undone, failed

def _do_undo(s):
    kind = s.get("kind")
    target = s.get("target", "")
    if kind == "file" and s.get("backup") and Path(s["backup"]).exists():
        try:
            shutil.copy2(s["backup"], target)
            return True, f"відновлено з {Path(s['backup']).name}"
        except Exception as e:
            return False, f"copy: {e}"
    if kind == "absent":
        # файл не існував → видаляємо якщо створився
        if target and Path(target).exists():
            try: Path(target).unlink(); return True, f"видалено {target}"
            except Exception as e: return False, f"unlink: {e}"
        return True, "нічого робити"
    return False, "невідомий тип знімка"

def list_snapshots(n=10):
    if not SNAP.exists(): return []
    out = []
    for line in SNAP.read_text().splitlines()[-n:]:
        try: out.append(json.loads(line))
        except Exception: pass
    return out

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for s in list_snapshots(20):
            mark = "↩" if s.get("undone") else "·"
            print(f"  {mark} {s.get('ts','?')}  {s.get('action','?')}  {s.get('target','')[:40]}")
    elif cmd == "last":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 1
        u, f = undo_last(n)
        print(f"  ✓ {len(u)}  ✗ {len(f)}")
        for x in u: print(f"    ↩ {x['action']}: {x['msg']}")
        for x in f: print(f"    ✗ {x['action']}: {x['msg']}")
