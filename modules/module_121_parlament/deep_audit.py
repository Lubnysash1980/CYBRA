#!/usr/bin/env python3
"""Deep audit: що БУЛО ЗАДУМАНО vs ЩО Є. Знаходить пропущені модулі,
TUI-пункти, README, тести, конфіги."""
import os, re, json, subprocess
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
TUI = H / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
PUB_TUI = H / "public/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

# ─── Еталон: що має бути у системі
SPEC = {
    "modules_expected": [
        # (id, назва, критичність)
        ("1",  "Створити контракт",       "critical"),
        ("2",  "Список контрактів",       "critical"),
        ("11", "INVOICE",                 "critical"),
        ("15", "PII mask",                "warn"),
        ("18", "Refund",                  "warn"),
        ("30", "Preflight",               "warn"),
        ("31", "Self-heal",               "warn"),
        ("40", "AI аналіз",               "warn"),
        ("50", "Address book",            "warn"),
        ("53", "QR-код",                  "warn"),
        ("65", "Dispute",                 "warn"),
        ("80", "Guardian",                "warn"),
        ("92", "Autosave",                "warn"),
        ("100","Node manager",            "warn"),
        ("108","MetaMask Sign",           "critical"),
        ("109","MetaMask Verify",         "critical"),
        ("114","AutoNode",                "warn"),
        ("119","QR Sign 7 рівнів",        "warn"),
        ("120","AI Guardian",             "critical"),
        ("121","Parliament",              "critical"),
    ],
    "files_expected": [
        ("config/metamask.env",           "critical"),
        ("config/telegram.env",           "warn"),
        ("modules/module_121_parlament/data/members.json", "critical"),
        ("modules/module_121_parlament/data/rules.json",   "warn"),
        ("docs/ROADMAP.md",               "warn"),
    ],
    "integrations_expected": [
        ("108 ↔ 121 (hook великих контрактів)", "warn"),
        ("119 ↔ 121 (QR рівня 8 з парламентом)", "warn"),
        ("120 ↔ 121 (guardian перевіряє hash-chain)", "warn"),
        ("114 ↔ 121 (AutoNode тримає BSC)", "warn"),
    ],
    "tests_expected": [
        ("tests/test_108_sign.sh",  "warn"),
        ("tests/test_119_qr.sh",    "warn"),
        ("tests/test_121_parliament.sh", "warn"),
    ],
}

def _exists(p): return Path(p).exists() if not str(p).startswith("/") else Path(p).exists()

def _tui_handlers():
    if not TUI.exists(): return set()
    src = TUI.read_text()
    return set(re.findall(r'^\s*(\d+)\)\s', src, re.M))

def _modules_on_disk():
    if not M.exists(): return set()
    out = set()
    for p in M.glob("module_*"):
        m = re.match(r'module_(\d+)_', p.name)
        if m: out.add(m.group(1))
    return out

def run():
    issues = []
    # 1) модулі: чи є на диску
    on_disk = _modules_on_disk()
    handlers = _tui_handlers()
    for mid, name, crit in SPEC["modules_expected"]:
        if mid not in on_disk:
            issues.append({
                "kind": "missing_module", "id": f"spec.mod.{mid}",
                "level": crit, "detail": f"Модуль {mid} ({name}) відсутній"})
        elif mid not in handlers:
            issues.append({
                "kind": "no_tui_handler", "id": f"spec.tui.{mid}",
                "level": "warn", "detail": f"Модуль {mid} є, але немає TUI-пункту"})

    # 2) модулі на диску, яких нема у spec — теж цікаво
    spec_ids = {m[0] for m in SPEC["modules_expected"]}
    extra = sorted(on_disk - spec_ids)
    if extra:
        issues.append({
            "kind": "extra_modules", "id": "spec.extra",
            "level": "info", "detail": f"Не в spec: {','.join(extra[:15])}"})

    # 3) файли
    for f, lvl in SPEC["files_expected"]:
        p = H / f
        if not p.exists():
            issues.append({
                "kind": "missing_file", "id": f"spec.file.{f}",
                "level": lvl, "detail": f"Файл {f} відсутній"})

    # 4) інтеграції (перевіряємо згадки у коді)
    for desc, lvl in SPEC["integrations_expected"]:
        # груба перевірка — шукаємо згадки обох модулів у модулі 121
        key = re.findall(r'(\d+)', desc.split()[0])
        if not key: continue
        mid = key[0]
        found = False
        for f in (M/"module_121_parlament").glob("*.py"):
            try:
                txt = f.read_text()
                if f"module_{mid}_" in txt or f"'{mid}'" in txt:
                    found = True; break
            except Exception: pass
        if not found:
            issues.append({
                "kind": "missing_integration", "id": f"spec.int.{mid}",
                "level": lvl, "detail": desc})

    # 5) тести
    for t, lvl in SPEC["tests_expected"]:
        if not (H / t).exists():
            issues.append({
                "kind": "missing_test", "id": f"spec.test.{t}",
                "level": lvl, "detail": f"Немає тесту: {t}"})

    return issues

if __name__ == "__main__":
    iss = run()
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
    if not iss:
        print(f"\n  {G}✅ spec = actual — усе на місці{N}\n")
    else:
        crit = [i for i in iss if i["level"]=="critical"]
        warn = [i for i in iss if i["level"]=="warn"]
        info = [i for i in iss if i["level"]=="info"]
        print(f"\n  {B}═══ Deep Audit ═══{N}")
        print(f"  🚨 {len(crit)}  🟡 {len(warn)}  ℹ {len(info)}\n")
        for i in crit+warn+info:
            ic = {"critical":"🚨","warn":"🟡","info":"ℹ"}.get(i["level"],"·")
            print(f"  {ic} [{i['kind']:18s}] {i['detail']}")
        print()
