#!/usr/bin/env python3
"""Бекап парламентських даних на WebDAV (Nextcloud, Yandex.Disk, etc)."""
import sys, os, json, time, tarfile, tempfile, urllib.request, base64
from pathlib import Path

D = Path(__file__).resolve().parent
DATA = D / "data"
PROTO = D / "protocols"
UNDO = D / "undo"
CFG = D / "webdav.json"
STATE = D / "webdav_state.json"

DEFAULT = {
    "enabled": False,
    "url": "",              # https://cloud.example.com/remote.php/dav/files/user/CYBRA
    "user": "",
    "pass": "",
    "keep_days": 30,
}

def _cfg():
    c = dict(DEFAULT)
    if CFG.exists():
        try: c.update(json.loads(CFG.read_text()))
        except Exception: pass
    return c

def _save_cfg(c): CFG.write_text(json.dumps(c, indent=2))

def _req(method, url, data=None, user=None, pwd=None, timeout=60):
    if not user:
        c = _cfg(); user = c["user"]; pwd = c["pass"]
    auth = base64.b64encode(f"{user}:{pwd}".encode()).decode()
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Basic {auth}")
    if data is not None and not isinstance(data, bytes):
        data = data.encode(); req.data = data
    if method == "PUT":
        req.add_header("Content-Type", "application/octet-stream")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return True, r.status, r.read()
    except urllib.error.HTTPError as e:
        return False, e.code, str(e).encode()
    except Exception as e:
        return False, 0, str(e).encode()

def setup(url, user, pwd, keep_days=30):
    c = _cfg(); c.update({"url": url.rstrip("/"), "user": user, "pass": pwd,
                          "enabled": True, "keep_days": keep_days})
    _save_cfg(c)
    # MKCOL — створити папку
    rc, code, body = _req("MKCOL", c["url"] + "/")
    if code in (201, 405):  # created | already exists
        return True, "налаштовано"
    return False, f"MKCOL {code}: {body[:120]}"

def make_archive():
    """Пакує data + protocols + undo у tar.gz."""
    ts = time.strftime("%Y%m%d_%H%M%S")
    tmp = Path(tempfile.gettempdir()) / f"parlament_{ts}.tar.gz"
    with tarfile.open(tmp, "w:gz") as tf:
        if DATA.exists():
            for f in DATA.glob("*"):
                if f.is_file(): tf.add(f, arcname=f"data/{f.name}")
        if PROTO.exists():
            for f in PROTO.glob("*.html"): tf.add(f, arcname=f"protocols/{f.name}")
            for f in PROTO.glob("*.pdf"):  tf.add(f, arcname=f"protocols/{f.name}")
        if UNDO.exists():
            for f in UNDO.glob("*.bak"):   tf.add(f, arcname=f"undo/{f.name}")
    return tmp, ts

def upload(archive_path, ts):
    c = _cfg()
    if not c["enabled"]: return False, "не активовано"
    name = archive_path.name
    url = f"{c['url']}/{name}"
    data = archive_path.read_bytes()
    rc, code, body = _req("PUT", url, data=data)
    if rc: return True, url
    return False, f"PUT {code}: {body[:120]}"

def prune_remote():
    """Видаляє старі архіви (keep_days)."""
    c = _cfg()
    if not c["enabled"]: return
    rc, code, body = _req("PROPFIND", c["url"] + "/",
                          data=b'<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:getlastmodified/></d:prop></d:propfind>')
    if not rc: return
    # Парсинг XML мінімально
    try:
        import re
        xml = body.decode()
        now = time.time()
        for m in re.finditer(r'<d:href>([^<]+)</d:href>.*?<d:getlastmodified>([^<]+)</d:getlastmodified>', xml, re.S):
            href, lm = m.groups()
            if not href.endswith(".tar.gz"): continue
            try:
                t = time.mktime(time.strptime(lm[:25], "%a, %d %b %Y %H:%M:%S"))
            except Exception: continue
            if now - t > c["keep_days"] * 86400:
                _req("DELETE", f"{c['url']}/{Path(href).name}")
    except Exception: pass

def backup():
    c = _cfg()
    if not c["enabled"]: return {"ok": False, "reason": "не активовано"}
    archive, ts = make_archive()
    ok, msg = upload(archive, ts)
    try: archive.unlink()
    except Exception: pass
    if ok:
        prune_remote()
        STATE.write_text(json.dumps({"last": ts, "url": msg,
                                     "ok": True}, indent=2))
    else:
        STATE.write_text(json.dumps({"last": ts, "error": msg,
                                     "ok": False}, indent=2))
    return {"ok": ok, "msg": msg, "ts": ts}

def restore(url=None):
    """Завантажує останній архів і розпаковує."""
    c = _cfg()
    if not c["enabled"] and not url: return False, "не активовано"
    if not url:
        # знайти останній
        rc, code, body = _req("PROPFIND", c["url"] + "/",
                              data=b'<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop/></d:propfind>')
        if not rc: return False, f"PROPFIND {code}"
        import re
        names = sorted(re.findall(r'<d:href>[^<]*/(parlament_\d+_\d+\.tar\.gz)</d:href>',
                                  body.decode()))
        if not names: return False, "немає архівів"
        url = f"{c['url']}/{names[-1]}"
    rc, code, body = _req("GET", url)
    if not rc: return False, f"GET {code}"
    tmp = Path(tempfile.gettempdir()) / "parlament_restore.tar.gz"
    tmp.write_bytes(body)
    # бекап поточного
    bak = D / f"restore_backup_{int(time.time())}"
    bak.mkdir()
    with tarfile.open(tmp, "r:gz") as tf:
        tf.extractall(D)
    return True, f"відновлено з {url} → {D}"

def status():
    c = _cfg()
    s = {"enabled": c["enabled"], "url": c["url"] or "(не вказано)"}
    if STATE.exists():
        try: s.update(json.loads(STATE.read_text()))
        except Exception: pass
    return s

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "setup":
        if len(sys.argv) < 5:
            print("usage: webdav.py setup <url> <user> <pass> [keep_days]")
            sys.exit(1)
        kd = int(sys.argv[5]) if len(sys.argv) > 5 else 30
        ok, msg = setup(sys.argv[2], sys.argv[3], sys.argv[4], kd)
        print(("✓ " if ok else "✗ ") + msg)
    elif cmd == "backup":
        print(json.dumps(backup(), indent=2, ensure_ascii=False))
    elif cmd == "restore":
        ok, msg = restore(sys.argv[2] if len(sys.argv) > 2 else None)
        print(("✓ " if ok else "✗ ") + msg)
    elif cmd == "status":
        print(json.dumps(status(), indent=2, ensure_ascii=False))
