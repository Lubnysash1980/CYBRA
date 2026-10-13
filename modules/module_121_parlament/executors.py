#!/usr/bin/env python3
"""Виконавці кроків контракту. Кожен вміє:
  - can(cid, payload)  → чи може він це зробити зараз
  - run(cid, payload)  → виконує і повертає (ok, msg, output)
Реєстр — глобальний словник EXECUTORS."""
import json, time, subprocess, os, sys, hashlib
from pathlib import Path

H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

# ── базовий клас ────────────────────────────────────────────
class Executor:
    id = "base"; name = "Base"; level = 0  # 0 = будь-який
    def can(self, cid, payload): return True, "ok"
    def run(self, cid, payload): return False, "not implemented", {}
    def __repr__(self): return f"<Executor {self.id}>"

# ── 1. SIGN ─────────────────────────────────────────────────
class SignExecutor(Executor):
    id = "sign"; name = "Підписання"; level = 1
    def can(self, cid, payload):
        sig = H / f"modules/module_19_contract_tui_menu/evidence/{cid}_buyer.sig"
        if sig.exists(): return True, "sig exists"
        return True, "треба підписати через 108"
    def run(self, cid, payload):
        sig = H / f"modules/module_19_contract_tui_menu/evidence/{cid}_buyer.sig"
        if sig.exists():
            return True, "вже підписано", {"sig": str(sig)}
        # викликати 108
        r = subprocess.run(["bash",
            str(H/"modules/module_108_metamask_sign/main.sh")],
            capture_output=True, text=True, timeout=900)
        ok = r.returncode == 0
        return ok, "108 завершився" if ok else r.stderr[:200], {}

# ── 2. ESCROW (через 114) ───────────────────────────────────
class EscrowExecutor(Executor):
    id = "escrow"; name = "Блокування коштів"; level = 2
    def can(self, cid, payload):
        amt = payload.get("amount_bnb", 0)
        addr = payload.get("from")
        if amt <= 0: return False, "сума не вказана"
        if not addr: return False, "адреса не вказана"
        return True, f"{amt} BNB від {addr[:10]}…"
    def run(self, cid, payload):
        # підготовка TX; підпис через MetaMask (не автоматично!)
        plan = {
            "action": "send_bnb",
            "from": payload.get("from"),
            "to": payload.get("to"),
            "amount_bnb": payload.get("amount_bnb"),
            "chain_id": payload.get("chain_id", 56),
            "cid": cid,
        }
        # зберігаємо у черзі — підписує людина через 108/QR
        q = D / "data" / "executions" / f"{cid}_pending_tx.json"
        q.write_text(json.dumps(plan, indent=2, ensure_ascii=False))
        return True, f"TX готується: {q.name}", {"plan": plan}

# ── 3. NOTIFY (через alerts) ─────────────────────────────────
class NotifyExecutor(Executor):
    id = "notify"; name = "Оповіщення"; level = 3
    def can(self, cid, payload): return True, "завжди"
    def run(self, cid, payload):
        try:
            import alerts
            alerts.send("proposal_created",
                        f"Контракт {cid}: {payload.get('msg','крок досягнуто')}",
                        payload.get("extra",""))
            return True, "надіслано", {}
        except Exception as e:
            return False, f"alert: {e}", {}

# ── 4. VERIFY (deliverable) ─────────────────────────────────
class VerifyExecutor(Executor):
    id = "verify"; name = "Перевірка deliverable"; level = 4
    def can(self, cid, payload):
        if not payload.get("proof"): return False, "немає proof"
        return True, "ok"
    def run(self, cid, payload):
        proof = payload.get("proof")
        expected = payload.get("expected_hash")
        if expected:
            h = hashlib.sha256(proof.encode() if isinstance(proof,str) else proof).hexdigest()
            if h != expected:
                return False, f"hash mismatch: {h[:12]}… != {expected[:12]}…", {"actual": h}
        return True, "verified", {"hash": h if expected else None}

