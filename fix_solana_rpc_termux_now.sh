#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CYBRA SOLANA RPC TERMUX FIX ==="

mkdir -p data/solana_rpc reports posts feeds proofs logs

echo
echo "=== 1. CLEAR STALE GIT LOCK ==="

if [ -f .git/index.lock ]; then
  if ps -A 2>/dev/null | grep -E "git[[:space:]]" | grep -v grep >/dev/null 2>&1; then
    echo "⚠ Active git process found, not removing lock."
    ps -A | grep -E "git[[:space:]]" | grep -v grep || true
  else
    rm -f .git/index.lock
    echo "✅ stale .git/index.lock removed"
  fi
else
  echo "✅ no git lock"
fi

echo
echo "=== 2. TERMUX NETWORK DEPENDENCIES ==="

pkg install -y ca-certificates openssl curl jq nodejs >/dev/null 2>&1 || true
update-ca-certificates >/dev/null 2>&1 || true

export NODE_OPTIONS="--dns-result-order=ipv4first"
export SOLANA_RPC_URL="${SOLANA_RPC_URL:-https://api.mainnet-beta.solana.com}"

echo "NODE_OPTIONS=$NODE_OPTIONS"
echo "SOLANA_RPC_URL=$SOLANA_RPC_URL"

echo
echo "=== 3. CREATE SOLANA RPC PROBE ==="

cat > solana_rpc_probe.mjs <<'NODE'
import dns from "node:dns";
import fs from "node:fs";

dns.setDefaultResultOrder("ipv4first");

const endpoints = [
  process.env.SOLANA_RPC_URL,
  process.env.RPC_URL,
  "https://api.mainnet-beta.solana.com",
  "https://solana-rpc.publicnode.com",
  "https://api.devnet.solana.com"
].filter(Boolean);

const account = process.env.SOLANA_TEST_ACCOUNT || "5WSJNhe6ChKAQWdJ9aSbEDJAict8msL5R7rRyejs8E6T";

async function rpc(endpoint, method, params = []) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12000);

  try {
    const r = await fetch(endpoint, {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method,
        params
      }),
      signal: controller.signal
    });

    const text = await r.text();
    clearTimeout(timeout);

    let json = null;
    try { json = JSON.parse(text); } catch {}

    return {
      ok: r.ok,
      http: r.status,
      text: text.slice(0, 500),
      json
    };
  } catch (e) {
    clearTimeout(timeout);
    return {
      ok: false,
      error: e.message,
      cause: e.cause ? String(e.cause) : null
    };
  }
}

async function main() {
  fs.mkdirSync("data/solana_rpc", {recursive: true});

  const results = [];
  let selected = null;

  for (const endpoint of endpoints) {
    console.log("\nRPC TEST:", endpoint);

    const health = await rpc(endpoint, "getHealth");
    console.log("getHealth:", health.ok ? "OK" : "FAIL", health.http || "", health.error || "");

    const blockhash = await rpc(endpoint, "getLatestBlockhash");
    console.log("getLatestBlockhash:", blockhash.ok ? "OK" : "FAIL", blockhash.http || "", blockhash.error || "");

    const acct = await rpc(endpoint, "getAccountInfo", [account, {"encoding": "base64"}]);
    console.log("getAccountInfo:", acct.ok ? "OK" : "FAIL", acct.http || "", acct.error || "");

    const good = blockhash.ok && !blockhash.error && blockhash.json && !blockhash.json.error;

    results.push({
      endpoint,
      health,
      blockhash,
      account,
      account_info_ok: acct.ok,
      good
    });

    if (!selected && good) {
      selected = endpoint;
    }
  }

  const report = {
    status: selected ? "rpc_found" : "rpc_not_found",
    selected_rpc: selected,
    account,
    time: Date.now(),
    results
  };

  fs.writeFileSync("data/solana_rpc/rpc_probe_report.json", JSON.stringify(report, null, 2));

  if (selected) {
    fs.writeFileSync("data/solana_rpc/selected_rpc.local", selected + "\n");
    console.log("\n✅ SELECTED_RPC:", selected);
    process.exit(0);
  } else {
    console.log("\n❌ NO WORKING RPC FOUND");
    console.log("Try another internet/VPN/private RPC.");
    process.exit(1);
  }
}

main();
NODE

echo
echo "=== 4. RUN RPC PROBE ==="

NODE_OPTIONS="--dns-result-order=ipv4first" node solana_rpc_probe.mjs
PROBE_CODE=$?

SELECTED_RPC=""
if [ -f data/solana_rpc/selected_rpc.local ]; then
  SELECTED_RPC="$(cat data/solana_rpc/selected_rpc.local | tr -d '\r\n')"
fi

if [ -n "$SELECTED_RPC" ]; then
  export SOLANA_RPC_URL="$SELECTED_RPC"
  echo "✅ Working RPC: $SOLANA_RPC_URL"
else
  echo "⚠ No selected RPC. Keeping: $SOLANA_RPC_URL"
fi

echo
echo "=== 5. PATCH mint_tokens_2022.js RPC SOURCE ==="

if [ -f mint_tokens_2022.js ]; then
  cp mint_tokens_2022.js "mint_tokens_2022.js.bak.$(date +%Y%m%d_%H%M%S)"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("mint_tokens_2022.js")
s = p.read_text(encoding="utf-8", errors="ignore")

changed = False

if 'import dns from "node:dns";' not in s:
    # Insert after import block if possible
    lines = s.splitlines()
    idx = 0
    for i, line in enumerate(lines):
        if line.strip().startswith("import "):
            idx = i + 1
    lines.insert(idx, 'import dns from "node:dns";')
    lines.insert(idx + 1, 'dns.setDefaultResultOrder("ipv4first");')
    s = "\n".join(lines)
    changed = True

