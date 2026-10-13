#!/usr/bin/env python3
"""SMTP відправка листів."""
import smtplib, json, os, sys, ssl
from pathlib import Path
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

H = Path.home() / "CYBRA"
CFG = H / "config" / "email.json"

DEFAULT = {
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "use_tls": True,
    "user": "",
    "password": "",
    "from_name": "CYBRA",
    "enabled": False,
}

def cfg():
    if not CFG.exists():
        CFG.write_text(json.dumps(DEFAULT, indent=2))
        return dict(DEFAULT)
    try:
        c = json.loads(CFG.read_text())
        base = dict(DEFAULT); base.update(c); return base
    except Exception: return dict(DEFAULT)

def save(c): CFG.write_text(json.dumps(c, indent=2))

def send(to, subject, body, html=False):
    c = cfg()
    if not c["enabled"]:
        return False, "email вимкнено (config/email.json)"
    if not c["user"] or not c["password"]:
        return False, "немає user/password"
    try:
        msg = MIMEMultipart("alternative")
        msg["From"] = f"{c['from_name']} <{c['user']}>"
        msg["To"] = to
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "html" if html else "plain", "utf-8"))
        if c["use_tls"]:
            ctx = ssl.create_default_context()
            with smtplib.SMTP(c["smtp_host"], c["smtp_port"], timeout=20) as s:
                s.ehlo(); s.starttls(context=ctx); s.login(c["user"], c["password"])
                s.send_message(msg)
        else:
            with smtplib.SMTP_SSL(c["smtp_host"], c["smtp_port"], timeout=20) as s:
                s.login(c["user"], c["password"]); s.send_message(msg)
        return True, "надіслано"
    except Exception as e:
        return False, str(e)[:200]

def test():
    c = cfg()
    ok, m = send(c["user"], "CYBRA test", "Це тестовий лист від CYBRA.")
    return ok, m

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "test"
    if cmd == "test":
        ok, m = test(); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "send":
        ok, m = send(sys.argv[2], sys.argv[3], sys.argv[4])
        print(("✓ " if ok else "✗ ")+m)
    elif cmd == "setup":
        c = cfg()
        c.update({"smtp_host":sys.argv[2],"smtp_port":int(sys.argv[3]),
                  "user":sys.argv[4],"password":sys.argv[5],"enabled":True})
        save(c); print("✓")
