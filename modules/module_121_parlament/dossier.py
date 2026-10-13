#!/usr/bin/env python3
"""Contract Dossier — усе що парламент знає про контракт.
Джерела: 108(sig), 111(invoice), 119(QR), 121(proposals/votes/exec),
verify_7(levels), deviation, hooks, stream, backups, git."""
import os, sys, json, time, hashlib
from pathlib import Path
from collections import Counter

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
sys.path.insert(0, str(D))

C_R='\033[31m'; C_G='\033[32m'; C_Y='\033[33m'; C_B='\033[36m'
C_M='\033[35m'; C_D='\033[2m'; C_BOLD='\033[1m'; C_N='\033[0m'

def _sec(t):
    return f"\n{C_B}{C_BOLD}═══ {t} ═══{C_N}"

def _kv(k, v, w=22):
    return f"  {C_D}{k:.<{w}}{C_N} {v}"

def _trunc(s, n=70):
    s = str(s)
    return s if len(s) <= n else s[:n-1] + "…"

# ─── джерела ────────────────────────────────────────────────

def _find_sig(cid):
    for pat in [f"modules/module_19_contract_tui_menu/evidence/{cid}_buyer.sig",
                f"public/sign/{cid}.json"]:
        p = H / pat
        if p.exists(): return p
    for base in [H/"modules/module_19_contract_tui_menu/evidence",
                 H/"public/sign"]:
        if not base.exists(): continue
        for f in base.glob(f"{cid}*"):
            return f
    return None

def gather_signature(cid):
    p = _find_sig(cid)
    if not p: return None
    try:
        d = json.loads(p.read_text())
    except Exception:
        return {"path": str(p), "error": "не JSON"}
    out = {"path": str(p), "size": p.stat().st_size}
    # invoice_payment контракт не має .sig — він показує buyer/pay_to
    if d.get("type") == "invoice_payment":
        out["type"] = "invoice_payment"
        out["address"] = d.get("buyer")
        out["pay_to"] = d.get("pay_to")
        out["total_uah"] = d.get("total_uah")
        out["invoice_no"] = (d.get("invoice") or {}).get("no")
        return out
    # звичайний .sig
    out["address"] = d.get("address")
    out["cid_in_file"] = d.get("cid")
    out["signature"] = d.get("signature","")
    out["message"] = d.get("message","")
    out["level"] = d.get("level")
    # верифікація
    try:
        from eth_account import Account
        from eth_account.messages import encode_defunct
        rec = Account.recover_message(encode_defunct(text=d["message"]),
                                      signature=d["signature"])
        out["recovered"] = rec
        out["valid"] = rec.lower() == d["address"].lower()
    except Exception as e:
        out["valid"] = None; out["verify_err"] = str(e)
    return out

def gather_proposals(cid):
    try:
        import parliament as P
        out = []
        for p in P.proposals():
            pl = p.get("payload") or {}
            if pl.get("cid") == cid or cid in (p.get("title") or ""):
                t = P.tally(p["pid"])
                votes = P.votes_of(p["pid"])
                out.append({
                    "pid": p["pid"], "status": p["status"],
                    "title": p["title"], "type": p["type"],
                    "author": p.get("author_label"),
                    "created": p.get("created"), "closed": p.get("closed"),
                    "tally": t, "votes": votes,
                    "veto": p.get("veto"),
                })
        return out
    except Exception:
        return []

def gather_execution(cid):
    try:
        import verify_7
        return verify_7.status(cid)
    except Exception:
        return None

def gather_plan(cid):
    p = D / "data" / "executions" / f"{cid}_plan.json"
    if p.exists():
        try: return json.loads(p.read_text())
        except Exception: pass
    return None

def gather_deviations(cid):
    f = D / "data" / "executions" / f"{cid}_deviations.jsonl"
    if not f.exists(): return []
    out = []
    for line in f.read_text().splitlines():
        try: out.append(json.loads(line))
        except Exception: pass
    return out

def gather_actions(cid):
    try:
        import actions
        return [e for e in actions.recent(500)
                if cid in json.dumps(e)]
    except Exception:
        return []

def gather_stream(cid, n=100):
    try:
        import stream
        return [e for e in stream.read(2000)
                if cid in json.dumps(e.get("data", {})) or cid in e.get("ev","")]
    except Exception:
        return []

def gather_hooks(cid):
    try:
        import hooks
        return [h for h in hooks.registered()
                if cid in json.dumps(h)]
    except Exception:
        return []

