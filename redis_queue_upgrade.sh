#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs registry

cat > registry/redis_queues.json <<'JSON'
{
  "queues": {
    "critical": "cybra:parliament:queue:critical",
    "high": "cybra:parliament:queue:high",
    "normal": "cybra:parliament:queue:normal",
    "low": "cybra:parliament:queue:low",
    "processing": "cybra:parliament:processing",
    "results": "cybra:parliament:results",
    "failed": "cybra:parliament:failed",
    "retry": "cybra:parliament:retry",
    "audit": "cybra:audit",
    "dedup": "cybra:parliament:dedup"
  },
  "logic": {
    "priority_order": ["critical", "high", "normal", "low"],
    "max_retries": 3,
    "deduplication": true,
    "audit": true
  }
}
JSON

cat > redis_queue_router.py <<'PY'
import json, hashlib, time
import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

OLD = "cybra:parliament:submissions"
DEDUP = "cybra:parliament:dedup"

Q = {
    "critical": "cybra:parliament:queue:critical",
    "high": "cybra:parliament:queue:high",
    "normal": "cybra:parliament:queue:normal",
    "low": "cybra:parliament:queue:low"
}

def dsha(raw):
    first = hashlib.sha256(raw.encode()).digest()
    return hashlib.sha256(first).hexdigest()

moved = 0
skipped = 0

while True:
    raw = r.rpop(OLD)
    if not raw:
        break

    h = dsha(raw)

    if r.sismember(DEDUP, h):
        skipped += 1
        continue

    try:
        task = json.loads(raw)
        priority = task.get("priority", "normal")
        if priority not in Q:
            priority = "normal"
    except Exception:
        priority = "low"

    r.sadd(DEDUP, h)
    r.lpush(Q[priority], raw)
    moved += 1

print(json.dumps({"moved": moved, "skipped_duplicates": skipped}, ensure_ascii=False))
PY

cat > posts/redis_queue_upgrade_status.md <<'MD'
# CYBRA Redis Queue Upgrade

Added:
- priority queues
- dedup set
- retry queue
- processing queue
- failed queue
- audit queue

Priority order:
1. critical
2. high
3. normal
4. low
MD

sha256sum registry/redis_queues.json redis_queue_router.py posts/redis_queue_upgrade_status.md > proofs/redis_queue_upgrade_hashes.txt

git add registry redis_queue_router.py posts proofs redis_queue_upgrade.sh 2>/dev/null || true
git commit -m "add Redis priority queue logic" || true

echo "✅ Redis queue logic installed"
echo "Run router:"
echo "  python3 ~/CYBRA/redis_queue_router.py"
