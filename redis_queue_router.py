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
