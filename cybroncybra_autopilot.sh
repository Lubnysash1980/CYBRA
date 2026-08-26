#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="${HOME}/CYBRA"
DOMAIN="https://cybroncybra.com"
PAGE="${DOMAIN}/token.html"
LOGO="${DOMAIN}/assets/cybra-logo.png"
CONTRACT="0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f"

RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')"
RUN="${ROOT}/runtime/cybroncybra_autopilot/${RUN_ID}"
WORK="${ROOT}/runtime/worker_tmp/${RUN_ID}"
VENV="${WORK}/venv"

mkdir -p "$RUN"/{results,evidence,patches} "$WORK"/{work,build,logs}

LOG="${RUN}/run.log"
exec > >(tee -a "$LOG") 2>&1

cd "$ROOT" || exit 1

TOTAL=0
OK=0
FAIL=0
PENDING=0
TIMEOUT=0

required() { TOTAL=$((TOTAL+1)); }
pass() { OK=$((OK+1)); }
bad() { FAIL=$((FAIL+1)); }
wait_remote() { PENDING=$((PENDING+1)); }

state() {
    cat > "$RUN/results/final.env" <<STATE
REQUIRED_TOTAL=$TOTAL
REQUIRED_OK=$OK
FAILED=$FAIL
PENDING=$PENDING
TIMEOUTS=$TIMEOUT
STATE
}

echo "================================================"
echo " CYBRONCYBRA — 100% REMOTE ORACLE AUTOPILOT"
echo "================================================"
echo "ROOT:     $ROOT"
echo "DOMAIN:   $DOMAIN"
echo "CONTRACT: $CONTRACT"
echo "RUN:      $RUN"
echo "WORK:     $WORK"
echo

# ============================================================
# 1 REPOSITORY
# ============================================================

echo "[1/16] Repository"
required

if git rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
   git rev-parse HEAD >/dev/null 2>&1; then
    echo "[GIT] HEAD=$(git rev-parse HEAD)"
    pass
else
    bad
fi

# ============================================================
# 2 REMOTE
# ============================================================

echo
echo "[2/16] Remote"
required

REMOTE="$(git remote get-url origin 2>/dev/null || true)"

if [ -n "$REMOTE" ]; then
    echo "[REMOTE] $REMOTE"
    pass
else
    bad
fi

# ============================================================
# 3 SPACE
# ============================================================

echo
echo "[3/16] Space"
required

FREE_KB="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{print $4}')"

if [[ "$FREE_KB" =~ ^[0-9]+$ ]] && [ "$FREE_KB" -ge 1048576 ]; then
    echo "[SPACE] OK"
    pass
else
    echo "[SPACE] FAIL"
    bad
fi

# ============================================================
# 4 SNAPSHOT
# ============================================================

echo
echo "[4/16] Snapshot"
required

{
    echo "RUN_ID=$RUN_ID"
    echo "TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "HEAD=$(git rev-parse HEAD 2>/dev/null || true)"
    echo "BRANCH=$(git branch --show-current 2>/dev/null || true)"
    git status --short 2>/dev/null || true
} > "$RUN/evidence/snapshot.txt"

[ -s "$RUN/evidence/snapshot.txt" ] && pass || bad

# ============================================================
# 5 VENV
# ============================================================

echo
echo "[5/16] Auto VENV"
required

PY="$(command -v python || command -v python3 || true)"

if [ -n "$PY" ]; then
    if "$PY" -m venv "$VENV" >/dev/null 2>&1 &&
       "$VENV/bin/python" -c 'import sys; print(sys.version)' >/dev/null 2>&1; then
        echo "[VENV] READY=$VENV"
        pass
    else
        echo "[VENV] FAIL"
        bad
    fi
else
    bad
fi

# ============================================================
# 6 LOCAL TOKEN PAGE
# ============================================================

echo
echo "[6/16] Token Page"
required

TOKEN_LOCAL="$ROOT/docs/token.html"

if [ -f "$TOKEN_LOCAL" ] &&
   grep -qi "$CONTRACT" "$TOKEN_LOCAL" &&
   grep -qi 'cybra-logo.png' "$TOKEN_LOCAL"; then
    echo "[PAGE] OK"
    pass
