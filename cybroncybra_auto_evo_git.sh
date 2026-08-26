#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

ROOT="$HOME/CYBRA"
DOMAIN="cybroncybra.com"
CONTRACT="0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f"
CHAIN_ID="56"
REMOTE="origin"
MAIN_BRANCH="main"

BASE="$ROOT/runtime/cybroncybra_auto"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$BASE/$TS"

BACKUP="$RUN/backup"
SNAPSHOT="$RUN/snapshot"
mkdir -p "$BACKUP" "$SNAPSHOT"

cd "$ROOT"

echo "================================================"
echo " CYBRONCYBRA.COM — AUTO EVO / GIT / TOKEN"
echo "================================================"
echo "TIME:     $TS"
echo "ROOT:     $ROOT"
echo "DOMAIN:   $DOMAIN"
echo "CONTRACT: $CONTRACT"
echo "CHAIN:    BSC / $CHAIN_ID"
echo

fail() {
    echo
    echo "[AUTO][FAIL] $1"
    echo "FALSE" > "$RUN/status"
    exit 1
}

echo "[1/12] Repository"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "Not a Git repository"

LOCAL_HEAD="$(git rev-parse HEAD)"
echo "$LOCAL_HEAD" > "$SNAPSHOT/local_head"

git status --short > "$SNAPSHOT/status_before.txt"

echo "[2/12] Git remote"

ACTUAL_REMOTE="$(git remote get-url "$REMOTE" 2>/dev/null || true)"

case "$ACTUAL_REMOTE" in
    git@github.com:Lubnysash1980/CYBRA.git|\
    https://github.com/Lubnysash1980/CYBRA.git)
        ;;
    *)
        fail "Unexpected Git remote: $ACTUAL_REMOTE"
        ;;
esac

echo "$ACTUAL_REMOTE" > "$SNAPSHOT/remote"

echo "[3/12] Backup"

tar \
    --exclude="./.git" \
    --exclude="./node_modules" \
    --exclude="./runtime/cybroncybra_auto" \
    --exclude="./runtime/cybroncybra_oracle" \
    --exclude="./.env" \
    --exclude="./.env.*" \
    --exclude="*.key" \
    --exclude="*.pem" \
    --exclude="*private*" \
    --exclude="*secret*" \
    --exclude="*token*" \
    -czf "$BACKUP/project.tar.gz" \
    . 2>/dev/null \
    || fail "Backup failed"

sha256sum "$BACKUP/project.tar.gz" > "$BACKUP/project.tar.gz.sha256"

echo "[4/12] Snapshot"

git diff --stat > "$SNAPSHOT/diff_stat.txt" || true
git diff --name-status > "$SNAPSHOT/diff_name_status.txt" || true

git status --porcelain=v1 > "$SNAPSHOT/status.txt"

git rev-parse HEAD > "$SNAPSHOT/head.txt"

echo "[5/12] Fetch Git Oracle"

GIT_TERMINAL_PROMPT=0 git fetch --prune "$REMOTE" "$MAIN_BRANCH" \
    || fail "Git fetch failed"

REMOTE_HEAD="$(git rev-parse "$REMOTE/$MAIN_BRANCH")"

echo "LOCAL : $LOCAL_HEAD"
echo "REMOTE: $REMOTE_HEAD"

echo "$REMOTE_HEAD" > "$SNAPSHOT/remote_head"

echo "[6/12] Auto branch"

BRANCH="auto/cybroncybra-$TS"

# Existing local modifications are intentionally preserved.
# No reset, clean or stash.
git switch -c "$BRANCH" \
    || fail "Cannot create auto branch"

echo "$BRANCH" > "$SNAPSHOT/branch"

echo "[7/12] BSC token Oracle"

TOKEN_OUT="$RUN/token.json"

node > "$TOKEN_OUT" <<'NODE'
const { ethers } = require("ethers");
const fs = require("fs");

const address = process.env.CONTRACT || "0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f";

const RPCS = [
  "https://bsc-dataseed.binance.org/",
  "https://bsc.publicnode.com"
];

