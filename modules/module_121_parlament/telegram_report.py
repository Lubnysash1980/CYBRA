#!/usr/bin/env python3
"""Формує звіт парламенту і шле в Telegram (якщо налаштовано)."""
import sys, os, json, urllib.request, time
from pathlib import Path

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
TG = H / "config/telegram.env"
sys.path.insert(0, str(D))

def _load_tg():
    if not TG.exists(): return None, None
    env = {}
    for l in TG.read_text().splitlines():
        l = l.strip()
        if "=" in l and not l.startswith("#"):
            k, v = l.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env.get("TG_TOKEN"), env.get("TG_CHAT")

def _send(token, chat, text):
    try:
        data = json.dumps({"chat_id": chat, "text": text,
                           "parse_mode": "Markdown",
                           "disable_web_page_preview": True}).encode()
        req = urllib.request.Request(
            f"https://api.telegram.org/bot{token}/sendMessage",
            data=data, headers={"Content-Type":"application/json"})
        urllib.request.urlopen(req, timeout=10).read()
        return True
    except Exception as e:
        print(f"  tg error: {e}", file=sys.stderr)
        return False

def build_report():
    import todo, parliament as P, actions
    items = todo.plan()
    counts = {"auto":0,"vote":0,"veto":0,"manual":0}
    for i in items: counts[i["level"]] = counts.get(i["level"],0) + 1

    lines = []
    lines.append(f"*CYBRA Parliament · {time.strftime('%Y-%m-%d %H:%M')}*")
    lines.append("")
    lines.append(f"Проблем: {len(items)}")
    lines.append(f"auto={counts['auto']} · vote={counts['vote']} · veto={counts['veto']}")
    lines.append("")

    if items:
        lines.append("*Що робити:*")
        for i in items[:8]:
            st = {"critical":"🚨","fail":"🔴","warn":"🟡"}.get(i["status"],"•")
            lines.append(f"{st} {i['name'][:40]}")
            lines.append(f"   → {i['action_name']}")
        if len(items) > 8:
            lines.append(f"   … і ще {len(items)-8}")

    # відкриті пропозиції
    open_props = P.proposals(status="open")
    if open_props:
        lines.append("")
        lines.append(f"*Відкритих пропозицій:* {len(open_props)}")
        for p in open_props[:3]:
            t = P.tally(p["pid"])
            lines.append(f"  {p['pid']}: за={t['yes']['weight']} проти={t['no']['weight']}")

    # виконані за добу
    recent = [e for e in actions.recent(200)
              if e.get("ts","")[:10] == time.strftime("%Y-%m-%d")]
    if recent:
        ok_n = len([e for e in recent if e.get("ok")])
        lines.append("")
        lines.append(f"*Виконано сьогодні:* {ok_n}/{len(recent)}")

    return "\n".join(lines)

def send_report():
    token, chat = _load_tg()
    text = build_report()
    if not token or not chat:
        print(text)
        print("\n  (Telegram не налаштовано — вивід у консоль)")
        return False
    ok = _send(token, chat, text)
    print("  ✓ надіслано" if ok else "  ✗ не вдалось")
    return ok

if __name__ == "__main__":
    send_report()
