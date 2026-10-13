#!/usr/bin/env python3
"""Глобальна пам'ять опцій. Читають усі модулі."""
import json, os, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
CFG = H / "config" / "options.json"

DEFAULTS = {
    # мережа
    "network.current":            "bsc_testnet",
    "network.auto_prompt_switch": True,

    # підпис
    "sign.require_validation":    True,
    "sign.require_kyc":           True,
    "sign.confirm_above_bnb":     1.0,

    # парламент
    "parliament.quorum_percent":  60,
    "parliament.approval_percent":51,
    "parliament.threshold_bnb":   1.0,

    # autonoде
    "autonode.poll_active_sec":   3,
    "autonode.poll_idle_sec":     30,
    "autonode.watch_interval_sec":15,

    # guardian
    "guardian.auto_fix_safe":     True,
    "guardian.interval_sec":      900,

    # нотифікації
    "notify.telegram":            False,
    "notify.discord":             False,
    "notify.termux":              True,

    # escrow / timelock
    "escrow.default_dispute_sec": 3600,
    "escrow.use_solidity":        False,   # поки не задеплоєно
    "timelock.use_solidity":      False,

    # UI
    "ui.theme":                   "dark",
    "ui.language":                "uk",

    # режим
    "mode.safe":                  True,     # блокує mainnet операції без підтвердження
    "mode.testnet_preferred":     True,     # дефолт на testnet якщо є
}

def _load():
    if not CFG.exists():
        _save(DEFAULTS)
        return dict(DEFAULTS)
    try:
        d = json.loads(CFG.read_text())
        # merge з defaults
        out = dict(DEFAULTS)
        out.update(d)
        return out
    except Exception:
        return dict(DEFAULTS)

def _save(d):
    tmp = str(CFG)+".tmp"
    Path(tmp).write_text(json.dumps(d, indent=2, ensure_ascii=False, sort_keys=True))
    os.replace(tmp, CFG)

def get(key, default=None):
    return _load().get(key, default)

def set_(key, value):
    d = _load()
    # розпізнати тип
    if isinstance(value, str):
        if value.lower() in ("true","yes","1"): value = True
        elif value.lower() in ("false","no","0"): value = False
        else:
            try: value = int(value)
            except ValueError:
                try: value = float(value)
                except ValueError: pass
    d[key] = value
    _save(d)
    return True, f"{key} = {value}"

def unset(key):
    d = _load()
    if key in d:
        del d[key]
        _save(d); return True, f"видалено {key}"
    return False, f"немає {key}"

def all_opts():
    return _load()

def reset():
    _save(DEFAULTS)
    return True, "скинуто до defaults"

def by_prefix(prefix):
    return {k:v for k,v in _load().items() if k.startswith(prefix)}

def export_env():
    """Виводить як env-змінні для bash."""
    d = _load()
    for k, v in sorted(d.items()):
        env_key = k.upper().replace(".", "_")
        if isinstance(v, bool):
            print(f'{env_key}={"1" if v else "0"}')
        else:
            print(f'{env_key}="{v}"')

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd == "show":
        G='\033[32m'; Y='\033[33m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
        opts = all_opts()
        cats = {}
        for k, v in opts.items():
            cat = k.split(".")[0]
            cats.setdefault(cat, []).append((k, v))
        for cat in sorted(cats):
            print(f"\n  {B}▸ {cat}{N}")
            for k, v in cats[cat]:
                col = G if v is True else (Y if v is False else "")
                print(f"    {k:32s} {col}{v}{N}")
        print()
    elif cmd == "get":
        print(get(sys.argv[2]))
    elif cmd == "set":
        if len(sys.argv) < 4: print("usage: options.py set <key> <value>"); sys.exit(1)
        ok, m = set_(sys.argv[2], sys.argv[3]); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "unset":
        ok, m = unset(sys.argv[2]); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "list":
        for k, v in sorted(all_opts().items()): print(f"  {k}={v}")
    elif cmd == "env":
        export_env()
    elif cmd == "reset":
        ok, m = reset(); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "prefix":
        for k, v in by_prefix(sys.argv[2]).items(): print(f"  {k}={v}")
