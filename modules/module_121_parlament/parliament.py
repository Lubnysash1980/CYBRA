#!/usr/bin/env python3
"""CYBRA Parliament — governance над контрактами та рішеннями."""
import json, os, time, hashlib, secrets, sys
try:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import stream
except Exception:
    stream = None
try:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import alerts
except Exception:
    alerts = None
from pathlib import Path

D   = Path(__file__).resolve().parent
DATA = D / "data"
DATA.mkdir(exist_ok=True)
MEMBERS   = DATA / "members.json"
PROPOSALS = DATA / "proposals.jsonl"
VOTES     = DATA / "votes.jsonl"
AUDIT     = DATA / "audit.jsonl"
RULES     = DATA / "rules.json"

DEFAULT_RULES = {
    "quorum_percent": 60,
    "approval_percent": 51,
    "veto_roles": ["founder"],
    "min_weight_for_proposal": 1,
    "contract_value_threshold_bnb": 1.0,
    "vote_ttl_sec": 604800,
    "hash_chain": True,
}

ROLES = ["founder", "arbiter", "auditor", "buyer", "seller", "observer"]

# ─── базове ──────────────────────────────────────────────
def _now(): return int(time.time())
def _iso(t=None): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(t or _now()))

def _append_jsonl(path, obj):
    obj["_prev"] = _last_hash(path)
    obj["_hash"] = _hash_obj(obj)
    with open(path, "a") as f:
        f.write(json.dumps(obj, ensure_ascii=False, sort_keys=True) + "\n")
    return obj["_hash"]

def _hash_obj(obj):
    clean = {k: v for k, v in obj.items() if k != "_hash"}
    return hashlib.sha256(json.dumps(clean, ensure_ascii=False,
                                     sort_keys=True).encode()).hexdigest()

def _last_hash(path):
    if not path.exists(): return "0"*64
    try:
        lines = path.read_text().splitlines()
        for line in reversed(lines):
            if line.strip():
                return json.loads(line).get("_hash", "0"*64)
    except Exception: pass
    return "0"*64

def _read_jsonl(path):
    if not path.exists(): return []
    out = []
    for line in path.read_text().splitlines():
        if not line.strip(): continue
        try: out.append(json.loads(line))
        except Exception: pass
    return out

def _write_json(path, obj):
    tmp = str(path) + ".tmp"
    Path(tmp).write_text(json.dumps(obj, ensure_ascii=False, indent=2))
    os.replace(tmp, path)

def _read_json(path, default=None):
    if not path.exists(): return default if default is not None else {}
    try: return json.loads(path.read_text())
    except Exception: return default if default is not None else {}

# ─── правила ─────────────────────────────────────────────
def rules():
    r = _read_json(RULES, None) or {}
    merged = dict(DEFAULT_RULES); merged.update(r)
    return merged

def set_rule(k, v):
    r = rules(); r[k] = v; _write_json(RULES, r)
    audit("rule_change", {"key":k, "value":v})
    return True

# ─── члени ───────────────────────────────────────────────
def members():
    return _read_json(MEMBERS, {"members": []})

def add_member(addr, label, role="observer", weight=1):
    addr = addr.lower()
    if role not in ROLES:
        return False, f"невідома роль: {role}"
    m = members()
    for x in m["members"]:
        if x["addr"] == addr:
            return False, f"вже є: {x['label']}"
    m["members"].append({
        "addr": addr, "label": label, "role": role,
        "weight": int(weight), "added": _iso(),
        "active": True,
    })
    _write_json(MEMBERS, m)
    audit("member_add", {"addr":addr, "role":role, "weight":weight})
    return True, "додано"

def remove_member(addr):
    addr = addr.lower()
    m = members()
    for i, x in enumerate(m["members"]):
        if x["addr"] == addr:
            m["members"][i]["active"] = False
            m["members"][i]["removed"] = _iso()
            _write_json(MEMBERS, m)
            audit("member_remove", {"addr": addr})
            return True, "деактивовано"
    return False, "не знайдено"

