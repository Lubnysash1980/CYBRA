#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
RUNTIME="$ROOT/runtime"
BUFFER="$RUNTIME/buffer"
BINARY="$RUNTIME/binary_buffer"
TASK_ROOT="$RUNTIME/cybroncybra_ai_task"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
TASK_ID="CYBRONCYBRA-AI-100-$TS"
TASK_DIR="$TASK_ROOT/$TS"

mkdir -p \
  "$BUFFER/queue" \
  "$BUFFER/running" \
  "$BUFFER/completed" \
  "$BUFFER/failed" \
  "$BINARY/incoming" \
  "$BINARY/quarantine" \
  "$BINARY/verified" \
  "$BINARY/running" \
  "$BINARY/completed" \
  "$BINARY/rejected" \
  "$TASK_DIR"

# ============================================================
# CYBRONCYBRA — MULTI LEVEL AI TASK CONTRACT
# ============================================================

cat > "$TASK_DIR/TASK.env" <<TASK
TASK_ID=$TASK_ID
TASK_TYPE=CYBRONCYBRA_AI
TASK_VERSION=2
CREATED_AT=$TS

LEVEL_0=ANALYSIS
LEVEL_1=BASIC_WORK
LEVEL_2=STANDARD_WORK
LEVEL_3=COMPLEX_WORKER
LEVEL_4=BINARY_WORKER
LEVEL_5=BINARY_EXECUTOR

BUFFER_REQUIRED=TRUE
INDEPENDENT_BUFFER_REQUIRED=TRUE
BINARY_BUFFER_REQUIRED=TRUE

WORKER_REQUIRED=TRUE
EXECUTOR_REQUIRED=TRUE
REMOTE_EVIDENCE_REQUIRED=TRUE
GIT_EVIDENCE_REQUIRED=TRUE
HASH_EVIDENCE_REQUIRED=TRUE

FAILED_MUST_BE=0
PENDING_MUST_BE=0
TIMEOUT_MUST_BE=0

FINAL_RULE=ALL_REQUIRED_TRUE
TRUE_ONLY_AT_100_PERCENT=TRUE
TASK

# ============================================================
# WORKER INSTRUCTION
# ============================================================

cat > "$TASK_DIR/WORKER_INSTRUCTION.md" <<'WORKER'
# CYBRONCYBRA AI WORKER TASK

## Objective

Process the assigned task through the required execution level.

## Levels

- LEVEL 0 — analyse only
- LEVEL 1 — basic deterministic work
- LEVEL 2 — standard work
- LEVEL 3 — complex worker processing
- LEVEL 4 — binary inspection/processing
- LEVEL 5 — binary execution only when explicitly authorized

## Mandatory rules

1. Never convert UNKNOWN/PENDING into TRUE.
2. Never fabricate evidence.
3. Never execute raw clipboard text as shell.
4. Binary objects must enter quarantine first.
5. Binary objects require SHA-256 identification.
6. Execution must reference TASK_ID.
7. Every successful operation must create evidence.
8. A failed operation remains FAILED until independently resolved.
9. FINAL=TRUE is forbidden unless the 100% validator confirms every required condition.
WORKER

# ============================================================
# EXECUTOR CONTRACT
# ============================================================

cat > "$TASK_DIR/EXECUTOR_CONTRACT.md" <<'EXECUTOR'
# CYBRONCYBRA EXECUTOR CONTRACT

Executor may execute only a structured task.

Required:

TASK_ID
WORKER_RESULT
COMMAND_MANIFEST
INPUT_HASH
OUTPUT_HASH
EXECUTION_RESULT
EVIDENCE

Forbidden:

- raw clipboard shell execution
- arbitrary command injection
- bypassing worker
- bypassing binary quarantine
- manually setting FINAL=TRUE
- treating missing evidence as success
EXECUTOR

# ============================================================
# BINARY BUFFER CONTRACT
# ============================================================

cat > "$TASK_DIR/BINARY_BUFFER_CONTRACT.md" <<'BINARY'
# INDEPENDENT BINARY BUFFER

Binary objects are isolated from the normal text task queue.

Pipeline:

INCOMING
  ->
SHA256
  ->
TYPE/SIZE CHECK
  ->
QUARANTINE
  ->
INDEPENDENT VERIFICATION
  ->
VERIFIED
  ->
WORKER
  ->
EXECUTOR
  ->
POST-EXECUTION HASH
  ->
EVIDENCE
  ->
100% GATE

No binary object may jump directly from INCOMING to EXECUTOR.
BINARY

