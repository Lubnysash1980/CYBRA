#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CYBRA FIX GIT LOCK + PAGES + RPC ==="

mkdir -p posts feeds proofs data/cybra_runtime_fix/reports logs runtime/redis

echo
echo "=== 1. STOP STALE GIT LOCK ==="

if [ -f .git/index.lock ]; then
  echo "Found .git/index.lock"

  if ps -A 2>/dev/null | grep -E "git[[:space:]]" | grep -v grep >/dev/null 2>&1; then
    echo "⚠ Active git process found. Showing:"
    ps -A | grep -E "git[[:space:]]" | grep -v grep || true
    echo "Not removing lock while git process is active."
  else
    rm -f .git/index.lock
    echo "✅ stale .git/index.lock removed"
  fi
else
  echo "✅ no git lock"
fi

echo
echo "=== 2. CREATE SAFE GIT COMMIT WRAPPER FOR HASH MODULE ==="

cat > cybra_git_safe_commit.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

FILE="${1:-hash_storage/root_hash.json}"
MSG="${2:-Update root_hash}"

wait_lock(){
  i=0
  while [ -f .git/index.lock ] && [ "$i" -lt 30 ]; do
    echo "Waiting for git lock... $i"
    sleep 2
    i=$((i+1))
  done

  if [ -f .git/index.lock ]; then
    if ps -A 2>/dev/null | grep -E "git[[:space:]]" | grep -v grep >/dev/null 2>&1; then
      echo "Active git process exists. Abort safe commit."
      exit 1
    else
      echo "Removing stale git lock."
      rm -f .git/index.lock
    fi
  fi
}

wait_lock

git add "$FILE" 2>/dev/null || {
  echo "git add failed for $FILE"
  exit 1
}

if git diff --cached --quiet; then
  echo "No staged changes."
  exit 0
fi

git commit -m "$MSG" || exit 1
git push origin main || git push
EOF

chmod +x cybra_git_safe_commit.sh

echo
echo "=== 3. PATCH cybragithash.mjs GIT COMMAND IF POSSIBLE ==="

python3 - <<'PY'
from pathlib import Path

p = Path("cybragithash.mjs")
if not p.exists():
    print("cybragithash.mjs not found, skip patch")
    raise SystemExit

s = p.read_text(encoding="utf-8", errors="ignore")
old = "git add hash_storage/root_hash.json && git commit -m 'Update root_hash' && git push"
new = "bash cybra_git_safe_commit.sh hash_storage/root_hash.json 'Update root_hash'"

if old in s:
    s = s.replace(old, new)
    p.write_text(s, encoding="utf-8")
    print("✅ cybragithash.mjs patched to use cybra_git_safe_commit.sh")
else:
    print("⚠ exact old git command not found; safe wrapper created, but mjs not patched")
PY

echo
echo "=== 4. CHECK GITHUB PAGES URLS CORRECTLY ==="

echo "Do not run URLs directly in bash."
echo "Use curl or termux-open-url."

if command -v curl >/dev/null 2>&1; then
  curl -I --max-time 15 "https://lubnysash1980.github.io/Alfapay/" || true
  curl -I --max-time 15 "https://lubnysash1980.github.io/Alfapay/logo.png" || true
  curl -I --max-time 15 "https://lubnysash1980.github.io/Alfapay/metadata.json" || true
else
  echo "curl missing. Install: pkg install curl"
fi

echo
echo "=== 5. CHECK SOLANA RPC FETCH ==="

RPC_URL="${SOLANA_RPC_URL:-${RPC_URL:-https://api.mainnet-beta.solana.com}}"

node - <<'NODE' || true
const rpc = process.env.SOLANA_RPC_URL || process.env.RPC_URL || "https://api.mainnet-beta.solana.com";

async function main() {
  console.log("RPC:", rpc);
  try {
    const r = await fetch(rpc, {
      method: "POST",
      headers: {"content-type":"application/json"},
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "getHealth"
      })
    });
    console.log("HTTP:", r.status);
    console.log(await r.text());
  } catch (e) {
    console.log("RPC_FETCH_FAILED:", e.message);
    console.log("Fix: перевір інтернет або задай інший RPC:");
    console.log("export SOLANA_RPC_URL='https://api.mainnet-beta.solana.com'");
  }
}
main();
NODE

echo
echo "=== 6. BUILD REPORT ==="

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sha(x): return hashlib.sha256(x.encode()).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))

def exists(p): return (ROOT / p).exists()

obj = {
    "status": "git_lock_pages_rpc_fix_generated",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "checks": {
        "git_index_lock_exists": exists(".git/index.lock"),
        "safe_git_commit_wrapper": exists("cybra_git_safe_commit.sh"),
        "cybragithash_mjs": exists("cybragithash.mjs"),
        "recovery_missing_count_zero": exists("posts/cybra_menubar_recovery_test_report.md"),
        "autorecovery_pack": exists("data/cybra_autorecovery/packs/cybra_restore_pack.tar.gz")
    },
    "notes": [
        "URLs must be opened with browser/curl, not executed as bash commands.",
        "mint_tokens_2022.js fetch failed means Solana RPC/network endpoint problem.",
        "Git index.lock was stale if no git process was active.",
        "HTTPS GitHub push may require token/PAT or SSH, not normal password."
    ],
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "private_key_required": False,
        "seed_phrase_required": False,
        "manual_OWNER_approval_required": True
    }
}
obj["double_sha"] = dsha(obj)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "data/cybra_runtime_fix/reports").mkdir(parents=True, exist_ok=True)

(ROOT / "feeds/cybra_git_lock_pages_rpc_fix.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "data/cybra_runtime_fix/reports/latest_git_lock_pages_rpc_fix.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

md = ["# CYBRA Git Lock / Pages / RPC Fix Report", "", "Status: generated", "", "## Checks"]
for k,v in obj["checks"].items():
    md.append(f"{k}: {v}")
md += ["", "## Notes"]
for n in obj["notes"]:
    md.append("- " + n)
md += ["", "## Safety"]
for k,v in obj["safety"].items():
    md.append(f"{k}: {v}")
md += ["", "## Double SHA", obj["double_sha"]]

(ROOT / "posts/cybra_git_lock_pages_rpc_fix.md").write_text("\n".join(md), encoding="utf-8")

with (ROOT / "proofs/cybra_git_lock_pages_rpc_fix.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_git_lock_pages_rpc_fix.json",
        "posts/cybra_git_lock_pages_rpc_fix.md",
        "data/cybra_runtime_fix/reports/latest_git_lock_pages_rpc_fix.json",
        "cybra_git_safe_commit.sh"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print("✅ report generated")
print("REPORT: posts/cybra_git_lock_pages_rpc_fix.md")
print("DOUBLE_SHA:", obj["double_sha"])
PY

echo
echo "=== 7. GIT STATUS ==="

git status --short || true

echo
echo "✅ FIX DONE"
echo
echo "Now commit:"
echo "git add fix_git_lock_pages_rpc_now.sh cybra_git_safe_commit.sh cybragithash.mjs posts/cybra_git_lock_pages_rpc_fix.md feeds/cybra_git_lock_pages_rpc_fix.json data/cybra_runtime_fix/reports/latest_git_lock_pages_rpc_fix.json proofs/cybra_git_lock_pages_rpc_fix.sha256"
echo "git commit -m 'fix git lock pages rpc runtime'"
echo "git push origin main"
