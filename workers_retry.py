import redis, json, time, hashlib

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

print("=== CYBRA WORKER STARTED ===")

while True:
    raw = r.rpop("cybra:parliament:submissions")
    if not raw:
        time.sleep(2)
        continue

    h = hashlib.sha256(raw.encode()).hexdigest()

    try:
        task = json.loads(raw)
        result = {
            "topic": task.get("topic", "unknown"),
            "type": task.get("type", "generic"),
            "status": "processed",
            "hash": h,
            "time": time.time()
        }
        r.lpush("cybra:parliament:results", json.dumps(result, ensure_ascii=False))
        r.lpush("cybra:audit", h)
        print("✅ DONE:", result["topic"])

    except Exception as e:
        r.lpush("cybra:parliament:failed", json.dumps({"raw": raw, "error": str(e), "hash": h}, ensure_ascii=False))
        print("❌ FAILED:", h)
