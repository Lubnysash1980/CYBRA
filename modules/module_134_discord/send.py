#!/usr/bin/env python3
"""Надсилає повідомлення у Discord через webhook."""
import json, os, sys, urllib.request
from pathlib import Path
CFG = Path.home() / "CYBRA/config/discord.env"

def _load():
    if not CFG.exists(): return None
    for line in CFG.read_text().splitlines():
        if line.startswith("DISCORD_WEBHOOK="):
            return line.split("=",1)[1].strip().strip('"').strip("'")
    return None

def send(content, embeds=None, username="CYBRA"):
    url = _load()
    if not url: return False, "немає DISCORD_WEBHOOK у config/discord.env"
    body = {"content": content, "username": username}
    if embeds: body["embeds"] = embeds
    try:
        data = json.dumps(body).encode()
        req = urllib.request.Request(url, data=data,
            headers={"Content-Type":"application/json"}, method="POST")
        urllib.request.urlopen(req, timeout=10).read()
        return True, "надіслано"
    except Exception as e:
        return False, str(e)

if __name__ == "__main__":
    msg = " ".join(sys.argv[1:]) or "CYBRA ping"
    ok, m = send(msg)
    print(("✓ " if ok else "✗ ")+m)
