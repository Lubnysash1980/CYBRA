#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/executor_mapping

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1
redis-cli ping >/dev/null

MAP_KEY="cybra:executor:mapping"
AUDIT_KEY="cybra:executor:mapping:audit"

case "${1:-load}" in
  load)
    python3 - <<'PY'
import ast, json, subprocess, time
from pathlib import Path

MAP_KEY = "cybra:executor:mapping"
AUDIT_KEY = "cybra:executor:mapping:audit"

p = Path("parliament_executor_v6.py")
s = p.read_text()

tree = ast.parse(s)
mapping = {}

for node in tree.body:
    if isinstance(node, ast.Assign):
        for t in node.targets:
            if isinstance(t, ast.Name) and t.id == "SCRIPT_MAP":
                mapping = ast.literal_eval(node.value)

# force important mappings
force = {
    "air_alert_task": "air_alert_handler.sh",
    "cybra_autofix_task": "cybra_autofix.sh",
}
mapping.update(force)

for task_type, script in mapping.items():
    subprocess.run(["redis-cli", "HSET", MAP_KEY, str(task_type), str(script)], check=True)

event = {
    "time": time.time(),
    "status": "loaded",
    "map_key": MAP_KEY,
    "count": len(mapping),
    "mapping": mapping,
}
subprocess.run(["redis-cli", "LPUSH", AUDIT_KEY, json.dumps(event, ensure_ascii=False)], check=True)

Path("feeds").mkdir(exist_ok=True)
Path("posts").mkdir(exist_ok=True)
Path("proofs").mkdir(exist_ok=True)

Path("feeds/executor_mapping.json").write_text(json.dumps(event, ensure_ascii=False, indent=2))
Path("posts/executor_mapping_status.md").write_text(
    "# CYBRA Redis Executing Mapping\n\n"
    f"Status: loaded\n\n"
    f"Redis key: `{MAP_KEY}`\n\n"
    f"Mappings: {len(mapping)}\n"
)

print("✅ Redis executor mapping loaded:", len(mapping))
PY

    sha256sum feeds/executor_mapping.json posts/executor_mapping_status.md > proofs/executor_mapping.sha256
    ;;

  list)
    redis-cli HGETALL "$MAP_KEY"
    ;;

  get)
    redis-cli HGET "$MAP_KEY" "$2"
    ;;

  set)
    if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
      echo "Usage: bash cybra_redis_executor_mapping.sh set <task_type> <script.sh>"
      exit 1
    fi
    redis-cli HSET "$MAP_KEY" "$2" "$3"
    redis-cli LPUSH "$AUDIT_KEY" "{\"status\":\"set\",\"type\":\"$2\",\"script\":\"$3\",\"time\":\"$(date -Iseconds)\"}"
    echo "✅ mapping set: $2 -> $3"
    ;;

  audit)
    redis-cli LRANGE "$AUDIT_KEY" 0 20
    ;;

  *)
    echo "Usage:"
    echo "  bash cybra_redis_executor_mapping.sh load"
    echo "  bash cybra_redis_executor_mapping.sh list"
    echo "  bash cybra_redis_executor_mapping.sh get air_alert_task"
    echo "  bash cybra_redis_executor_mapping.sh set task_type script.sh"
    echo "  bash cybra_redis_executor_mapping.sh audit"
    exit 1
    ;;
esac
