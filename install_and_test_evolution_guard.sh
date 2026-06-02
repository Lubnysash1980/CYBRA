#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== INSTALL CYBRA EVOLUTION GUARD ==="

mkdir -p parliament/evolution private_vault/evolution posts feeds proofs logs/evolution

touch .gitignore
grep -qxF "private_vault/" .gitignore || echo "private_vault/" >> .gitignore
grep -qxF "__pycache__/" .gitignore || echo "__pycache__/" >> .gitignore
grep -qxF "dump.rdb" .gitignore || echo "dump.rdb" >> .gitignore
grep -qxF "ai_network/" .gitignore || echo "ai_network/" >> .gitignore
grep -qxF "recovery/" .gitignore || echo "recovery/" >> .gitignore
grep -qxF "token/runtime/rpc.env" .gitignore || echo "token/runtime/rpc.env" >> .gitignore

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

if [ ! -f private_vault/evolution/evolution_gate.token ]; then
  openssl rand -hex 32 > private_vault/evolution/evolution_gate.token
fi

if [ ! -f private_vault/evolution/internal_seal.token ]; then
  openssl rand -hex 48 > private_vault/evolution/internal_seal.token
fi

chmod 600 private_vault/evolution/*.token

GATE_SHA="$(sha256sum private_vault/evolution/evolution_gate.token | awk '{print $1}')"
SEAL_SHA="$(sha256sum private_vault/evolution/internal_seal.token | awk '{print $1}')"

cat > parliament/evolution/evolution_laws.json <<JSON
{
  "name": "CYBRA Evolution Guard",
  "status": "active",
  "mode": "evolution_only",
  "keys": {
    "external_gate_sha256": "$GATE_SHA",
    "internal_seal_sha256_only": "$SEAL_SHA",
    "internal_key_visible": false,
    "private_tokens_location": "private_vault/evolution/"
  },
  "rules": {
    "accept_development": true,
    "block_degradation": true,
    "audit_required": true,
    "proof_required": true,
    "lineage_required": true,
    "no_private_keys_in_git": true,
    "no_secret_dump": true
  }
}
JSON

cat > cybra_evolution_guard.py <<'PY'
#!/usr/bin/env python3
import json, time, hmac, hashlib, subprocess, sys
from pathlib import Path
import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

GATE = Path("private_vault/evolution/evolution_gate.token")
SEAL = Path("private_vault/evolution/internal_seal.token")

POSITIVE = [
    "розвиток", "еволюц", "audit", "аудит", "proof", "sha",
    "revision", "ревіз", "analytics", "аналіт", "education",
    "освіт", "security", "захист", "stability", "recovery",
    "mapping", "documentation", "handler", "test", "safe"
]

NEGATIVE = [
    "private key", "seed phrase", "password", "rm -rf /",
    "зламати", "вкрасти", "steal", "payment execution",
    "неконтрольована оплата", "секрети в git"
]

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def sign(path, msg):
    secret = path.read_text().strip().encode("utf-8")
    return hmac.new(secret, msg.encode("utf-8"), hashlib.sha256).hexdigest()

def score_task(task):
    raw = json.dumps(task, ensure_ascii=False).lower()
    score = 0
    pos = []
    neg = []

    for w in POSITIVE:
        if w.lower() in raw:
            score += 1
            pos.append(w)

    for w in NEGATIVE:
        if w.lower() in raw:
            score -= 5
            neg.append(w)

    if task.get("topic"):
        score += 1
    if task.get("type"):
        score += 1
    if task.get("payload"):
        score += 1

    decision = "approved" if score >= 4 and not neg else "hold"
    if score < 0:
        decision = "rejected"

    return score, decision, pos, neg

def write_status(event):
    Path("feeds").mkdir(exist_ok=True)
    Path("posts").mkdir(exist_ok=True)
    Path("proofs").mkdir(exist_ok=True)

    Path("feeds/evolution_guard_status.json").write_text(
        json.dumps(event, ensure_ascii=False, indent=2)
    )

    md = f"""# CYBRA Evolution Guard

Status: evolution_checked  
Decision: **{event["decision"]}**  
Topic: {event["topic"]}  
Type: {event["type"]}  
Score: {event["score"]}  
Fingerprint: `{event["fingerprint"]}`  
Gate signature: `{event["gate_signature"]}`  
Internal seal: `{event["internal_seal"]}`  
Time: {event["time_iso"]}

## Positive hits

{chr(10).join("- `" + x + "`" for x in event["positive_hits"]) or "- none"}

## Negative hits

{chr(10).join("- `" + x + "`" for x in event["negative_hits"]) or "- none"}
"""
    Path("posts/evolution_guard_status.md").write_text(md)

    subprocess.run(
        [
            "sha256sum",
            "feeds/evolution_guard_status.json",
            "posts/evolution_guard_status.md",
            "parliament/evolution/evolution_laws.json"
        ],
        stdout=open("proofs/evolution_guard_status.sha256", "w"),
        stderr=subprocess.DEVNULL
    )

def evaluate(raw, submit=False):
    r.ping()

    task = json.loads(raw)
    canon = json.dumps(task, ensure_ascii=False, sort_keys=True)
    fp = dsha(canon)

    score, decision, pos, neg = score_task(task)

    gate_sig = sign(GATE, fp + ":" + str(score))
    internal_seal = sign(SEAL, fp + ":" + decision)

    event = {
        "status": "evolution_checked",
        "decision": decision,
        "topic": task.get("topic"),
        "type": task.get("type"),
        "score": score,
        "fingerprint": fp,
        "gate_signature": gate_sig,
        "internal_seal": internal_seal,
        "internal_key_revealed": False,
        "positive_hits": pos,
        "negative_hits": neg,
        "time": time.time(),
        "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z")
    }

    task["_evolution"] = event
    enriched = json.dumps(task, ensure_ascii=False)

    if decision == "approved":
        r.lpush("cybra:evolution:approved", enriched)
        if submit:
            r.lpush("cybra:parliament:queue", enriched)
            event["submitted_to"] = "cybra:parliament:queue"
    elif decision == "hold":
        r.lpush("cybra:evolution:hold", enriched)
    else:
        r.lpush("cybra:evolution:rejected", enriched)

    r.lpush("cybra:evolution:audit", json.dumps(event, ensure_ascii=False))
    write_status(event)

    print(json.dumps(event, ensure_ascii=False, indent=2))

def report():
    audits = []
    for raw in r.lrange("cybra:evolution:audit", 0, 100):
        try:
            audits.append(json.loads(raw))
        except Exception:
            pass

    report = {
        "status": "generated",
        "audit_records": len(audits),
        "approved": r.llen("cybra:evolution:approved"),
        "hold": r.llen("cybra:evolution:hold"),
        "rejected": r.llen("cybra:evolution:rejected"),
        "latest": audits[:10],
        "time": time.time()
    }
    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    Path("feeds/evolution_guard_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))

    Path("posts/evolution_guard_report.md").write_text(
        "# CYBRA Evolution Guard Report\n\n"
        f"Status: generated\n\n"
        f"Approved queue: {report['approved']}\n\n"
        f"Hold queue: {report['hold']}\n\n"
        f"Rejected queue: {report['rejected']}\n\n"
        f"Audit records: {report['audit_records']}\n\n"
        f"Double SHA: `{report['double_sha']}`\n"
    )

    subprocess.run(
        ["sha256sum", "feeds/evolution_guard_report.json", "posts/evolution_guard_report.md"],
        stdout=open("proofs/evolution_guard_report.sha256", "w"),
        stderr=subprocess.DEVNULL
    )

    print("✅ evolution report generated")

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "inspect":
        evaluate(sys.argv[2], submit=False)
    elif cmd == "submit":
        evaluate(sys.argv[2], submit=True)
    elif cmd == "report":
        report()
    else:
        print("Usage: inspect '<json>' | submit '<json>' | report")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_evolution_guard.py

cat > evolution_guard_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_evolution_guard.py report
EOF2

chmod +x evolution_guard_handler.sh

cat > cybra_evolution.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  inspect)
    python3 cybra_evolution_guard.py inspect "$2"
    ;;
  submit)
    python3 cybra_evolution_guard.py submit "$2"
    ;;
  report)
    python3 cybra_evolution_guard.py report
    cat posts/evolution_guard_report.md
    ;;
  status)
    redis-cli ping
    echo "EVOLUTION_APPROVED: $(redis-cli LLEN cybra:evolution:approved)"
    echo "EVOLUTION_HOLD: $(redis-cli LLEN cybra:evolution:hold)"
    echo "EVOLUTION_REJECTED: $(redis-cli LLEN cybra:evolution:rejected)"
    echo "EVOLUTION_AUDIT: $(redis-cli LLEN cybra:evolution:audit)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/evolution_guard_status.md && echo "STATUS_REPORT: exists" || echo "STATUS_REPORT: missing"
    ;;
  *)
    echo "Usage: bash cybra_evolution.sh inspect|submit|report|status"
    ;;
esac
EOF2

chmod +x cybra_evolution.sh

redis-cli HSET cybra:executor:mapping evolution_guard_task evolution_guard_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"evolution_guard_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "evolution_guard_task": "evolution_guard_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ evolution_guard_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== RUN ONE EVOLUTION TEST ==="

TASK='{"topic":"CYBRA Evolution Pass Test","type":"evolution_guard_task","priority":"high","payload":{"mode":"evolution_pass_test","goal":"розвиток audit proof revision analytics education security stability recovery mapping documentation","expected":"approved_by_evolution_guard"}}'

python3 cybra_evolution_guard.py inspect "$TASK"

DECISION="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path("feeds/evolution_guard_status.json").read_text())
print(d.get("decision"))
PY
)"

echo "DECISION=$DECISION"

if [ "$DECISION" = "approved" ]; then
  python3 cybra_evolution_guard.py submit "$TASK"
  cybra worker-start || true
  sleep 8
else
  echo "❌ Evolution did not approve test task"
  cat posts/evolution_guard_status.md
  exit 1
fi

bash cybra_evolution.sh report
bash cybra_evolution.sh status
cybra status
cybra results | head -5

echo
echo "✅ EVOLUTION INSTALL AND TEST DONE"