def gather_invoice(cid):
    """Спробувати знайти INVOICE від 111."""
    for pat in [f"modules/module_11_invoice/data/{cid}.json",
                f"modules/module_19_contract_tui_menu/invoices/{cid}.json"]:
        p = H / pat
        if p.exists():
            try: return json.loads(p.read_text())
            except Exception: pass
    return None

def gather_backups(cid):
    out = []
    for base in [H/"backups", H/"modules/module_19_contract_tui_menu/backups"]:
        if not base.exists(): continue
        for f in base.rglob(f"*{cid}*"):
            out.append({"path": str(f), "size": f.stat().st_size,
                        "mtime": time.strftime("%Y-%m-%d %H:%M",
                                               time.localtime(f.stat().st_mtime))})
    return out[:10]

def gather_protocols(cid):
    pdir = D / "protocols"
    if not pdir.exists(): return []
    return [{"path": str(f), "size": f.stat().st_size} for f in pdir.glob(f"*{cid}*")]

def gather_tx_plans(cid):
    out = []
    for name in [f"{cid}_pending_tx.json", f"{cid}_release_tx.json"]:
        p = D / "data" / "executions" / name
        if p.exists():
            try: out.append({"kind": name, "plan": json.loads(p.read_text())})
            except Exception: pass
    return out


def gather_validation(cid):
    """Читає звіт валідатора 122, якщо є."""
    for base in [H/"modules/module_122_contract_validator/data"]:
        p = base / f"{cid}_validation.json"
        if p.exists():
            try: return json.loads(p.read_text())
            except Exception: pass
    return None

# ─── хеш дос'є (для доведення незмінності) ─────────────────
def dossier_hash(d):
    clone = {k: v for k, v in d.items() if k != "_dossier_hash"}
    return hashlib.sha256(
        json.dumps(clone, sort_keys=True, ensure_ascii=False, default=str).encode()
    ).hexdigest()

# ─── рендер ─────────────────────────────────────────────────
def render(cid, out_console=True, save=True):
    d = {
        "cid": cid,
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "validation": gather_validation(cid),
        "signature": gather_signature(cid),
        "proposals": gather_proposals(cid),
        "execution": gather_execution(cid),
        "plan": gather_plan(cid),
        "deviations": gather_deviations(cid),
        "actions": gather_actions(cid),
        "stream": gather_stream(cid),
        "hooks": gather_hooks(cid),
        "invoice": gather_invoice(cid),
        "backups": gather_backups(cid),
        "protocols": gather_protocols(cid),
        "tx_plans": gather_tx_plans(cid),
    }
    d["_dossier_hash"] = dossier_hash(d)

    if save:
        p = D / "data" / "executions" / f"{cid}_dossier.json"
        p.write_text(json.dumps(d, indent=2, ensure_ascii=False, default=str))

    if out_console:
        _print(cid, d)
    return d