# ── 5. DEVIATION (3%) ───────────────────────────────────────
class DeviationExecutor(Executor):
    id = "deviation"; name = "Перевірка відхилення 3%"; level = 5
    def can(self, cid, payload):
        if payload.get("expected") is None: return False, "немає expected"
        if payload.get("actual") is None: return False, "немає actual"
        return True, "ok"
    def run(self, cid, payload):
        exp = float(payload["expected"]); act = float(payload["actual"])
        if exp == 0: return False, "expected=0", {}
        dev = abs(act - exp) / exp * 100
        threshold = float(payload.get("threshold", 3.0))
        result = {"expected": exp, "actual": act, "deviation_pct": round(dev, 4),
                  "threshold": threshold}
        if dev > threshold:
            try:
                import hooks
                hooks.fire("deviation", cid=cid, level=5, payload=result)
            except Exception: pass
            # автозаміна — якщо є replacement
            repl = payload.get("replacement")
            if repl:
                result["action"] = "auto_replace"
                result["replacement"] = repl
                return True, f"відхилення {dev:.2f}% > {threshold}% → автозаміна", result
            return False, f"відхилення {dev:.2f}% > {threshold}%", result
        return True, f"відхилення {dev:.2f}% ≤ {threshold}%", result

# ── 6. WAIT (dispute window) ────────────────────────────────
class WaitExecutor(Executor):
    id = "wait"; name = "Очікування вікна"; level = 6
    def can(self, cid, payload): return True, "auto"
    def run(self, cid, payload):
        sec = int(payload.get("window_sec", 3600))
        return True, f"очікування {sec}s (auto через verify_7.advance)", {"window_sec": sec}

# ── 7. RELEASE ──────────────────────────────────────────────
class ReleaseExecutor(Executor):
    id = "release"; name = "Розблокування коштів"; level = 7
    def can(self, cid, payload): return True, "готово"
    def run(self, cid, payload):
        # підготовка фінальної TX
        plan = {"action": "release_escrow", "cid": cid,
                "to": payload.get("seller"),
                "amount_bnb": payload.get("amount_bnb")}
        q = D / "data" / "executions" / f"{cid}_release_tx.json"
        q.write_text(json.dumps(plan, indent=2, ensure_ascii=False))
        return True, f"release TX готово: {q.name}", {"plan": plan}

# ── реєстр ──────────────────────────────────────────────────
EXECUTORS = {
    e.id: e() for e in [
        SignExecutor, EscrowExecutor, NotifyExecutor, VerifyExecutor,
        DeviationExecutor, WaitExecutor, ReleaseExecutor,
    ]
}

def by_level(lvl):
    """Повертає екзекуторів, які підходять для рівня."""
    return [e for e in EXECUTORS.values() if e.level in (0, lvl)]

def run(executor_id, cid, payload=None):
    e = EXECUTORS.get(executor_id)
    if not e: return False, f"немає екзекутора {executor_id}", {}
    ok, why = e.can(cid, payload or {})
    if not ok: return False, f"can: {why}", {}
    ok, msg, out = e.run(cid, payload or {})
    # stream + hooks
    try:
        import stream, hooks
        stream.system("executor_run" if ok else "executor_fail",
                      {"id": executor_id, "cid": cid, "msg": msg[:120]},
                      level="info" if ok else "warn")
        hooks.fire("executor_done" if ok else "executor_fail",
                   cid=cid, executor=executor_id, msg=msg)
    except Exception: pass
    return ok, msg, out

if __name__ == "__main__":
    if len(sys.argv) < 3: print("usage: executors.py <id> <cid> [json_payload]"); sys.exit(1)
    eid, cid = sys.argv[1], sys.argv[2]
    p = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
    ok, msg, out = run(eid, cid, p)
    print(json.dumps({"ok": ok, "msg": msg, "out": out}, indent=2, ensure_ascii=False))
