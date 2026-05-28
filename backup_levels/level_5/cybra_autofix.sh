#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE"/{pmz,proofs,posts,site/assets,native_tokens,mainnet,registry,logs/executor}

echo "=== CYBRA AUTOFIX START ==="

# PMZ script
cat > "$BASE/create_pmz_registry.sh" <<'PMZ'
#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE/pmz" "$BASE/proofs" "$BASE/posts"

cat > "$BASE/pmz/pmz_manifest.json" <<JSON
{
  "system": "CYBRA PMZ",
  "purpose": "historical metadata and proof registry",
  "sources": [
    "https://lubnysash1980.github.io/Alfapay/metadata.json",
    "native_tokens",
    "mainnet",
    "proofs",
    "posts",
    "site"
  ],
  "status": "created"
}
JSON

find "$BASE/native_tokens" "$BASE/mainnet" "$BASE/proofs" "$BASE/posts" "$BASE/site" -type f 2>/dev/null -exec sha256sum {} \; > "$BASE/pmz/proof_hashes.txt"

cat > "$BASE/pmz/history_index.json" <<JSON
{
  "history_layers": [
    "genesis",
    "metadata",
    "proofs",
    "ai_parliament_decisions",
    "status_posts"
  ],
  "proof_file": "pmz/proof_hashes.txt"
}
JSON

cat > "$BASE/posts/pmz_status.md" <<MD
# CYBRA PMZ Status

PMZ historical metadata registry created.

Files:
- pmz/pmz_manifest.json
- pmz/history_index.json
- pmz/proof_hashes.txt
MD

echo "✅ PMZ registry created"
PMZ
chmod +x "$BASE/create_pmz_registry.sh"

# Native token script if missing
if [ ! -f "$BASE/create_native_token_ecosystem.sh" ]; then
cat > "$BASE/create_native_token_ecosystem.sh" <<'NATIVE'
#!/data/data/com.termux/files/usr/bin/bash
set -e
BASE="$HOME/CYBRA"
OWNER="FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y"

mkdir -p "$BASE/native_tokens/CYBRA"/{chain,pools,metadata,proofs}
mkdir -p "$BASE/proofs" "$BASE/site" "$BASE/posts"

cat > "$BASE/native_tokens/CYBRA/metadata/token.json" <<JSON
{"symbol":"CYBRA","name":"CYBRA Native Coin","model":"native_chain_no_mint_account","owner_wallet":"$OWNER","genesis_supply":1000000,"proof":"sha256","status":"created"}
JSON

cat > "$BASE/native_tokens/CYBRA/chain/genesis.json" <<JSON
{"index":0,"type":"genesis","symbol":"CYBRA","owner_wallet":"$OWNER","supply":1000000}
JSON

cat > "$BASE/native_tokens/CYBRA/pools/pools.json" <<JSON
{"reserve_pool":400000,"liquidity_pool":300000,"work_pool":200000,"reward_pool":100000}
JSON

find "$BASE/native_tokens/CYBRA" -type f -exec sha256sum {} \; > "$BASE/proofs/native_tokens_hashes.txt"

cat > "$BASE/posts/native_token_status.md" <<MD
# CYBRA Native Token Status

CYBRA Native Coin created.
Owner wallet: $OWNER
Supply: 1000000
MD

echo "✅ Native token ecosystem created"
NATIVE
chmod +x "$BASE/create_native_token_ecosystem.sh"
fi

# Executor v3
cat > "$BASE/parliament_executor_v3.py" <<'PY'
import redis, json, time, hashlib, subprocess
from pathlib import Path

BASE = Path.home() / "CYBRA"
LOGS = BASE / "logs" / "executor"
LOGS.mkdir(parents=True, exist_ok=True)

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

Q_IN = "cybra:parliament:submissions"
Q_RESULTS = "cybra:parliament:results"
Q_FAILED = "cybra:parliament:failed"
Q_AUDIT = "cybra:audit"

ALLOWED = {
    "native_token_ecosystem_task": ["bash", "create_native_token_ecosystem.sh"],
    "pmz_historical_metadata_task": ["bash", "create_pmz_registry.sh"],
    "cybra_autofix_task": ["bash", "cybra_autofix.sh"],
    "promind_ai_evolution_task": ["bash", "-lc", "mkdir -p posts && echo '# ProMind accepted' > posts/promind_status_report.md"],
    "codespaces_remote_orchestration_task": ["bash", "-lc", "mkdir -p posts && echo '# Codespaces remote orchestration accepted' > posts/codespace_remote_status.md"]
}

def sha(x):
    return hashlib.sha256(x.encode()).hexdigest()

def execute(task):
    ttype = task.get("type", "generic")
    topic = task.get("topic", "unknown")
    cmd = ALLOWED.get(ttype)

    if not cmd:
        return {"topic": topic, "type": ttype, "status": "no_executor_mapping"}

    p = subprocess.run(cmd, cwd=str(BASE), text=True, capture_output=True, timeout=900)

    return {
        "topic": topic,
        "type": ttype,
        "status": "executed" if p.returncode == 0 else "execution_failed",
        "cmd": cmd,
        "returncode": p.returncode,
        "stdout": p.stdout[-3000:],
        "stderr": p.stderr[-3000:],
        "time": time.time()
    }

print("=== CYBRA PARLIAMENT EXECUTOR V3 STARTED ===")

while True:
    raw = r.rpop(Q_IN)
    if not raw:
        time.sleep(2)
        continue

    h = sha(raw)

    try:
        task = json.loads(raw)
        result = execute(task)
        result["hash"] = h
        (LOGS / f"{h}.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))
        r.lpush(Q_AUDIT, h)
        print("✅", result["status"], ":", result["topic"])
    except Exception as e:
        r.lpush(Q_FAILED, json.dumps({"raw": raw, "hash": h, "error": str(e)}, ensure_ascii=False))
        print("❌ FAILED:", h, e)
PY

# Report
cat > "$BASE/posts/autofix_report.md" <<MD
# CYBRA Autofix Report

Created/checked:
- create_pmz_registry.sh
- create_native_token_ecosystem.sh
- parliament_executor_v3.py
- pmz/
- proofs/
- posts/
- native_tokens/
- mainnet/
- site/

Next:
1. submit pmz task
2. submit native token task
3. run parliament_executor_v3.py
MD

git add create_pmz_registry.sh create_native_token_ecosystem.sh parliament_executor_v3.py posts/autofix_report.md pmz proofs posts site native_tokens mainnet 2>/dev/null || true
git commit -m "CYBRA autofix executor and PMZ registry" 2>/dev/null || true

echo "✅ CYBRA AUTOFIX DONE"
echo "Report: posts/autofix_report.md"