const abi = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function totalSupply() view returns (uint256)"
];

async function main() {
  let lastError = null;

  for (const rpc of RPCS) {
    try {
      const provider = new ethers.JsonRpcProvider(rpc, 56);
      const code = await provider.getCode(address);

      if (!code || code === "0x") {
        throw new Error("No contract bytecode at address");
      }

      const contract = new ethers.Contract(address, abi, provider);

      const [name, symbol, decimals, totalSupply] =
        await Promise.all([
          contract.name(),
          contract.symbol(),
          contract.decimals(),
          contract.totalSupply()
        ]);

      const result = {
        ok: true,
        chain: "BSC",
        chain_id: 56,
        contract: address,
        rpc,
        name: String(name),
        symbol: String(symbol),
        decimals: Number(decimals),
        total_supply_raw: totalSupply.toString(),
        total_supply: ethers.formatUnits(totalSupply, decimals),
        checked_at: new Date().toISOString()
      };

      process.stdout.write(JSON.stringify(result, null, 2));
      return;
    } catch (e) {
      lastError = e;
    }
  }

  process.stdout.write(JSON.stringify({
    ok: false,
    chain: "BSC",
    chain_id: 56,
    contract: address,
    error: String(lastError)
  }, null, 2));

  process.exit(1);
}

main();
NODE

# CONTRACT must be exported for the inline Node process
# Re-run with environment if first attempt failed because of shell scope.
if ! grep -q '"ok": true' "$TOKEN_OUT" 2>/dev/null; then
    CONTRACT="$CONTRACT" node > "$TOKEN_OUT" <<'NODE'
const { ethers } = require("ethers");

const address = process.env.CONTRACT;
const rpcs = [
  "https://bsc-dataseed.binance.org/",
  "https://bsc.publicnode.com"
];

const abi = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function totalSupply() view returns (uint256)"
];

(async () => {
  let last;

  for (const rpc of rpcs) {
    try {
      const provider = new ethers.JsonRpcProvider(rpc, 56);
      const code = await provider.getCode(address);

      if (code === "0x")
        throw new Error("Contract does not exist");

      const c = new ethers.Contract(address, abi, provider);

      const name = await c.name();
      const symbol = await c.symbol();
      const decimals = Number(await c.decimals());
      const supply = await c.totalSupply();

      console.log(JSON.stringify({
        ok: true,
        chain: "BSC",
        chain_id: 56,
        contract: address,
        rpc,
        name: String(name),
        symbol: String(symbol),
        decimals,
        total_supply_raw: supply.toString(),
        total_supply: ethers.formatUnits(supply, decimals),
        checked_at: new Date().toISOString()
      }, null, 2));

      process.exit(0);
    } catch (e) {
      last = e;
    }
  }

  console.log(JSON.stringify({
    ok: false,
    contract: address,
    error: String(last)
  }, null, 2));

  process.exit(1);
})();
NODE
fi

grep -q '"ok": true' "$TOKEN_OUT" \
    || fail "BSC token metadata check failed"

cp "$TOKEN_OUT" "$ROOT/data/cybroncybra_token_metadata.json"

echo "[TOKEN] Metadata:"
cat "$TOKEN_OUT"
echo

echo "[8/12] Domain configuration"

mkdir -p "$ROOT/config/cybroncybra" \
         "$ROOT/data/cybroncybra_domain"

cat > "$ROOT/config/cybroncybra/domain.env" <<EOF
CYBRA_DOMAIN=$DOMAIN
CYBRONCYBRA_DOMAIN=$DOMAIN
CYBRA_CHAIN=BSC
CYBRA_CHAIN_ID=$CHAIN_ID
CYBRA_TOKEN_CONTRACT=$CONTRACT
CYBRA_OFFICIAL_EMAIL=official@$DOMAIN
CYBRA_SUPPORT_EMAIL=support@$DOMAIN
CYBRA_ADMIN_EMAIL=admin@$DOMAIN
EOF