def get_member(addr):
    addr = addr.lower()
    for x in members()["members"]:
        if x["addr"] == addr and x.get("active", True):
            return x
    return None

def total_weight():
    return sum(x["weight"] for x in members()["members"] if x.get("active", True))

# ─── пропозиції ──────────────────────────────────────────
PTYPES = ["contract_sign", "dispute", "upgrade", "rule_change", "custom"]

def create_proposal(ptype, title, payload, author, ttl=None):
    if ptype not in PTYPES:
        return False, f"невідомий тип: {ptype}", None
    if not _controllers_ok():
        return False, "🚫 контролери не 100% — створення пропозиції заблоковано", None
    a = get_member(author)
    if not a:
        return False, f"автор не є членом: {author}", None
    r = rules()
    if a["weight"] < r["min_weight_for_proposal"]:
        return False, "недостатня вага для пропозиції", None

    pid = "PRP-" + time.strftime("%Y%m%d%H%M%S") + "-" + secrets.token_hex(3)
    expires = _now() + (ttl or r["vote_ttl_sec"])
    proposal = {
        "pid": pid, "type": ptype, "title": title,
        "payload": payload, "author": a["addr"],
        "author_label": a["label"],
        "created": _iso(), "expires": expires,
        "quorum_percent": r["quorum_percent"],
        "approval_percent": r["approval_percent"],
        "status": "open",
    }
    _append_jsonl(PROPOSALS, proposal)
    audit("proposal_create", {"pid": pid, "type": ptype, "author": a["addr"]})
    if stream:
        try: stream.proposal(pid, ptype, title, a["addr"])
        except Exception: pass
    if alerts and ptype in ("contract_sign","upgrade","dispute","rule_change"):
        try: alerts.on_proposal(pid, ptype, title, a.get("label",""))
        except Exception: pass
    return True, "створено", pid

def get_proposal(pid):
    for p in _read_jsonl(PROPOSALS):
        if p.get("pid") == pid:
            return p
    return None

def proposals(status=None):
    all_ = _read_jsonl(PROPOSALS)
    # останній запис по pid виграє (може бути статус-апдейт)
    by_pid = {}
    for p in all_: by_pid[p["pid"]] = p
    out = list(by_pid.values())
    if status: out = [p for p in out if p.get("status") == status]
    return sorted(out, key=lambda x: x.get("created",""), reverse=True)

def votes_of(pid):
    return [v for v in _read_jsonl(VOTES) if v.get("pid") == pid]

def tally(pid):
    p = get_proposal(pid)
    if not p: return None
    vs = votes_of(pid)
    # останній голос члена
    by_addr = {}
    for v in vs:
        by_addr[v["voter"].lower()] = v
    yes_w = no_w = abstain_w = 0
    yes_n = no_n = abstain_n = 0
    voters = set()
    for addr, v in by_addr.items():
        mem = get_member(addr)
        if not mem: continue
        w = mem["weight"]
        voters.add(addr)
        if v["choice"] == "yes":     yes_w += w; yes_n += 1
        elif v["choice"] == "no":    no_w += w; no_n += 1
        else:                        abstain_w += w; abstain_n += 1

    tw = total_weight()
    participated = yes_w + no_w + abstain_w
    quorum_needed = tw * p["quorum_percent"] / 100
    quorum_ok = participated >= quorum_needed

    decided_w = yes_w + no_w
    approval = (yes_w / decided_w * 100) if decided_w > 0 else 0
    approval_ok = approval >= p["approval_percent"]

    expired = _now() > p.get("expires", 0)
    return {
        "pid": pid, "total_weight": tw,
        "yes": {"count": yes_n, "weight": yes_w},
        "no":  {"count": no_n,  "weight": no_w},
        "abstain": {"count": abstain_n, "weight": abstain_w},
        "participated_weight": participated,
        "quorum_needed": round(quorum_needed, 2),
        "quorum_ok": quorum_ok,
        "approval_percent": round(approval, 2),
        "approval_ok": approval_ok,
        "expired": expired,
        "decided": quorum_ok and approval_ok and not expired,
        "voters": sorted(voters),
    }

