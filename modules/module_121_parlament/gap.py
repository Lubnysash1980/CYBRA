#!/usr/bin/env python3
"""Gap analysis: на основі логів + специфікації радить що робити далі."""
import json, re, sys
from pathlib import Path
from collections import Counter

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
sys.path.insert(0, str(D))
import stream

# ─── Шаблони — що ми знаємо про ідеальну CYBRA
TEMPLATES = [
    # id, назва, категорія, пріоритет, залежності, опис
    ("122", "Contract Validator", "core", "high",
     ["108","119"], "Валідація контрактів ПЕРЕД підписом: суми, умови, строки, адреси"),
    ("123", "Multi-sig Flow", "core", "high",
     ["108","121"], "2-of-3 підпис для контрактів > $10k"),
    ("124", "Time-lock Signing", "core", "med",
     ["108"], "Контракт активний через N годин після підпису"),
    ("125", "On-chain Anchor", "chain", "med",
     ["114","121"], "sha256(protocol) у BSC через AutoNode"),
    ("126", "ZK-proof для CID", "crypto", "low",
     ["119","121"], "Довести CID валідний без розкриття"),
    ("127", "Multi-sig QR", "crypto", "med",
     ["119","121"], "QR з N підписами парламенту"),
    ("128", "Web Dashboard", "ui", "med",
     ["114","121"], "HTTP-панель: підписи, парламент, мережі"),
    ("129", "Voice Interface", "ui", "low",
     [], "Голосові команди через Termux:API"),
    ("130", "Test Suite", "quality", "high",
     ["all"], "Автотести для 108-121"),
    ("131", "KYC Lite", "compliance", "med",
     ["108"], "Перевірка адрес через OFAC/sanctions"),
    ("132", "Compliance Check", "compliance", "low",
     ["108","121"], "GDPR, MiCA перевірки"),
    ("133", "Multi-chain tokens", "chain", "low",
     ["114"], "ERC-20 баланси у watch-адресах"),
    ("134", "Discord Bot", "integrations", "low",
     ["121"], "Альтернатива Telegram для голосування"),
    ("135", "WalletConnect", "integrations", "high",
     ["108","121"], "Голосування без trycloudflare URL"),
    ("136", "Contract Templates", "core", "med",
     ["1","108"], "Шаблони контрактів: NDA, сейл, оренда"),
    ("137", "Escrow Flow", "core", "high",
     ["108","121"], "Ескроу: кошти на контракті до виконання"),
    ("138", "Arbitration Module", "core", "med",
     ["65","121"], "Автоматичний арбітраж на основі правил"),
    ("139", "Reputation On-chain", "chain", "low",
     ["121","114"], "Репутація учасників у BSC"),
    ("140", "Analytics Dashboard", "ui", "med",
     ["121"], "Графіки: активність, гроші, спори"),
]

def _module_exists(mid):
    if not (H/"modules").exists(): return False
    for p in (H/"modules").glob(f"module_{mid}_*"):
        return True
    return False

def _usage_from_log():
    """Скількому модулю які події. З логів."""
    events = stream.read(2000)
    usage = Counter()
    for e in events:
        cat = e.get("cat","?")
        ev = e.get("ev","?")
        usage[cat] += 1
    return usage

def _problem_hotspots():
    """Які check_id найчастіше падають?"""
    events = stream.read(2000)
    c = Counter()
    for e in events:
        if e.get("cat") == "check" and e.get("data",{}).get("status") in ("fail","critical"):
            c[e["ev"]] += 1
    return c

def _action_failures():
    """Які дії не спрацьовують?"""
    events = stream.read(2000)
    c = Counter()
    for e in events:
        if e.get("cat") == "action" and not e.get("data",{}).get("ok"):
            c[e["ev"]] += 1
    return c

def analyze():
    """Повертає повний аналіз: gaps, hotspots, рекомендації."""
    existing_ids = set()
    if (H/"modules").exists():
        for p in (H/"modules").glob("module_*"):
            m = re.match(r'module_(\d+)_', p.name)
            if m: existing_ids.add(m.group(1))

    gaps = []
    for tid, tname, cat, prio, deps, desc in TEMPLATES:
        if tid in existing_ids: continue
        missing_deps = [d for d in deps if d != "all" and d not in existing_ids]
        gaps.append({
            "id": tid, "name": tname, "cat": cat, "prio": prio,
            "desc": desc, "deps": deps, "missing_deps": missing_deps,
            "ready": len(missing_deps) == 0,
        })

    # сортуємо: спершу ready+high
    pr_w = {"high":0, "med":1, "low":2}
    gaps.sort(key=lambda g: (not g["ready"], pr_w.get(g["prio"],9), g["id"]))

    return {
        "gaps": gaps,
        "ready_count": sum(1 for g in gaps if g["ready"]),
        "hotspots": dict(_problem_hotspots().most_common(10)),
        "action_failures": dict(_action_failures().most_common(10)),
        "usage": dict(_usage_from_log()),
        "existing_modules": len(existing_ids),
    }

def print_report(a):
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; DIM='\033[2m'; N='\033[0m'
    print(f"\n  {B}═══ GAP ANALYSIS ═══{N}")
    print(f"  Модулів зараз: {a['existing_modules']}")
    print(f"  Прогалин: {len(a['gaps'])}, з них готові ({G}ready{N}): {a['ready_count']}\n")

    print(f"  {B}▸ Топ пріоритет (ready до впровадження):{N}")
    for g in [g for g in a["gaps"] if g["ready"]][:8]:
        c = {"high":R, "med":Y, "low":G}.get(g["prio"], "")
        print(f"    {c}[{g['prio']:4s}]{N} {g['id']} {g['name']:26s} "
              f"{DIM}{g['desc'][:45]}{N}")

    if a["hotspots"]:
        print(f"\n  {B}▸ Найчастіші проблеми (з логів):{N}")
        for k, v in a["hotspots"].items():
            print(f"    {R}{v:3d}×{N}  {k}")

    if a["action_failures"]:
        print(f"\n  {B}▸ Дії які не спрацьовують:{N}")
        for k, v in a["action_failures"].items():
            print(f"    {Y}{v:3d}×{N}  {k}")

    print(f"\n  {DIM}Повний план → config/roadmap.json → docs/ROADMAP.md{N}")
    print()

if __name__ == "__main__":
    a = analyze()
    if len(sys.argv) > 1 and sys.argv[1] == "json":
        print(json.dumps(a, indent=2, ensure_ascii=False))
    else:
        print_report(a)
