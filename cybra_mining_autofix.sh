#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p "$BASE/mining" "$BASE/pools" "$BASE/proofs" "$BASE/posts"

cat > "$BASE/mining/pool_registry.json" <<'JSON'
{
  "miner_pool": {},
  "reward_pool": 0,
  "difficulty": "owner_configurable_later",
  "emission": "unlimited_until_governance_rule_set",
  "status": "active_native_testnet"
}
JSON

cat > "$BASE/mining/mining_engine.py" <<'PY'
import json, time, hashlib
from pathlib import Path

BASE = Path.home() / "CYBRA"
CHAIN = BASE / "native_tokens" / "CYBRA" / "chain" / "blocks.json"
POOLS = BASE / "mining" / "pool_registry.json"
PROOF = BASE / "proofs" / "mining_hashes.txt"
POST = BASE / "posts" / "mining_status.md"

OWNER = "FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y"

def sha(x):
    return hashlib.sha256(x.encode()).hexdigest()

def load(path, default):
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return default

def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

chain = load(CHAIN, [])
pools = load(POOLS, {"miner_pool": {}, "reward_pool": 0})

reward = 50
block = {
    "index": len(chain),
    "time": time.time(),
    "type": "mined_block",
    "miner": OWNER,
    "reward": reward,
    "prev_hash": chain[-1]["hash"] if chain else "genesis"
}
block["hash"] = sha(json.dumps(block, sort_keys=True))

chain.append(block)
pools["reward_pool"] = int(pools.get("reward_pool", 0)) + reward
pools["miner_pool"][OWNER] = int(pools.get("miner_pool", {}).get(OWNER, 0)) + reward

save(CHAIN, chain)
save(POOLS, pools)

PROOF.write_text(
    f'{block["hash"]}  mined_block_{block["index"]}\n',
    encoding="utf-8"
)

POST.write_text(f"""# CYBRA Mining Status

Status: active  
Last block: {block["index"]}  
Miner: {OWNER}  
Reward: {reward} CYBRA  
Hash: {block["hash"]}

Mode: native-chain mining / testnet-first.
""", encoding="utf-8")

print("✅ MINED BLOCK", block["index"])
print(block["hash"])
PY

python3 "$BASE/mining/mining_engine.py"

git add mining proofs posts native_tokens 2>/dev/null || true
git commit -m "CYBRA smart mining autofix block" || true

echo "✅ Mining autofix executed"
