"""Telegram токен — валідний?"""
import urllib.request, json
from pathlib import Path

CFG = Path.home() / "CYBRA/config/telegram.env"

def run():
    if not CFG.exists():
        return [{"id":"tg","name":"Telegram","status":"ok",
                 "detail":"не налаштовано (опційно)","fix_hint":""}]
    env = {}
    for line in CFG.read_text().splitlines():
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=",1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    tok = env.get("TG_TOKEN"); chat = env.get("TG_CHAT")
    if not tok:
        return [{"id":"tg","name":"Telegram","status":"ok",
                 "detail":"не активний (токен не вказано)","fix_hint":""}]
    try:
        with urllib.request.urlopen(f"https://api.telegram.org/bot{tok}/getMe", timeout=8) as r:
            j = json.loads(r.read())
        if j.get("ok"):
            return [{"id":"tg","name":"Telegram","status":"ok",
                     "detail":f"@{j['result'].get('username','?')}","fix_hint":""}]
        return [{"id":"tg","name":"Telegram","status":"warn",
                 "detail":"token invalid","fix_hint":"онови TG_TOKEN"}]
    except Exception as e:
        return [{"id":"tg","name":"Telegram","status":"warn",
                 "detail":f"network: {str(e)[:60]}","fix_hint":""}]