# ============================================================
# REMOTE ORACLE CONTRACT
# ============================================================

cat > "$TASK_DIR/REMOTE_ORACLE_CONTRACT.md" <<'REMOTE'
# REMOTE ORACLE CONTRACT

The local AI must NOT claim remote verification.

Required external evidence:

DNS_OK=TRUE
HTTPS_DOMAIN_OK=TRUE
HTTPS_PAGE_OK=TRUE
HTTPS_LOGO_OK=TRUE

Evidence must identify:

TASK_ID
timestamp
source
result
hash/evidence reference

Missing remote evidence = PENDING.
REMOTE_FINAL=TRUE is accepted only when externally verified.
REMOTE

# ============================================================
# 100% VALIDATOR
# ============================================================

cat > "$TASK_DIR/validator.sh" <<'VALIDATOR'
#!/data/data/com.termux/files/usr/bin/bash

set -u

FINAL="TRUE"

check() {
    local name="$1"
    local value="$2"

    if [ "$value" != "TRUE" ]; then
        echo "[GATE] $name=FALSE"
        FINAL="FALSE"
    else
        echo "[GATE] $name=TRUE"
    fi
}

check BUFFER TRUE
check INDEPENDENT_BUFFER TRUE
check WORKER FALSE
check EXECUTOR FALSE
check REMOTE FALSE
check GIT_EVIDENCE FALSE
check HASH_EVIDENCE FALSE

echo

if [ "$FINAL" = "TRUE" ]; then
    echo "COMPLETION=100%"
    echo "FINAL=TRUE"
    exit 0
fi

echo "COMPLETION<100%"
echo "FINAL=FALSE"
exit 2
VALIDATOR

chmod +x "$TASK_DIR/validator.sh"

# ============================================================
# TASK MANIFEST
# ============================================================

cat > "$TASK_DIR/MANIFEST" <<MANIFEST
TASK_ID=$TASK_ID
TASK_DIR=$TASK_DIR

NORMAL_BUFFER=$BUFFER
INDEPENDENT_BINARY_BUFFER=$BINARY

LEVELS=0,1,2,3,4,5

WORKER=$TASK_DIR/WORKER_INSTRUCTION.md
EXECUTOR=$TASK_DIR/EXECUTOR_CONTRACT.md
BINARY_CONTRACT=$TASK_DIR/BINARY_BUFFER_CONTRACT.md
REMOTE_CONTRACT=$TASK_DIR/REMOTE_ORACLE_CONTRACT.md
VALIDATOR=$TASK_DIR/validator.sh

FINAL_POLICY=TRUE_ONLY_AT_100_PERCENT
MANIFEST

# ============================================================
# QUEUE TASK
# ============================================================

QUEUE="$BUFFER/queue/ai-$TS"
mkdir -p "$QUEUE"

cp "$TASK_DIR/TASK.env" "$QUEUE/"
cp "$TASK_DIR/MANIFEST" "$QUEUE/"
cp "$TASK_DIR/WORKER_INSTRUCTION.md" "$QUEUE/"
cp "$TASK_DIR/EXECUTOR_CONTRACT.md" "$QUEUE/"
cp "$TASK_DIR/BINARY_BUFFER_CONTRACT.md" "$QUEUE/"
cp "$TASK_DIR/REMOTE_ORACLE_CONTRACT.md" "$QUEUE/"

cat > "$QUEUE/STATE" <<STATE
TASK_ID=$TASK_ID
STATE=QUEUED
WORKER=FALSE
EXECUTOR=FALSE
REMOTE=FALSE
EVIDENCE=TRUE
FINAL=FALSE
STATE

# ============================================================
# HASH THE TASK
# ============================================================

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$TASK_DIR/MANIFEST" > "$TASK_DIR/MANIFEST.sha256"
    cp "$TASK_DIR/MANIFEST.sha256" "$QUEUE/"
fi

echo
echo "================================================"
echo " CYBRONCYBRA — AI TASK CREATED"
echo "================================================"
echo "TASK:       $TASK_ID"
echo "TASK_DIR:   $TASK_DIR"
echo "QUEUE:      $QUEUE"
echo "BINARY:     $BINARY"
echo
echo "LEVELS:     0 → 5"
echo "WORKER:     REQUIRED"
echo "EXECUTOR:   REQUIRED"
echo "REMOTE:     REQUIRED"
echo "HASH:       REQUIRED"
echo "100% GATE:  ENABLED"
echo
echo "FINAL=FALSE"
echo
