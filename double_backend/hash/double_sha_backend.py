import hashlib, json, time
from pathlib import Path

def double_sha_bytes(data: bytes) -> str:
    return hashlib.sha256(hashlib.sha256(data).digest()).hexdigest()

def double_sha_text(text: str) -> str:
    return double_sha_bytes(text.encode())

def write_double_backend_record(task, result=None):
    Path("double_backend/audit").mkdir(parents=True, exist_ok=True)
    raw = json.dumps({
        "time": time.time(),
        "task": task,
        "result": result
    }, ensure_ascii=False, indent=2)
    h = double_sha_text(raw)
    Path(f"double_backend/audit/{h}.json").write_text(raw, encoding="utf-8")
    return h
