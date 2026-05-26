import json, hashlib, time
from pathlib import Path
from multiprocessing import Pool, cpu_count

BASE = Path.home() / "CYBRA"
GEN = BASE / "generated_scripts"
POSTS = BASE / "posts"
PROOFS = BASE / "proofs"

GEN.mkdir(exist_ok=True)
POSTS.mkdir(exist_ok=True)
PROOFS.mkdir(exist_ok=True)

def dsha(x: str) -> str:
    first = hashlib.sha256(x.encode()).digest()
    return hashlib.sha256(first).hexdigest()

def classify(task):
    text = json.dumps(task, ensure_ascii=False).lower()
    if "token" in text or "токен" in text:
        return "token"
    if "mining" in text or "майн" in text:
        return "mining"
    if "pmz" in text or "metadata" in text:
        return "pmz"
    if "codespace" in text or "github" in text:
        return "remote"
    return "generic"

def build_script(task):
    kind = classify(task)
    topic = task.get("topic", "unknown")
    name = f"generated_{dsha(topic)[:12]}.sh"
    path = GEN / name

    if kind == "token":
        body = "bash create_native_token_ecosystem.sh\n"
    elif kind == "mining":
        body = "bash cybra_mining_autofix.sh\n"
    elif kind == "pmz":
        body = "bash create_pmz_registry.sh\n"
    elif kind == "remote":
        body = "mkdir -p remote_queue && echo 'bash cybra_test_pipeline.sh' > remote_queue/auto_from_answer_engine.task\n"
    else:
        body = f"mkdir -p posts && echo '# Generated solution for {topic}' > posts/generated_solution.md\n"

    path.write_text("#!/data/data/com.termux/files/usr/bin/bash\nset -e\n" + body, encoding="utf-8")
    path.chmod(0o755)

    return str(path), kind

def multiprocess_plan(items):
    with Pool(min(cpu_count(), max(1, len(items)))) as p:
        return p.map(lambda x: x, items)

def expand(task):
    script, kind = build_script(task)
    proof = {
        "time": time.time(),
        "topic": task.get("topic"),
        "type": task.get("type"),
        "classified_as": kind,
        "generated_script": script,
        "double_sha": dsha(json.dumps(task, ensure_ascii=False))
    }

    (PROOFS / "self_expanding_engine_hashes.txt").write_text(json.dumps(proof, ensure_ascii=False, indent=2), encoding="utf-8")

    (POSTS / "self_expanding_engine_status.md").write_text(
        f"# CYBRA Self-Expanding Engine\n\nGenerated script: `{script}`\n\nClass: {kind}\n",
        encoding="utf-8"
    )

    return proof

if __name__ == "__main__":
    sample = {"topic": "self test", "type": "unknown"}
    print(json.dumps(expand(sample), ensure_ascii=False, indent=2))
