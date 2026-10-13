#!/usr/bin/env python3
"""Генерує і оновлює roadmap: config/roadmap.json + docs/ROADMAP.md"""
import json, time, sys
from pathlib import Path

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
CFG = H / "config" / "roadmap.json"
MD = H / "docs" / "ROADMAP.md"
CFG.parent.mkdir(parents=True, exist_ok=True)
MD.parent.mkdir(parents=True, exist_ok=True)

sys.path.insert(0, str(D))

def _load_prev():
    if CFG.exists():
        try: return json.loads(CFG.read_text())
        except Exception: pass
    return {"items": {}, "generated": None}

def _save(cfg):
    cfg["generated"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    tmp = str(CFG)+".tmp"
    Path(tmp).write_text(json.dumps(cfg, indent=2, ensure_ascii=False))
    CFG.replace(tmp)

def refresh():
    import gap
    a = gap.analyze()
    prev = _load_prev()
    items = prev.get("items", {})

    # апдейт статусів
    for g in a["gaps"]:
        tid = g["id"]
        old = items.get(tid, {})
        items[tid] = {
            "id": tid, "name": g["name"], "cat": g["cat"], "prio": g["prio"],
            "desc": g["desc"], "deps": g["deps"], "missing_deps": g["missing_deps"],
            "ready": g["ready"],
            "status": old.get("status", "planned"),
            "first_seen": old.get("first_seen", time.strftime("%Y-%m-%d")),
            "last_seen": time.strftime("%Y-%m-%d"),
        }
    # закриваємо ті що вже є
    for tid in list(items.keys()):
        if tid not in {g["id"] for g in a["gaps"]}:
            items[tid]["status"] = "done"
            items[tid]["done_at"] = time.strftime("%Y-%m-%d")

    cfg = {
        "items": items,
        "hotspots": a["hotspots"],
        "action_failures": a["action_failures"],
        "existing_modules": a["existing_modules"],
    }
    _save(cfg)
    _write_md(cfg)
    return cfg

def _write_md(cfg):
    items = cfg["items"]
    by_status = {"planned": [], "wip": [], "done": [], "blocked": []}
    for i in items.values():
        by_status.setdefault(i["status"], []).append(i)

    G=''; N=''
    lines = []
    lines.append("# CYBRA · ROADMAP")
    lines.append("")
    lines.append(f"_Оновлено: {cfg.get('generated','—')}_")
    lines.append("")
    lines.append(f"**Модулів зараз:** {cfg.get('existing_modules',0)}  ·  "
                 f"**Заплановано:** {len(by_status['planned'])}  ·  "
                 f"**Виконано:** {len(by_status['done'])}")
    lines.append("")

    def sec(title, arr, emoji):
        if not arr: return
        lines.append(f"## {emoji} {title}")
        lines.append("")
        arr.sort(key=lambda x: ({"high":0,"med":1,"low":2}.get(x.get("prio"),9), x["id"]))
        for x in arr:
            check = "x" if x["status"]=="done" else " "
            p = x.get("prio","?")
            lines.append(f"- [{check}] **{x['id']} · {x['name']}**  "
                         f"`{p}` · _{x.get('cat','?')}_  ")
            lines.append(f"  {x.get('desc','')}")
            if x.get("missing_deps"):
                lines.append(f"  > залежить від: {', '.join(x['missing_deps'])}")
        lines.append("")

    sec("Планується", by_status["planned"], "📋")
    sec("В роботі", by_status["wip"], "⚙️")
    sec("Заблоковано", by_status["blocked"], "🚫")
    sec("Виконано", by_status["done"], "✅")

    # hotspots
    if cfg.get("hotspots"):
        lines.append("## 🔥 Найчастіші проблеми")
        lines.append("")
        for k, v in list(cfg["hotspots"].items())[:10]:
            lines.append(f"- `{k}` — {v}×")
        lines.append("")

    if cfg.get("action_failures"):
        lines.append("## ⚠️ Дії що не спрацьовують")
        lines.append("")
        for k, v in list(cfg["action_failures"].items())[:10]:
            lines.append(f"- `{k}` — {v}×")
        lines.append("")

    MD.write_text("\n".join(lines))

def set_status(tid, status):
    cfg = _load_prev()
    if tid not in cfg.get("items", {}):
        return False, f"немає id {tid}"
    cfg["items"][tid]["status"] = status
    cfg["items"][tid]["updated"] = time.strftime("%Y-%m-%d")
    _save(cfg); _write_md(cfg)
    return True, f"{tid} → {status}"

def add_custom(tid, name, cat, prio, desc, deps=None):
    cfg = _load_prev()
    cfg.setdefault("items", {})[tid] = {
        "id": tid, "name": name, "cat": cat, "prio": prio,
        "desc": desc, "deps": deps or [], "missing_deps": [],
        "ready": True, "status": "planned",
        "first_seen": time.strftime("%Y-%m-%d"),
        "last_seen": time.strftime("%Y-%m-%d"),
        "custom": True,
    }
    _save(cfg); _write_md(cfg)
    return True, f"додано {tid}"

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "refresh"
    if cmd == "refresh":
        cfg = refresh()
        print(f"  ✓ roadmap: {len(cfg['items'])} пунктів")
        print(f"    JSON: {CFG}")
        print(f"    MD:   {MD}")
    elif cmd == "status":
        if len(sys.argv) < 4: print("usage: roadmap.py status <id> <planned|wip|done|blocked>"); sys.exit(1)
        ok, msg = set_status(sys.argv[2], sys.argv[3])
        print(("✓ " if ok else "✗ ")+msg)
    elif cmd == "add":
        if len(sys.argv) < 7: print("usage: roadmap.py add <id> <name> <cat> <prio> <desc>"); sys.exit(1)
        ok, msg = add_custom(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
        print(("✓ " if ok else "✗ ")+msg)
    elif cmd == "show":
        if MD.exists(): print(MD.read_text()[:4000])
        else: print("(ROADMAP.md не створено)")
