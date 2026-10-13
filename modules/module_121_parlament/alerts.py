#!/usr/bin/env python3
"""Центральні алерти парламенту в Telegram + Termux-нотифікація."""
import json, os, urllib.request, subprocess, sys
from pathlib import Path

H = Path.home() / "CYBRA"
TG = H / "config/telegram.env"

PRIORITY = {
    "veto":              "🚨",
    "proposal_created":  "📜",
    "quorum_reached":    "✅",
    "approved":          "🎉",
    "executed":          "⚙️",
    "chain_broken":      "🔥",
    "action_failed":     "❌",
    "action_executed":   "✓",
    "member_added":      "👤",
    "member_removed":    "🚪",
    "rule_changed":      "📏",
}

def _load_tg():
    if not TG.exists(): return None, None
    env = {}
    for l in TG.read_text().splitlines():
        l = l.strip()
        if "=" in l and not l.startswith("#"):
            k, v = l.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env.get("TG_TOKEN"), env.get("TG_CHAT")

def _tg(text):
    tok, chat = _load_tg()
    if not tok or not chat: return False
    try:
        data = json.dumps({
            "chat_id": chat, "text": text, "parse_mode": "Markdown",
            "disable_web_page_preview": True
        }).encode()
        req = urllib.request.Request(
            f"https://api.telegram.org/bot{tok}/sendMessage",
            data=data, headers={"Content-Type":"application/json"})
        urllib.request.urlopen(req, timeout=10).read()
        return True
    except Exception as e:
        print(f"[alerts] tg: {e}", file=sys.stderr)
        return False

def _termux(title, body):
    try:
        subprocess.run(["termux-notification",
                        "--title", title[:64],
                        "--content", body[:200]],
                       timeout=5, capture_output=True)
    except Exception: pass

def send(kind, text, extra=""):
    emoji = PRIORITY.get(kind, "ℹ️")
    title = f"{emoji} CYBRA · {kind}"
    full = f"{title}\n{text}"
    if extra: full += f"\n\n{extra}"
    _tg(full)
    _termux(title, text)

# ── підписки з парламенту ───────────────────────────────────
def on_veto(pid, voter_label, reason, title):
    send("veto",
         f"*VETO* · {pid}",
         f"*{title}*\nВід: {voter_label}\nПричина: {reason or '—'}")

def on_proposal(pid, ptype, title, author_label):
    send("proposal_created",
         f"*{title}*",
         f"Тип: {ptype}\nАвтор: {author_label}\nPID: `{pid}`")

def on_approved(pid, title, tally):
    send("approved",
         f"*{title}*",
         f"За: {tally['yes']['weight']} · Проти: {tally['no']['weight']}\n"
         f"Схвалення: {tally['approval_percent']}%")

def on_chain_broken(report):
    send("chain_broken",
         "Hash-chain порушено!",
         f"Биті: {report}")

def on_action(action, ok, msg):
    if ok:
        send("action_executed", f"{action}", msg)
    else:
        send("action_failed", f"{action} FAIL", msg)

if __name__ == "__main__":
    # CLI: alerts.py <kind> <text> [extra]
    if len(sys.argv) < 3:
        print("usage: alerts.py <kind> <text> [extra]"); sys.exit(1)
    send(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
    print("sent")