# ─── голосування ─────────────────────────────────────────
def sign_message(pid, voter, choice):
    """Канонічне повідомлення для підпису MetaMask."""
    p = get_proposal(pid)
    if not p: return None
    return (f"CYBRA Parliament Vote\n"
            f"PID: {pid}\n"
            f"Title: {p['title']}\n"
            f"Voter: {voter.lower()}\n"
            f"Choice: {choice}\n"
            f"Timestamp: {_iso()}")


def sic_snapshot():
    """Отримує SIC snapshot для парламенту."""
    try:
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "module_380_sic"))
        import sic
        return sic.snapshot()
    except Exception: return {}

def _controllers_ok():
    """Перевіряє 100% через gate 399. Fallback — controller_gate."""
    try:
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "module_399_gate"))
        import gate
        ok, _ = gate.allow("parliament_vote")
        return ok
    except Exception:
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import controller_gate
            return controller_gate.check()[0]
        except Exception:
            return False


def _solo_mode():
    """True якщо в парламенті тільки 1 активний член (founder)."""
    active = [m for m in members()["members"] if m.get("active", True)]
    return len(active) <= 1

def cast_vote(pid, voter, choice, signature, message=None):
    """Записує голос. Валідація підпису — окремо (verify_vote)."""
    if not _controllers_ok():
        return False, "🚫 контролери не 100% — голосування заблоковано"
    if choice not in ("yes","no","abstain"):
        return False, "choice: yes|no|abstain"
    p = get_proposal(pid)
    if not p: return False, "пропозиція не знайдена"
    if p.get("status") != "open":
        return False, f"статус: {p.get('status')}"
    if _now() > p.get("expires", 0):
        return False, "прострочено"
    voter = voter.lower()
    m = get_member(voter)
    if not m: return False, "ви не член парламенту"
    # один голос (останній виграє, але без зміни після закриття)
    for v in votes_of(pid):
        if v["voter"].lower() == voter and v["choice"] == choice:
            return False, "вже голосували так само"

    vote = {
        "pid": pid, "voter": voter, "choice": choice,
        "signature": signature, "message": message or sign_message(pid, voter, choice),
        "ts": _iso(),
    }
    _append_jsonl(VOTES, vote)
    audit("vote", {"pid": pid, "voter": voter, "choice": choice})
    if stream:
        try: stream.vote(pid, voter, choice)
        except Exception: pass
    return True, "голос зараховано"

def verify_vote_signature(vote):
    """Перевіряє що підпис відповідає voter-у."""
    try:
        from eth_account import Account
        from eth_account.messages import encode_defunct
        msg = vote.get("message","")
        sig = vote.get("signature","")
        if not msg or not sig: return False, "нема msg/sig"
        rec = Account.recover_message(encode_defunct(text=msg), signature=sig)
        if rec.lower() != vote["voter"].lower():
            return False, f"recovered={rec} != {vote['voter']}"
        return True, "ok"
    except ImportError:
        return False, "eth_account відсутній"
    except Exception as e:
        return False, f"ecrecover: {e}"

# ─── закриття та виконання ───────────────────────────────
def close_proposal(pid):
    p = get_proposal(pid)
    if not p: return False, "не знайдено"
    if p.get("status") != "open":
        return False, f"вже {p.get('status')}"
    t = tally(pid)
    if not t: return False, "tally fail"
    # Solo-режим: founder один — авто-approve
    if _solo_mode() and not t["quorum_ok"]:
        # авто-голос founder якщо ще не голосував
        for m in members()["members"]:
            if m.get("active") and m["role"] == "founder":
                existing = [v for v in votes_of(pid) if v["voter"].lower() == m["addr"].lower()]
                if not existing:
                    cast_vote(pid, m["addr"], "yes", "auto:solo", 
                             sign_message(pid, m["addr"], "yes"))
                    t = tally(pid)
                break
    if not t["quorum_ok"]:
        return False, f"кворум не досягнуто: {t['participated_weight']}/{t['quorum_needed']}"
    if not t["approval_ok"]:
        return False, f"схвалення {t['approval_percent']}% < {p['approval_percent']}%"

    updated = dict(p); updated["status"] = "approved"
    updated["closed"] = _iso(); updated["tally"] = t
    _append_jsonl(PROPOSALS, updated)
    audit("proposal_approved", {"pid": pid, "tally": t})
    if alerts:
        try: alerts.on_approved(pid, p.get("title",""), t)
        except Exception: pass
    try:
        import protocol
        protocol.generate(pid)
    except Exception: pass
    return True, "схвалено"