cat > "$ROOT/data/cybroncybra_domain/config.json" <<EOF
{
  "domain": "$DOMAIN",
  "chain": "BSC",
  "chain_id": 56,
  "contract": "$CONTRACT",
  "emails": {
    "official": "official@$DOMAIN",
    "support": "support@$DOMAIN",
    "admin": "admin@$DOMAIN"
  },
  "auto": {
    "git": true,
    "oracle": true,
    "backup": true,
    "snapshot": true,
    "rollback_ready": true,
    "evolution": true
  }
}
EOF

echo "[9/12] GitHub Pages domain"

mkdir -p "$ROOT/docs"

printf '%s\n' "$DOMAIN" > "$ROOT/docs/CNAME"

cat > "$ROOT/docs/domain.json" <<EOF
{
  "domain": "$DOMAIN",
  "https": true,
  "github_pages": true,
  "token_page": "/token.html"
}
EOF

echo "[10/12] Token Page"

python3 - "$ROOT" "$TOKEN_OUT" <<'PY'
import json
import pathlib
import sys
import html

root = pathlib.Path(sys.argv[1])
token_file = pathlib.Path(sys.argv[2])

data = json.loads(token_file.read_text())
docs = root / "docs"
docs.mkdir(parents=True, exist_ok=True)

name = html.escape(str(data["name"]))
symbol = html.escape(str(data["symbol"]))
decimals = data["decimals"]
supply = html.escape(str(data["total_supply"]))
contract = html.escape(str(data["contract"]))

pancake = (
    "https://pancakeswap.finance/swap?outputCurrency="
    + data["contract"]
)

bscscan = "https://bscscan.com/token/" + data["contract"]

page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{name} ({symbol}) — CYBRONCYBRA</title>
<meta name="description" content="{name} ({symbol}) token on BNB Smart Chain">
<style>
body {{
  font-family: system-ui,sans-serif;
  max-width:900px;
  margin:40px auto;
  padding:20px;
  background:#090b10;
  color:#f5f7fa;
}}
.card {{
  background:#141821;
  border:1px solid #2b3342;
  border-radius:16px;
  padding:24px;
  margin:16px 0;
}}
a {{
  color:#55d6ff;
}}
code {{
  word-break:break-all;
}}
.grid {{
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(220px,1fr));
  gap:12px;
}}
</style>
</head>
<body>

<h1>CYBRONCYBRA</h1>

<div class="card">
<h2>{name} ({symbol})</h2>

<div class="grid">
<div><b>Network</b><br>BSC / BNB Smart Chain</div>
<div><b>Decimals</b><br>{decimals}</div>
<div><b>Total Supply</b><br>{supply}</div>
</div>
</div>

<div class="card">
<h3>Contract</h3>
<code>{contract}</code>
<p>
<a href="{bscscan}" target="_blank" rel="noopener">
View contract on BscScan
</a>
</p>
</div>

<div class="card">
<h3>Trade</h3>
<p>
<a href="{pancake}" target="_blank" rel="noopener">
Open BSC token swap
</a>
</p>
<p>
Trading availability depends on an existing liquidity pool.
</p>
</div>

<div class="card">
<h3>Official contacts</h3>
<p>
<a href="mailto:official@cybroncybra.com">
official@cybroncybra.com
</a>
</p>
<p>
<a href="mailto:support@cybroncybra.com">
support@cybroncybra.com
</a>
</p>
<p>
<a href="mailto:admin@cybroncybra.com">
admin@cybroncybra.com
</a>
</p>
</div>

<p>
<a href="/">← CYBRONCYBRA</a>
</p>

</body>
</html>
"""

(docs / "token.html").write_text(page, encoding="utf-8")

contact = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CYBRONCYBRA Contact</title>
</head>
<body>
<h1>CYBRONCYBRA</h1>
<h2>Contact</h2>
<p><a href="mailto:official@cybroncybra.com">official@cybroncybra.com</a></p>
<p><a href="mailto:support@cybroncybra.com">support@cybroncybra.com</a></p>
<p><a href="mailto:admin@cybroncybra.com">admin@cybroncybra.com</a></p>
<p><a href="/token.html">Token Page</a></p>
</body>
</html>
"""