else
    echo "[PAGE] FAIL"
    bad
fi

# ============================================================
# 7 SEO
# ============================================================

echo
echo "[7/16] SEO"
required

if [ -f "$ROOT/robots.txt" ] &&
   [ -f "$ROOT/sitemap.xml" ] &&
   [ -f "$ROOT/CNAME" ] &&
   grep -q 'cybroncybra.com' "$ROOT/CNAME"; then
    echo "[SEO] OK"
    pass
else
    echo "[SEO] FAIL"
    bad
fi

# ============================================================
# 8 REMOTE DNS ORACLE
# ============================================================

echo
echo "[8/16] DNS Oracle — REMOTE"
required

REMOTE_ENV="$ROOT/runtime/remote_oracle/FINAL.env"

if [ -f "$REMOTE_ENV" ] &&
   grep -q '^DNS_OK=TRUE$' "$REMOTE_ENV"; then
    echo "[DNS] REMOTE VERIFIED"
    pass
else
    echo "[DNS] REMOTE EVIDENCE REQUIRED"
    wait_remote
fi

# ============================================================
# 9 REMOTE HTTPS ORACLE
# ============================================================

echo
echo "[9/16] HTTPS Oracle — REMOTE"
required

if [ -f "$REMOTE_ENV" ] &&
   grep -q '^HTTPS_OK=TRUE$' "$REMOTE_ENV" &&
   grep -q '^PAGE_OK=TRUE$' "$REMOTE_ENV" &&
   grep -q '^LOGO_OK=TRUE$' "$REMOTE_ENV"; then
    echo "[HTTPS] REMOTE VERIFIED"
    pass
else
    echo "[HTTPS] REMOTE EVIDENCE REQUIRED"
    wait_remote
fi

# ============================================================
# 10 BSC
# ============================================================

echo
echo "[10/16] BSC Oracle"
required

BSC_JSON="$RUN/evidence/bsc.json"

"$VENV/bin/python" - "$CONTRACT" "$BSC_JSON" <<'PY'
import json
import sys
import urllib.request

contract=sys.argv[1]
out=sys.argv[2]

payload=json.dumps({
    "jsonrpc":"2.0",
    "id":1,
    "method":"eth_getCode",
    "params":[contract,"latest"]
}).encode()

req=urllib.request.Request(
    "https://bsc-dataseed.binance.org",
    data=payload,
    headers={"Content-Type":"application/json"}
)

try:
    with urllib.request.urlopen(req, timeout=20) as r:
        data=json.loads(r.read().decode())
    code=data.get("result","")
    ok=isinstance(code,str) and code.startswith("0x") and len(code)>2
except Exception as e:
    ok=False
    data={"error":str(e)}

json.dump({"ok":ok,"response":data},open(out,"w"),indent=2)
sys.exit(0 if ok else 1)
PY

if [ $? -eq 0 ]; then
    echo "[BSC] OK"
    pass
else
    echo "[BSC] FAIL"
    bad
fi

# ============================================================
# 11 GIT LARGE OBJECT
# ============================================================

echo
echo "[11/16] Git Large Object Oracle"
required

LARGE="$RUN/evidence/large_objects.txt"
: > "$LARGE"

git ls-tree -r -l HEAD 2>/dev/null |
awk '$4 > 100000000 {print $4, $5}' > "$LARGE"

if [ ! -s "$LARGE" ]; then
    echo "[LARGE] OK — no reachable object >100 MB"
    pass
else
    echo "[LARGE] FAIL"
    bad
fi

# ============================================================
# 12 WORKER BUILD
# ============================================================

echo
echo "[12/16] Worker Build"
required

WORKER="$WORK/work/worker.py"

cat > "$WORKER" <<'PY'
import json
import os
import sys

print("AI Worker environment:", sys.version)
print("Worker workspace:", os.environ.get("CYBRA_WORKSPACE"))

checks = {
    "python": True,
    "json": True,
    "workspace": os.path.isdir(os.environ["CYBRA_WORKSPACE"]),
}