def veto_proposal(pid, voter, signature, reason=""):
    voter = voter.lower()
    m = get_member(voter)
    if not m: return False, "не член"
    if m["role"] not in rules()["veto_roles"]:
        return False, f"роль {m['role']} не має вето"
    p = get_proposal(pid)
    if not p or p.get("status") != "open":
        return False, "пропозиція не відкрита"
    updated = dict(p)
    updated["status"] = "vetoed"
    updated["closed"] = _iso()
    updated["veto"] = {"by": voter, "reason": reason, "signature": signature,
                       "ts": _iso()}
    _append_jsonl(PROPOSALS, updated)
    audit("proposal_vetoed", {"pid": pid, "by": voter, "reason": reason})
    if alerts:
        try: alerts.on_veto(pid, m.get("label", voter[:10]), reason, p.get("title",""))
        except Exception: pass
    return True, "вето накладено"

# ─── хеш-ланцюг (tamper detection) ───────────────────────
def audit(kind, payload):
    _append_jsonl(AUDIT, {"kind": kind, "payload": payload})
    # autopush після важливих подій
    if kind in ("proposal_approved","proposal_vetoed","vote"):
        try:
            import git_sync
            git_sync.sync(both=True)
        except Exception: pass

def verify_chain():
    """Перевіряє цілісність усіх журналів."""
    reports = {}
    for name, path in [("proposals", PROPOSALS), ("votes", VOTES), ("audit", AUDIT)]:
        prev = "0"*64; bad = 0; n = 0
        for line in _read_jsonl(path):
            n += 1
            stored = line.get("_hash")
            calc = _hash_obj(line)
            if stored != calc: bad += 1
            if line.get("_prev") != prev: bad += 1
            prev = stored
        reports[name] = {"entries": n, "broken": bad, "ok": bad == 0}
    return reports

# ─── репутація ───────────────────────────────────────────
def reputation():
    """Скільки голосів, скільки збіглось з фіналом, скільки пропозицій."""
    rep = {}
    for m in members()["members"]:
        if not m.get("active", True): continue
        addr = m["addr"]
        rep[addr] = {"label": m["label"], "role": m["role"], "weight": m["weight"],
                     "votes": 0, "proposals": 0, "approved": 0}
    for v in _read_jsonl(VOTES):
        a = v["voter"].lower()
        if a in rep: rep[a]["votes"] += 1
    for p in proposals():
        a = p.get("author")
        if a in rep:
            rep[a]["proposals"] += 1
            if p.get("status") == "approved": rep[a]["approved"] += 1
    return rep

# ─── утиліти ─────────────────────────────────────────────
def next_step_hint(pid):
    """Що робити далі з пропозицією."""
    t = tally(pid)
    if not t: return "?"
    if t["expired"]: return "прострочено — закрий або перествори"
    if t["decided"]: return "готово до close"
    need_q = max(0, t["quorum_needed"] - t["participated_weight"])
    need_a = max(0, (t["approval_percent"] if not t["approval_ok"] else 0))
    parts = []
    if not t["quorum_ok"]: parts.append(f"кворум: ще {need_q:.0f} ваги")
    if not t["approval_ok"]: parts.append(f"схвалення: {t['approval_percent']}%")
    return ", ".join(parts) or "?"

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "chain":
        print(json.dumps(verify_chain(), indent=2, ensure_ascii=False))