def _print(cid, d):
    W = 78
    print(f"\n{C_B}{'═'*W}{C_N}")
    print(f"{C_B}{C_BOLD}  📄 CONTRACT DOSSIER{C_N}  {C_D}{cid}{C_N}")
    print(f"{C_B}{'═'*W}{C_N}")
    print(f"  {C_D}Згенеровано: {d['generated']}{C_N}")

    # ── ВАЛІДАЦІЯ ──
    val = d.get("validation")
    if val:
        print(_sec("0 · ВАЛІДАЦІЯ (122)"))
        verdict_color = C_G if val.get("verdict")=="OK" else C_R
        print(_kv("Вердикт", f"{verdict_color}{val.get('verdict')}{C_N}"))
        print(_kv("Score", f"{val.get('score',0)}/100"))
        print(_kv("Critical fails", val.get("critical_fail", 0)))
        print(_kv("Warn fails", val.get("warn_fail", 0)))
        fails = [r for r in val.get("results",[]) if not r.get("ok")]
        if fails:
            print(f"  {C_Y}Провалені перевірки:{C_N}")
            for f in fails:
                col = C_R if f.get("level")=="critical" else C_Y
                print(f"    {col}✗{C_N} [{f.get('level'):8s}] {f.get('name')} — {f.get('detail')}")

    # ── ПІДПИС ──
    print(_sec("1 · ПІДПИС"))
    s = d["signature"]
    if not s:
        print(f"  {C_Y}немає .sig файлу{C_N}")
    elif s.get("error"):
        print(f"  {C_R}помилка: {s['error']}{C_N}")
    elif s.get("type") == "invoice_payment":
        # invoice_payment — показуємо інші поля
        print(_kv("Тип", "invoice_payment"))
        print(_kv("Покупець", s.get("address") or "—"))
        print(_kv("Отримувач", s.get("pay_to") or "—"))
        print(_kv("Рахунок", f"№{s.get('invoice_no','—')}"))
        print(_kv("Сума", f"{s.get('total_uah',0):,.2f} UAH"))
        print(f"  {C_Y}!{C_N} Контракт ще не підписано (треба cybra → 108)")
    else:
        v = s.get("valid")
        mark = f"{C_G}✓ валідний{C_N}" if v else (f"{C_R}✗ НЕВАЛІДНИЙ{C_N}" if v is False else f"{C_Y}?{C_N}")
        print(_kv("Файл", _trunc(s["path"], 50)))
        print(_kv("Розмір", f"{s['size']} байт"))
        print(_kv("Адреса", s.get("address","—")))
        print(_kv("Recovered", s.get("recovered","—")))
        print(_kv("Перевірка", mark))
        if s.get("signature"):
            print(_kv("Підпис", s["signature"][:42] + "…"))
        if s.get("level"):
            print(_kv("QR рівень", s["level"]))

    # ── ПАРЛАМЕНТ ──
    print(_sec("2 · ПАРЛАМЕНТ"))
    props = d["proposals"]
    if not props:
        print(f"  {C_D}немає пропозицій по цьому контракту{C_N}")
    else:
        for p in props:
            st_color = {"approved":C_G, "vetoed":C_R, "open":C_Y}.get(p["status"], C_D)
            print(f"\n  {C_BOLD}{p['pid']}{C_N}  {st_color}[{p['status']}]{C_N}")
            print(_kv("  Заголовок", p["title"]))
            print(_kv("  Тип", p["type"]))
            print(_kv("  Автор", p.get("author","—")))
            print(_kv("  Створено", p.get("created","—")))
            if p.get("closed"): print(_kv("  Закрито", p["closed"]))
            t = p.get("tally") or {}
            if t:
                q = t.get("quorum_ok"); a = t.get("approval_ok")
                qm = f"{C_G}✓{C_N}" if q else f"{C_Y}⏳{C_N}"
                am = f"{C_G}✓{C_N}" if a else f"{C_Y}⏳{C_N}"
                print(_kv("  Кворум", f"{t.get('participated_weight',0)}/{t.get('quorum_needed',0)} {qm}"))
                print(_kv("  Схвалення", f"{t.get('approval_percent',0)}% {am}"))
                print(_kv("  За", f"{t['yes']['count']} голосів · вага {t['yes']['weight']}"))
                print(_kv("  Проти", f"{t['no']['count']} · вага {t['no']['weight']}"))
                print(_kv("  Утримались", f"{t['abstain']['count']} · вага {t['abstain']['weight']}"))
            if p.get("veto"):
                v = p["veto"]
                print(f"  {C_R}🚨 VETO: {v.get('reason','—')}{C_N}")
            if p.get("votes"):
                print(f"  {C_D}Голоси:{C_N}")
                for v in p["votes"]:
                    choice_emoji = {"yes":"✅","no":"❌","abstain":"➖"}.get(v["choice"],"•")
                    print(f"    {choice_emoji} {v['voter'][:14]}…  {v.get('ts','')}")

    # ── ВИКОНАННЯ ──
    print(_sec("3 · ВИКОНАННЯ (7 рівнів)"))
    ex = d["execution"]
    if not ex:
        print(f"  {C_D}стан виконання відсутній{C_N}")
    else:
        bar_w = 40
        filled = int(bar_w * ex["progress"] / 100)
        bar = "█"*filled + "░"*(bar_w-filled)
        print(f"  {C_G}{bar}{C_N}  {ex['progress']}%  ({ex['done']}/{ex['total']})")
        print()
        for i in range(1, 8):
            l = ex["levels"][i]
            mk = f"{C_G}✓{C_N}" if l["ok"] else f"{C_Y}○{C_N}"
            by = f"{C_D}{l['by']} @ {l['at']}{C_N}" if l["at"] else ""
            print(f"  {mk} L{i} · {l['name']:40s} {by}")
        if ex.get("next_action"):
            print(f"\n  {C_Y}→ Далі:{C_N} {ex['next_action']}")

    # ── ПЛАН ──
    if d["plan"]:
        print(_sec("4 · ПЛАН"))
        print(_kv("Тип", f"{d['plan']['type']} ({d['plan']['type_name']})"))
        for s in d["plan"]["steps"]:
            payload_str = json.dumps(s["payload"], ensure_ascii=False)
            print(f"  L{s['level']}  [{s['executor']:10s}]  {C_D}{_trunc(payload_str, 50)}{C_N}")

    # ── ВІДХИЛЕННЯ ──
    devs = d["deviations"]
    if devs:
        print(_sec("5 · ВІДХИЛЕННЯ"))
        for dev in devs[-10:]:
            act = dev.get("action","?")
            color = {"accept":C_G, "vote":C_Y, "auto_replace":C_M,
                     "reject":C_R, "auto_reject":C_R}.get(act, C_D)
            print(f"  {color}[{act:12s}]{C_N}  L{dev.get('level')}  "
                  f"expected={dev.get('expected')} actual={dev.get('actual')} "
                  f"dev={dev.get('deviation_pct')}%")

    # ── TX ПЛАНИ ──
    if d["tx_plans"]:
        print(_sec("6 · TX ПЛАНИ"))
        for t in d["tx_plans"]:
            print(f"  {C_B}{t['kind']}{C_N}")
            for k, v in t["plan"].items():
                print(f"    {k:14s} {v}")

    # ── БЕКАПИ ──
    if d["backups"]:
        print(_sec("7 · БЕКАПИ"))
        for b in d["backups"]:
            print(f"  {b['mtime']}  {b['size']:>8} B  {_trunc(b['path'], 45)}")

    # ── ПРОТОКОЛИ ──
    if d["protocols"]:
        print(_sec("8 · ПРОТОКОЛИ"))
        for pr in d["protocols"]:
            print(f"  {pr['size']:>8} B  {_trunc(pr['path'], 55)}")

    # ── АУДИТ (stream) ──
    if d["stream"]:
        print(_sec("9 · СТРІМ ПОДІЙ (останні)"))
        for e in d["stream"][-12:]:
            lv = e.get("level","?")[:4].upper()
            color = {"INFO":C_D, "WARN":C_Y, "ERRO":C_R, "CRIT":C_R}.get(lv, C_D)
            print(f"  {color}[{lv:4s}]{C_N} {e.get('cat','?'):9s} "
                  f"{_trunc(e.get('ev',''), 40):42s} {e.get('ts','')}")

    # ── ДІЇ ──
    if d["actions"]:
        print(_sec("10 · ДІЇ ПАРЛАМЕНТУ"))
        for a in d["actions"][-10:]:
            mk = f"{C_G}✓{C_N}" if a.get("ok") else f"{C_R}✗{C_N}"
            print(f"  {mk} [{a.get('level','?'):5s}] {a.get('action','?'):24s} "
                  f"{_trunc(a.get('msg',''), 40)}")

    # ── ПІДСУМОК ──
    print(f"\n{C_B}{'═'*78}{C_N}")
    h = d["_dossier_hash"]
    print(f"  {C_D}Hash дос'є (SHA-256):{C_N} {h}")
    print(f"  {C_D}Збережено в: modules/module_121_parlament/data/executions/{cid}_dossier.json{C_N}")
    print(f"{C_B}{'═'*78}{C_N}\n")

# ─── CLI ────────────────────────────────────────────────────
def list_contracts():
    """Усі відомі CID з усіх джерел."""
    cids = set()
    # .sig файли
    ev = H / "modules/module_19_contract_tui_menu/evidence"
    if ev.exists():
        for f in ev.glob("*_buyer.sig"):
            cids.add(f.stem.replace("_buyer",""))
    # executions
    ex = D / "data" / "executions"
    if ex.exists():
        for f in ex.glob("C-*.json"):
            cids.add(f.stem)
    # proposals
    try:
        import parliament as P
        for p in P.proposals():
            pl = p.get("payload") or {}
            if pl.get("cid"): cids.add(pl["cid"])
    except Exception: pass
    return sorted(cids, reverse=True)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: dossier.py <cid> | list")
        sys.exit(1)
    if sys.argv[1] == "list":
        for c in list_contracts(): print(c)
    elif sys.argv[1] == "json":
        d = render(sys.argv[2], out_console=False, save=False)
        print(json.dumps(d, indent=2, ensure_ascii=False, default=str))
    else:
        render(sys.argv[1])
