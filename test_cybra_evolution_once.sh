#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p logs/evolution posts feeds proofs

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

TASK="$(python3 - <<'PY'
import json, time
print(json.dumps({
  "topic": "CYBRA Evolution Pass Test",
  "type": "evolution_guard_task",
  "priority": "high",
  "payload": {
    "mode": "evolution_pass_test",
    "goal": "розвиток audit proof revision analytics education security stability recovery mapping documentation",
    "diagnostic_run": int(time.time()),
    "expected": "approved_by_evolution_guard"
  }
}, ensure_ascii=False))
PY
)"

echo "=== 1. EVOLUTION INSPECT ==="
python3 cybra_evolution_guard.py inspect "$TASK" | tee logs/evolution/evolution_once_inspect.log

echo
echo "=== 2. EVOLUTION DECISION ==="
cat feeds/evolution_guard_status.json | grep -E '"decision"|"score"|"topic"|"type"' || true

DECISION="$(python3 - <<'PY'
import json
from pathlib import Path
p=Path("feeds/evolution_guard_status.json")
d=json.loads(p.read_text())
print(d.get("decision"))
PY
)"

echo "DECISION=$DECISION"

if [ "$DECISION" != "approved" ]; then
  echo "❌ Evolution did not pass. Check posts/evolution_guard_status.md"
  cat posts/evolution_guard_status.md
  exit 1
fi

echo
echo "=== 3. SUBMIT THROUGH EVOLUTION GUARD ==="
python3 cybra_evolution_guard.py submit "$TASK" | tee logs/evolution/evolution_once_submit.log

echo
echo "=== 4. RUN WORKER ==="
cybra worker-start || true
sleep 8

echo
echo "=== 5. STATUS ==="
cybra status
bash cybra_evolution.sh status

echo
echo "=== 6. RESULTS ==="
cybra results | head -10

echo
echo "=== 7. REPORT ==="
bash cybra_evolution.sh report | head -80

echo
echo "=== 8. DIAGNOSTICS ==="
bash cybra_task_test_diagnostics.sh report | head -120

echo
echo "✅ EVOLUTION TEST FINISHED"
