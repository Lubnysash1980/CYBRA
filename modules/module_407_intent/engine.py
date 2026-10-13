#!/usr/bin/env python3
"""Intent Engine — розуміє команди природною мовою (uk/ru/en/he).
Якщо не знає — записує у unknown і пропонує додати.
"""
import json, sys, time
from pathlib import Path

D = Path(__file__).resolve().parent
DB = D / "data" / "intents.json"

def _load():
    try: return json.loads(DB.read_text())
    except Exception: return {"intents": [], "learned": [], "unknown": []}

def _save(d): DB.write_text(json.dumps(d, indent=2, ensure_ascii=False))

def match(text):
    """Знайти намір."""
    d = _load()
    text_l = text.lower().strip()
    # 1. Точні ключові слова
    for it in d["intents"] + d["learned"]:
        for kw in it["keywords"]:
            if kw.lower() in text_l:
                return it, "keyword"
    # 2. Часткове співпадіння (≥60% слів)
    text_words = set(text_l.split())
    best, score = None, 0
    for it in d["intents"] + d["learned"]:
        for kw in it["keywords"]:
            kw_words = set(kw.lower().split())
            if not kw_words: continue
            overlap = len(text_words & kw_words) / len(kw_words)
            if overlap > score:
                best, score = it, overlap
    if score >= 0.6: return best, "fuzzy"
    return None, None

def learn(text, action, intent_id=None):
    """Додати новий намір."""
    d = _load()
    if not intent_id:
        intent_id = f"custom_{int(time.time())}"
    d["learned"].append({
        "id": intent_id, "keywords": [text], "action": action,
        "learned_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    })
    # прибрати з unknown
    d["unknown"] = [u for u in d["unknown"] if u.get("text") != text]
    _save(d)
    return intent_id

def log_unknown(text):
    """Записати невідомий намір."""
    d = _load()
    d["unknown"].append({
        "text": text,
        "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "count": 1,
    })
    _save(d)

def suggest(text):
    """Пропозиція що робити з невідомим наміром."""
    return {
        "text": text,
        "suggestion": "Додати через: cybra → 407 → learn",
        "template": {"keywords": [text], "action": "cybra_open <NNN>"},
    }

if __name__ == "__main__":
    import sys
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"

    if cmd == "list":
        d = _load()
        print(f"\n  {B}Наміри ({len(d['intents'])} вбудованих + {len(d['learned'])} вивчених){N}\n")
        for it in d["intents"]:
            print(f"  · {it['id']:20s} → {it['action']}")
            print(f"    {', '.join(it['keywords'][:4])}")
        if d.get("learned"):
            print(f"\n  {B}Вивчені:{N}")
            for it in d["learned"]:
                print(f"  · {it['id']:20s} → {it['action']}")
                print(f"    {', '.join(it['keywords'])}")
        if d.get("unknown"):
            print(f"\n  {Y}Невідомі ({len(d['unknown'])}):{N}")
            for u in d["unknown"][-5:]:
                print(f"  ? {u['text'][:60]}")

    elif cmd == "match":
        if len(sys.argv) < 3:
            print("usage: engine.py match <text>"); sys.exit(1)
        text = " ".join(sys.argv[2:])
        it, mode = match(text)
        if it:
            print(f"  {G}✓{N} [{mode}] {it['id']} → {it['action']}")
        else:
            print(f"  {R}✗{N} невідомо: {text}")
            log_unknown(text)
            print(f"  {Y}Записано у unknown{N}")

    elif cmd == "learn":
        # engine.py learn "text" "action"
        if len(sys.argv) < 4:
            print("usage: engine.py learn <text> <action>"); sys.exit(1)
        text, action = sys.argv[2], sys.argv[3]
        iid = learn(text, action)
        print(f"  {G}✓{N} вивчено: {iid}")

    elif cmd == "unknown":
        d = _load()
        for u in d.get("unknown", []):
            print(f"  {u['at']}  {u['text']}")

    elif cmd == "json":
        print(json.dumps(_load(), indent=2, ensure_ascii=False))