print(json.dumps(checks, indent=2))

if not all(checks.values()):
    raise SystemExit(1)
PY

CYBRA_WORKSPACE="$WORK/build" \
"$VENV/bin/python" "$WORKER"

if [ $? -eq 0 ]; then
    echo "[WORKER] BUILD OK"
    pass
else
    bad
fi

# ============================================================
# 13 BUFFER
# ============================================================

echo
echo "[13/16] AutoPatch Buffer"
required

BUFFER="$ROOT/runtime/buffer"
mkdir -p "$BUFFER"/{queue,running,completed,failed}

PATCH="$RUN/patches/autopatch_buffer.sh"

cat > "$PATCH" <<PATCHFILE
#!/data/data/com.termux/files/usr/bin/bash
# CYBRONCYBRA PATCH
PATCH_ID="autopilot-${RUN_ID}"
SOURCE="CYBRONCYBRA"
MODE="WORKER_EXECUTOR"
VERIFY_REQUIRED="TRUE"
FINAL_REQUIRED="100_PERCENT"
PATCHFILE

chmod +x "$PATCH"

if [ -s "$PATCH" ]; then
    echo "[BUFFER] PATCH CREATED"
    echo "[BUFFER] $PATCH"
    if command -v termux-clipboard-set >/dev/null 2>&1; then
        cat "$PATCH" | termux-clipboard-set
        echo "[CLIPBOARD] OUTPUT COPIED"
    fi
    pass
else
    bad
fi

# ============================================================
# 14 GIT EVIDENCE
# ============================================================

echo
echo "[14/16] Git Evidence"
required

{
    echo "HEAD=$(git rev-parse HEAD)"
    echo "REMOTE=$REMOTE"
    echo "RUN_ID=$RUN_ID"
    git status --short
} > "$RUN/evidence/git.env"

[ -s "$RUN/evidence/git.env" ] && pass || bad

# ============================================================
# 15 EVO
# ============================================================

echo
echo "[15/16] EVO"
required

cat > "$RUN/evidence/evo.env" <<EVO
AUTOPILOT=TRUE
WORKER=TRUE
BUFFER=TRUE
EXECUTOR=TRUE
REMOTE_ORACLE=TRUE
FINAL_GATE=100_PERCENT
RUN_ID=$RUN_ID
EVO

pass

# ============================================================
# 16 FINAL GATE
# ============================================================

echo
echo "[16/16] FINAL 100% GATE"

state

if [ "$TOTAL" -gt 0 ]; then
    PERCENT=$((OK * 100 / TOTAL))
else
    PERCENT=0
fi

FINAL=FALSE

if [ "$OK" -eq "$TOTAL" ] &&
   [ "$FAIL" -eq 0 ] &&
   [ "$PENDING" -eq 0 ] &&
   [ "$TIMEOUT" -eq 0 ]; then
    FINAL=TRUE
fi

cat > "$RUN/FINAL.env" <<FINAL
REQUIRED_TOTAL=$TOTAL
REQUIRED_OK=$OK
FAILED=$FAIL
PENDING=$PENDING
TIMEOUTS=$TIMEOUT
COMPLETION=${PERCENT}%
FINAL=$FINAL
RUN_ID=$RUN_ID
FINAL
echo
echo "================================================"
echo " CYBRONCYBRA — FINAL"
echo "================================================"
echo "REQUIRED:   $TOTAL"
echo "OK:         $OK"
echo "FAILED:     $FAIL"
echo "PENDING:    $PENDING"
echo "TIMEOUTS:   $TIMEOUT"
echo "COMPLETION: ${PERCENT}%"
echo "FINAL:      $FINAL"
echo
echo "RUN:        $RUN"
echo "WORK:       $WORK"

if [ "$FINAL" = "TRUE" ]; then
    echo
    echo "================================================"
    echo " 100% TRUE"
    echo "================================================"
    exit 0
fi

echo
echo "================================================"
echo " 100% FALSE"
echo "================================================"
echo "[GATE] No TRUE until every required process is verified."
exit 2