(docs / "contact.html").write_text(contact, encoding="utf-8")
PY

echo "[11/12] Auto Evolution"

mkdir -p "$ROOT/feeds" "$ROOT/proofs"

python3 - "$ROOT" "$TOKEN_OUT" "$TS" "$BRANCH" <<'PY'
import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone

root = pathlib.Path(sys.argv[1])
token_file = pathlib.Path(sys.argv[2])
ts = sys.argv[3]
branch = sys.argv[4]

token = json.loads(token_file.read_text())

files = [
    "docs/token.html",
    "docs/contact.html",
    "docs/CNAME",
    "docs/domain.json",
    "config/cybroncybra/domain.env",
    "data/cybroncybra_domain/config.json",
    "data/cybroncybra_token_metadata.json"
]

hashes = {}

for rel in files:
    p = root / rel
    if p.exists():
        hashes[rel] = hashlib.sha256(p.read_bytes()).hexdigest()

report = {
    "status": "AUTO_EVOLUTION_COMPLETED",
    "time": datetime.now(timezone.utc).isoformat(),
    "domain": "cybroncybra.com",
    "branch": branch,
    "token": token,
    "files_sha256": hashes,
    "auto": {
        "configuration": True,
        "token_metadata": True,
        "token_page": True,
        "domain": True,
        "git": True,
        "backup": True,
        "snapshot": True,
        "rollback": True
    }
}

text = json.dumps(report, indent=2, ensure_ascii=False)

(root / "feeds/cybroncybra_auto_evolution.json").write_text(
    text, encoding="utf-8"
)

digest = hashlib.sha256(text.encode()).hexdigest()

(root / "proofs/cybroncybra_auto_evolution.sha256").write_text(
    digest + "\n", encoding="utf-8"
)
PY

echo "[EVO] AUTO_EVOLUTION=1"

echo "[12/12] Git validation + commit + push"

git diff --check \
    || fail "Git whitespace/error check failed"

# Only files produced by this automation are staged.
# Existing unrelated local changes remain untouched.
git add \
    cybroncybra_auto_evo_git.sh \
    docs/CNAME \
    docs/domain.json \
    docs/token.html \
    docs/contact.html \
    config/cybroncybra/domain.env \
    data/cybroncybra_domain/config.json \
    data/cybroncybra_token_metadata.json \
    feeds/cybroncybra_auto_evolution.json \
    proofs/cybroncybra_auto_evolution.sha256

git diff --cached --check \
    || fail "Staged diff failed validation"

if git diff --cached --quiet; then
    echo "[GIT] Nothing new to commit."
else
    git commit -m "auto: cybroncybra domain token oracle evo" \
        || fail "Git commit failed"
fi

# Do not allow Git to hang asking for credentials.
GIT_TERMINAL_PROMPT=0 git push -u "$REMOTE" "$BRANCH" \
    || fail "Git push failed. SSH authentication is not unattended."

cat > "$RUN/result.env" <<EOF
DOMAIN=$DOMAIN
CONTRACT=$CONTRACT
CHAIN=BSC
CHAIN_ID=$CHAIN_ID
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_URL=$ACTUAL_REMOTE
BRANCH=$BRANCH
AUTO_EVOLUTION=1
TOKEN_PAGE=$ROOT/docs/token.html
BACKUP=$BACKUP/project.tar.gz
SNAPSHOT=$SNAPSHOT
STATUS=TRUE
TIME=$TS
EOF

cp "$RUN/result.env" "$ROOT/runtime/cybroncybra_integration_result.env"

echo
echo "================================================"
echo " CYBRONCYBRA AUTO COMPLETE"
echo "================================================"
cat "$RUN/result.env"
echo
echo "[AUTO] Existing unrelated local changes were preserved."
echo "[AUTO] No destructive reset performed."
echo "[AUTO] Auto branch created and pushed."
echo "[AUTO] Token metadata checked against BSC."
echo "[AUTO] Token page generated."
echo "[AUTO] Domain CNAME configured."
echo "[AUTO] Backup + snapshot ready."
echo "[AUTO] Evolution proof generated."
