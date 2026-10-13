#!/usr/bin/env python3
"""Щоденний дайджест у Telegram: підписи, парламент, гроші, алерти."""
import sys, os, json, time
from pathlib import Path
H = Path.home() / "CYBRA"
sys.path.insert(0, str(H/"modules/module_121_parlament"))
sys.path.insert(0, str(H/"modules/module_141_portfolio"))

def build():
    G=''; N=''
    lines = [f"*📊 CYBRA Daily · {time.strftime('%Y-%m-%d')}*", ""]

    # підписи за добу
    ev = H/"modules/module_19_contract_tui_menu/evidence"
    cutoff = time.time() - 86400
    sigs_24h = [f for f in ev.glob("*.sig") if f.stat().st_mtime > cutoff] if ev.exists() else []
    lines.append(f"*Підписи за добу:* {len(sigs_24h)}")

    # парламент
    try:
        import parliament as P
        props = P.proposals()
        new_24h = [p for p in props if p.get("created","")[:10] == time.strftime("%Y-%m-%d")]
        lines.append(f"*Пропозицій:* {len(new_24h)} нових · {len([p for p in props if p.get('status')=='open'])} відкрито")
    except Exception: pass

    # портфель
    try:
        import portfolio
        if portfolio.HISTORY.exists():
            last = json.loads(portfolio.HISTORY.read_text().splitlines()[-1])
            pnl = portfolio.pnl()
            if pnl:
                sign = "+" if pnl["delta_usd"] >= 0 else ""
                lines.append(f"*Портфель:* ${last['total_usd']:.2f} ({sign}{pnl['delta_usd']:.2f})")
            else:
                lines.append(f"*Портфель:* ${last['total_usd']:.2f}")
    except Exception: pass

    # виконання
    try:
        import verify_7
        ex = H/"modules/module_121_parlament/data/executions"
        if ex.exists():
            execs = []
            for f in ex.glob("C-*.json"):
                st = verify_7.status(f.stem)
                if st: execs.append(st)
            active = len([e for e in execs if e["progress"] < 100])
            lines.append(f"*Активних контрактів:* {active}")
    except Exception: pass

    # алерти
    try:
        import orchestrator
        o = orchestrator.Orchestrator(verbose=False)
        al = o.mon.alerts()
        if al:
            lines.append("")
            lines.append(f"*⚠️ {len(al)} алертів:*")
            for x in al[:5]:
                lines.append(f"  · {x['msg']}")
    except Exception: pass

    # тренд
    try:
        import orchestrator
        o = orchestrator.Orchestrator(verbose=False)
        tr = o.mon.trend(24)
        if tr:
            mods_first = tr[0].get("modules_count", 0)
            mods_last = tr[-1].get("modules_count", 0)
            if mods_last != mods_first:
                lines.append(f"*Модулів:* {mods_first} → {mods_last}")
    except Exception: pass

    return "\n".join(lines)

def send():
    text = build()
    try:
        import alerts
        ok = alerts._tg(text)
        print("✓ надіслано" if ok else "✗ не надіслано (перевір config/telegram.env)")
    except Exception as e:
        print(f"✗ {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "text":
        print(build())
    else:
        send()