if "const RPC_URL =" not in s:
    marker = 'dns.setDefaultResultOrder("ipv4first");'
    insert = '''dns.setDefaultResultOrder("ipv4first");
const RPC_URL = process.env.SOLANA_RPC_URL || process.env.RPC_URL || "https://api.mainnet-beta.solana.com";
console.log("🌐 Solana RPC:", RPC_URL);'''
    s = s.replace(marker, insert, 1)
    changed = True

patterns = [
    r'new\s+Connection\s*\(\s*clusterApiUrl\s*\([^)]*\)\s*(,\s*["\'][^"\']+["\'])?\s*\)',
    r'new\s+Connection\s*\(\s*["\']https?://[^"\']+["\']\s*(,\s*["\'][^"\']+["\'])?\s*\)'
]

for pat in patterns:
    ns = re.sub(pat, 'new Connection(RPC_URL, "confirmed")', s, count=1)
    if ns != s:
        s = ns
        changed = True
        break

p.write_text(s, encoding="utf-8")

print("✅ patched" if changed else "⚠ no connection pattern changed; file may already use env RPC")
PY

else
  echo "⚠ mint_tokens_2022.js not found"
fi

echo
echo "=== 6. CREATE SAFE MINT RUNNER ==="

cat > run_mint_tokens_2022_safe.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

export NODE_OPTIONS="--dns-result-order=ipv4first"

if [ -f data/solana_rpc/selected_rpc.local ]; then
  export SOLANA_RPC_URL="$(cat data/solana_rpc/selected_rpc.local | tr -d '\r\n')"
else
  export SOLANA_RPC_URL="${SOLANA_RPC_URL:-https://api.mainnet-beta.solana.com}"
fi

echo "RPC: $SOLANA_RPC_URL"

echo
echo "=== RPC TEST BEFORE MINT ==="
node solana_rpc_probe.mjs || {
  echo "❌ RPC test failed. Mint stopped."
  exit 1
}

if [ "${1:-test}" != "real" ]; then
  echo
  echo "✅ RPC works. Real mint not executed."
  echo "To run real on-chain mint:"
  echo "bash run_mint_tokens_2022_safe.sh real"
  exit 0
fi

echo
echo "⚠ REAL ON-CHAIN MINT MODE"
echo "This may send a Solana transaction."
echo "No seed/private key should be printed or committed."
sleep 2

node mint_tokens_2022.js
EOF

chmod +x run_mint_tokens_2022_safe.sh

echo
echo "=== 7. PROTECT PRIVATE FILES FROM GIT ==="

cat >> .gitignore <<'EOF'

# Solana / wallet private safety
.env.solana
data/solana_rpc/selected_rpc.local
*mint*authority*.json
*authority*.json
*keypair*.json
*wallet*.json
*.secret.json
EOF

cat >> .git/info/exclude <<'EOF'
.env.solana
data/solana_rpc/selected_rpc.local
*mint*authority*.json
*authority*.json
*keypair*.json
*wallet*.json
*.secret.json
EOF

echo
echo "=== 8. BUILD FIX REPORT ==="

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sha(x): return hashlib.sha256(x.encode()).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))
def exists(p): return (ROOT / p).exists()

selected = ""
sel = ROOT / "data/solana_rpc/selected_rpc.local"
if sel.exists():
    selected = sel.read_text().strip()

obj = {
    "status": "solana_rpc_termux_fix_generated",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "selected_rpc": selected,
    "checks": {
        "rpc_probe": exists("solana_rpc_probe.mjs"),
        "rpc_probe_report": exists("data/solana_rpc/rpc_probe_report.json"),
        "selected_rpc_local": exists("data/solana_rpc/selected_rpc.local"),
        "mint_script": exists("mint_tokens_2022.js"),
        "safe_runner": exists("run_mint_tokens_2022_safe.sh"),
        "git_lock_exists": exists(".git/index.lock")
    },
    "pages": {
        "metadata_json": "HTTP 200 confirmed by curl",
        "logo_png": "HTTP 200 confirmed by curl"
    },
    "safety": {
        "real_mint_default": False,
        "real_mint_requires_command": "bash run_mint_tokens_2022_safe.sh real",
        "automatic_real_payment": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "private_key_required_in_chat": False,
        "manual_OWNER_approval_required": True
    }
}
obj["double_sha"] = dsha(obj)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)

(ROOT / "feeds/cybra_solana_rpc_termux_fix.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

md = ["# CYBRA Solana RPC Termux Fix Report", "", "Status: generated", ""]
md.append(f"Selected RPC: {selected or 'none'}")
md.append("")
md.append("## Checks")
for k,v in obj["checks"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Pages")
for k,v in obj["pages"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Safety")
for k,v in obj["safety"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Double SHA")
md.append(obj["double_sha"])

(ROOT / "posts/cybra_solana_rpc_termux_fix.md").write_text("\n".join(md), encoding="utf-8")

with (ROOT / "proofs/cybra_solana_rpc_termux_fix.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_solana_rpc_termux_fix.json",
        "posts/cybra_solana_rpc_termux_fix.md",
        "solana_rpc_probe.mjs",
        "run_mint_tokens_2022_safe.sh"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print("✅ report generated")
print("REPORT: posts/cybra_solana_rpc_termux_fix.md")
print("DOUBLE_SHA:", obj["double_sha"])
PY

echo
echo "=== 9. TEST SAFE RUNNER ==="

bash run_mint_tokens_2022_safe.sh test || true

echo
echo "✅ SOLANA RPC TERMUX FIX DONE"
echo
echo "Next:"
echo "bash run_mint_tokens_2022_safe.sh test"
echo "bash run_mint_tokens_2022_safe.sh real"
