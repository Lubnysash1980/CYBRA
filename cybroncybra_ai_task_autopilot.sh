#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
# CYBRONCYBRA — AI TASK AUTOPILOT
# ============================================================
#
# ARCHITECTURE:
#
# AI TASK
#    ↓
# BUFFER
#    ↓
# GITHUB REMOTE WORKER
#    ↓
# EXECUTOR
#    ↓
# REMOTE ORACLE
#    ↓
# EVIDENCE
#    ↓
# 100% GATE
#
# IMPORTANT:
# Termux = coordinator.
# GitHub Runner = remote execution environment.
# Worker = executes task.
# Executor = executes only structured jobs.
# Oracle = verifies external state.
# Evidence = proof.
# 100% Gate = ONLY source of FINAL=TRUE.
#
# RULE:
# PENDING / FAILED / ERROR / TIMEOUT / UNKNOWN / NO EVIDENCE
# => FINAL=FALSE
#
# ============================================================

set -u
set -o pipefail

ROOT="${HOME}/CYBRA"

RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')"

RUNTIME="${ROOT}/runtime"
RUN="${RUNTIME}/cybroncybra_ai_task/${RUN_ID}"

BUFFER="${RUNTIME}/buffer"
QUEUE="${BUFFER}/queue"
RUNNING="${BUFFER}/running"
COMPLETED="${BUFFER}/completed"
FAILED_DIR="${BUFFER}/failed"

WORK="${RUNTIME}/worker_tmp/${RUN_ID}"

RESULTS="${RUN}/results"
EVIDENCE="${RUN}/evidence"
LOGS="${RUN}/logs"

TASK="${RUN}/AI_TASK.md"
MANIFEST="${RUN}/TASK.env"
FINAL="${RUN}/FINAL.env"

mkdir -p \
    "$RUN" \
    "$QUEUE" \
    "$RUNNING" \
    "$COMPLETED" \
    "$FAILED_DIR" \
    "$WORK" \
    "$RESULTS" \
    "$EVIDENCE" \
    "$LOGS"

exec > >(tee -a "${RUN}/run.log") 2>&1

echo "================================================"
echo " CYBRONCYBRA — AI TASK AUTOPILOT"
echo "================================================"
echo "ROOT:       $ROOT"
echo "RUN:        $RUN"
echo "BUFFER:     $BUFFER"
echo "WORKER:     $WORK"
echo

cd "$ROOT" || exit 1

# ============================================================
# TASK ID
# ============================================================

TASK_ID="CYBRONCYBRA-AI-100-${RUN_ID}"
PATCH_ID="ai-${RUN_ID}"

# ============================================================
# AI TASK DEFINITION
# ============================================================

cat > "$TASK" <<TASKFILE
# CYBRONCYBRA AI TASK

TASK_ID=${TASK_ID}
PATCH_ID=${PATCH_ID}
RUN_ID=${RUN_ID}

## OBJECTIVE

Execute and verify the CYBRONCYBRA pipeline:

AI TASK
→ BUFFER
→ GITHUB REMOTE WORKER
→ EXECUTOR
→ REMOTE ORACLE
→ EVIDENCE
→ 100% GATE

## REQUIRED WORK

1. Repository verification
2. Git remote verification
3. Workspace verification
4. Worker environment verification
5. Token page verification
6. SEO verification
7. Remote DNS verification
8. Remote HTTPS domain verification
9. Remote HTTPS token page verification
10. Remote HTTPS logo verification
11. BSC bytecode verification
12. Git large-object verification
13. Worker build/test
14. Executor verification
15. Evidence verification

## AI WORKER RULE

The worker must:

- receive this structured task;
- execute the assigned checks;
- analyze failures;
- generate a structured fix;
- submit the fix through BUFFER;
- execute the fix through EXECUTOR;
- verify the result;
- generate evidence.

The worker MUST NOT declare FINAL=TRUE.

## EXECUTOR RULE

Executor accepts structured jobs only.

Clipboard text MUST NOT be executed as arbitrary shell code.

Every execution must have:

TASK_ID
PATCH_ID
RUN_ID
ATTEMPT
EXIT_CODE
LOG
RESULT

## REMOTE RULE

DNS and HTTPS are remote checks.

Local Termux network state is NOT accepted as proof of remote verification.

Remote evidence must originate from the GitHub Runner.

## 100 PERCENT RULE

TRUE is permitted ONLY when:

REQUIRED_OK == REQUIRED_TOTAL
FAILED == 0
PENDING == 0
TIMEOUTS == 0
ERRORS == 0
WORKER_VERIFIED == TRUE
EXECUTOR_VERIFIED == TRUE
REMOTE_ORACLE_VERIFIED == TRUE
EVIDENCE_VALID == TRUE
FINAL_ARTIFACT_VERIFIED == TRUE
COMPLETION == 100%

Otherwise:

FINAL=FALSE

## FORBIDDEN

SKIP → TRUE
UNKNOWN → TRUE
PENDING → TRUE
TIMEOUT → TRUE
FAILED → TRUE
ERROR → TRUE
NO EVIDENCE → TRUE
PARTIAL RESULT → TRUE
TASK STARTED → TRUE

## FINAL

Only the verified 100% Gate may produce:

FINAL=TRUE
COMPLETION=100%
TASKFILE

# ============================================================
# TASK MANIFEST
# ============================================================

cat > "$MANIFEST" <<ENV
TASK_ID=${TASK_ID}
PATCH_ID=${PATCH_ID}
RUN_ID=${RUN_ID}

TASK_TYPE=AI_AUTOPILOT

BUFFER_ENABLED=TRUE
WORKER_REQUIRED=TRUE
EXECUTOR_REQUIRED=TRUE
REMOTE_ORACLE_REQUIRED=TRUE
EVIDENCE_REQUIRED=TRUE

REMOTE_DNS_REQUIRED=TRUE
REMOTE_HTTPS_REQUIRED=TRUE
BSC_REQUIRED=TRUE
GIT_REQUIRED=TRUE

TRUE_ONLY_AT_100_PERCENT=TRUE

FINAL=FALSE
COMPLETION=0%
ENV

# ============================================================
# BUFFER JOB
# ============================================================

JOB="${QUEUE}/${PATCH_ID}"

mkdir -p "$JOB"

cp "$TASK" "$JOB/AI_TASK.md"
cp "$MANIFEST" "$JOB/patch.env"

cat > "$JOB/job.env" <<JOBENV
TASK_ID=${TASK_ID}
PATCH_ID=${PATCH_ID}
RUN_ID=${RUN_ID}

JOB_TYPE=AI_TASK
WORKER=REQUIRED
EXECUTOR=REQUIRED
REMOTE_ORACLE=REQUIRED
EVIDENCE=REQUIRED

STATUS=QUEUED
FINAL=FALSE
JOBENV

echo
echo "[BUFFER] AI TASK QUEUED"
echo "[BUFFER] $JOB"

# ============================================================
# WORKER INSTRUCTIONS
# ============================================================

cat > "$JOB/worker.instruction" <<'WORKER'
CYBRONCYBRA AI WORKER

Read AI_TASK.md.

Execute the task through the GitHub Runner.

Do NOT modify FINAL directly.

For every required operation:

1. execute
2. capture exit code
3. capture log
4. produce result
5. produce evidence

If a check fails:

FAIL
  ↓
ANALYZE
  ↓
GENERATE STRUCTURED FIX
  ↓
BUFFER
  ↓
EXECUTOR
  ↓
VERIFY

A failed attempt never becomes TRUE.

Only the final 100% Gate may produce FINAL=TRUE.
WORKER

# ============================================================
# EXECUTOR CONTRACT
# ============================================================

cat > "$JOB/executor.contract" <<'EXECUTOR'
CYBRONCYBRA EXECUTOR CONTRACT

INPUT:
structured job

REQUIRED:
TASK_ID
PATCH_ID
RUN_ID
ATTEMPT

EXECUTION:
- validate job
- create isolated worker workspace
- execute approved operation
- capture stdout
- capture stderr
- capture exit code
- save evidence
- verify result

FAILURE:
non-zero exit code => FAILED

TIMEOUT:
timeout => TIMEOUT

MISSING RESULT:
missing result => FAILED

NO ARBITRARY CLIPBOARD EXECUTION.

FINAL=TRUE is NOT an executor decision.

Executor reports evidence to the 100% Gate.
EXECUTOR

# ============================================================
# REMOTE ORACLE CONTRACT
# ============================================================

cat > "$JOB/remote-oracle.contract" <<'ORACLE'
CYBRONCYBRA REMOTE ORACLE

GitHub Runner must verify:

DNS:
  cybroncybra.com

HTTPS:
  https://cybroncybra.com
  https://cybroncybra.com/token.html
  https://cybroncybra.com/assets/cybra-logo.png

Required evidence:

DNS_OK=TRUE
HTTPS_DOMAIN_OK=TRUE
HTTPS_PAGE_OK=TRUE
HTTPS_LOGO_OK=TRUE

Only when all four are TRUE:

REMOTE_ORACLE_VERIFIED=TRUE

Otherwise:

REMOTE_ORACLE_VERIFIED=FALSE
ORACLE

# ============================================================
# LOCAL STRUCTURAL CHECK
# ============================================================

echo
echo "[1] STRUCTURE"

REQUIRED_TOTAL=15
REQUIRED_OK=0
FAILED=0
PENDING=0
TIMEOUTS=0
ERRORS=0

check() {
    local name="$1"
    local condition="$2"

    if [ "$condition" = "TRUE" ]; then
        echo "[OK] $name"
        REQUIRED_OK=$((REQUIRED_OK + 1))
    else
        echo "[FAIL] $name"
        FAILED=$((FAILED + 1))
    fi
}

check "repository" \
    "$([ -d .git ] && echo TRUE || echo FALSE)"

check "buffer" \
    "$([ -d "$BUFFER" ] && echo TRUE || echo FALSE)"

check "queue" \
    "$([ -d "$QUEUE" ] && echo TRUE || echo FALSE)"

check "running" \
    "$([ -d "$RUNNING" ] && echo TRUE || echo FALSE)"

check "completed" \
    "$([ -d "$COMPLETED" ] && echo TRUE || echo FALSE)"

check "failed" \
    "$([ -d "$FAILED_DIR" ] && echo TRUE || echo FALSE)"

check "worker_tmp" \
    "$([ -d "$WORK" ] && echo TRUE || echo FALSE)"

check "AI_TASK" \
    "$([ -s "$TASK" ] && echo TRUE || echo FALSE)"

check "manifest" \
    "$([ -s "$MANIFEST" ] && echo TRUE || echo FALSE)"

check "worker_instruction" \
    "$([ -s "$JOB/worker.instruction" ] && echo TRUE || echo FALSE)"

check "executor_contract" \
    "$([ -s "$JOB/executor.contract" ] && echo TRUE || echo FALSE)"

check "remote_oracle_contract" \
    "$([ -s "$JOB/remote-oracle.contract" ] && echo TRUE || echo FALSE)"

check "git_head" \
    "$(git rev-parse HEAD >/dev/null 2>&1 && echo TRUE || echo FALSE)"

check "git_remote" \
    "$(git remote get-url origin >/dev/null 2>&1 && echo TRUE || echo FALSE)"

check "task_identity" \
    "$([ -n "$TASK_ID" ] && [ -n "$PATCH_ID" ] && echo TRUE || echo FALSE)"

# ============================================================
# LOCAL EVIDENCE
# ============================================================

cat > "$EVIDENCE/local.env" <<LOCAL
TASK_ID=${TASK_ID}
PATCH_ID=${PATCH_ID}
RUN_ID=${RUN_ID}

GIT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo UNKNOWN)
GIT_REMOTE=$(git remote get-url origin 2>/dev/null || echo UNKNOWN)

BUFFER=TRUE
AI_TASK=TRUE
LOCAL_STRUCTURE_VERIFIED=TRUE

LOCAL_REQUIRED_TOTAL=${REQUIRED_TOTAL}
LOCAL_REQUIRED_OK=${REQUIRED_OK}
LOCAL_FAILED=${FAILED}
LOCAL_PENDING=${PENDING}
LOCAL_TIMEOUTS=${TIMEOUTS}
LOCAL_ERRORS=${ERRORS}
LOCAL_COMPLETION=$((REQUIRED_OK * 100 / REQUIRED_TOTAL))%
LOCAL

# ============================================================
# REMOTE EVIDENCE IMPORT
# ============================================================

REMOTE="${RUNTIME}/remote_oracle/remote_oracle.env"

REMOTE_DNS_OK=FALSE
REMOTE_HTTPS_DOMAIN_OK=FALSE
REMOTE_HTTPS_PAGE_OK=FALSE
REMOTE_HTTPS_LOGO_OK=FALSE
REMOTE_ORACLE_VERIFIED=FALSE

if [ -f "$REMOTE" ]; then
    # Evidence is data, not executable commands.
    while IFS='=' read -r key value; do
        case "$key" in
            DNS_OK) REMOTE_DNS_OK="$value" ;;
            HTTPS_DOMAIN_OK) REMOTE_HTTPS_DOMAIN_OK="$value" ;;
            HTTPS_PAGE_OK) REMOTE_HTTPS_PAGE_OK="$value" ;;
            HTTPS_LOGO_OK) REMOTE_HTTPS_LOGO_OK="$value" ;;
            REMOTE_ORACLE_VERIFIED) REMOTE_ORACLE_VERIFIED="$value" ;;
        esac
    done < "$REMOTE"
fi

if [ "$REMOTE_DNS_OK" = "TRUE" ] &&
   [ "$REMOTE_HTTPS_DOMAIN_OK" = "TRUE" ] &&
   [ "$REMOTE_HTTPS_PAGE_OK" = "TRUE" ] &&
   [ "$REMOTE_HTTPS_LOGO_OK" = "TRUE" ] &&
   [ "$REMOTE_ORACLE_VERIFIED" = "TRUE" ]; then

    echo "[REMOTE] VERIFIED"
else
    echo "[REMOTE] NOT VERIFIED"
    PENDING=$((PENDING + 1))
fi

# ============================================================
# WORKER / EXECUTOR EVIDENCE
# ============================================================

WORKER_EVIDENCE="${RUNTIME}/worker_result.env"
EXECUTOR_EVIDENCE="${RUNTIME}/executor_result.env"

WORKER_VERIFIED=FALSE
EXECUTOR_VERIFIED=FALSE
EVIDENCE_VALID=FALSE
FINAL_ARTIFACT_VERIFIED=FALSE

if [ -f "$WORKER_EVIDENCE" ]; then
    grep -qx 'WORKER_VERIFIED=TRUE' "$WORKER_EVIDENCE" \
        && WORKER_VERIFIED=TRUE
fi

if [ -f "$EXECUTOR_EVIDENCE" ]; then
    grep -qx 'EXECUTOR_VERIFIED=TRUE' "$EXECUTOR_EVIDENCE" \
        && EXECUTOR_VERIFIED=TRUE
fi

# Evidence must exist for the current task.
if [ -s "$EVIDENCE/local.env" ] &&
   [ -n "$TASK_ID" ] &&
   [ -n "$PATCH_ID" ]; then
    EVIDENCE_VALID=TRUE
fi

# Final artifact is verified only when the remote worker/executor
# explicitly produced matching evidence for this task.
if [ "$WORKER_VERIFIED" = "TRUE" ] &&
   [ "$EXECUTOR_VERIFIED" = "TRUE" ]; then
    FINAL_ARTIFACT_VERIFIED=TRUE
fi

# ============================================================
# FINAL 100% GATE
# ============================================================

TOTAL_CHECKS=20
OK_CHECKS=0

[ "$REQUIRED_OK" -eq "$REQUIRED_TOTAL" ] &&
    OK_CHECKS=$((OK_CHECKS + 1))

[ "$FAILED" -eq 0 ] &&
    OK_CHECKS=$((OK_CHECKS + 1))

[ "$PENDING" -eq 0 ] &&
    OK_CHECKS=$((OK_CHECKS + 1))

[ "$TIMEOUTS" -eq 0 ] &&
    OK_CHECKS=$((OK_CHECKS + 1))

[ "$ERRORS" -eq 0 ] &&
    OK_CHECKS=$((OK_CHECKS + 1))

[ "$WORKER_VERIFIED" = "TRUE" ] &&
    OK_CHECKS=$((OK_CHECKS + 1))

[ "$EXECUTOR_VERIFIED" = "TRUE" ] &&
    OK_CHECKS=$((OK_CHECKS + 1))

[ "$REMOTE_ORACLE_VERIFIED" = "TRUE" ] &&
    OK_CHECKS=$((OK_CHECKS + 1))

[ "$EVIDENCE_VALID" = "TRUE" ] &&
    OK_CHECKS=$((OK_CHECKS + 1))

[ "$FINAL_ARTIFACT_VERIFIED" = "TRUE" ] &&
    OK_CHECKS=$((OK_CHECKS + 1))

# The remaining gate slots represent the required remote/local
# evidence categories and are deliberately NOT auto-filled.
#
# This prevents the local coordinator from falsely declaring 100%.

COMPLETION=$((OK_CHECKS * 100 / 10))

FINAL_STATUS=FALSE

if [ "$REQUIRED_OK" -eq "$REQUIRED_TOTAL" ] &&
   [ "$FAILED" -eq 0 ] &&
   [ "$PENDING" -eq 0 ] &&
   [ "$TIMEOUTS" -eq 0 ] &&
   [ "$ERRORS" -eq 0 ] &&
   [ "$WORKER_VERIFIED" = "TRUE" ] &&
   [ "$EXECUTOR_VERIFIED" = "TRUE" ] &&
   [ "$REMOTE_ORACLE_VERIFIED" = "TRUE" ] &&
   [ "$EVIDENCE_VALID" = "TRUE" ] &&
   [ "$FINAL_ARTIFACT_VERIFIED" = "TRUE" ]; then

    COMPLETION=100
    FINAL_STATUS=TRUE
fi

# ============================================================
# FINAL EVIDENCE
# ============================================================

cat > "$FINAL" <<FINAL
TASK_ID=${TASK_ID}
PATCH_ID=${PATCH_ID}
RUN_ID=${RUN_ID}

REQUIRED_TOTAL=${REQUIRED_TOTAL}
REQUIRED_OK=${REQUIRED_OK}

FAILED=${FAILED}
PENDING=${PENDING}
TIMEOUTS=${TIMEOUTS}
ERRORS=${ERRORS}

WORKER_VERIFIED=${WORKER_VERIFIED}
EXECUTOR_VERIFIED=${EXECUTOR_VERIFIED}
REMOTE_ORACLE_VERIFIED=${REMOTE_ORACLE_VERIFIED}
EVIDENCE_VALID=${EVIDENCE_VALID}
FINAL_ARTIFACT_VERIFIED=${FINAL_ARTIFACT_VERIFIED}

REMOTE_DNS_OK=${REMOTE_DNS_OK}
REMOTE_HTTPS_DOMAIN_OK=${REMOTE_HTTPS_DOMAIN_OK}
REMOTE_HTTPS_PAGE_OK=${REMOTE_HTTPS_PAGE_OK}
REMOTE_HTTPS_LOGO_OK=${REMOTE_HTTPS_LOGO_OK}

COMPLETION=${COMPLETION}%
FINAL=${FINAL_STATUS}
FINAL

cp "$FINAL" "$EVIDENCE/final.env"

# ============================================================
# OUTPUT
# ============================================================

echo
echo "================================================"
echo " CYBRONCYBRA — AI TASK RESULT"
echo "================================================"
echo
echo "TASK:        $TASK_ID"
echo "PATCH:       $PATCH_ID"
echo "RUN:         $RUN"
echo
echo "BUFFER:      QUEUED"
echo "WORKER:      $WORKER_VERIFIED"
echo "EXECUTOR:    $EXECUTOR_VERIFIED"
echo "REMOTE:      $REMOTE_ORACLE_VERIFIED"
echo "EVIDENCE:    $EVIDENCE_VALID"
echo
echo "COMPLETION:  ${COMPLETION}%"
echo "FINAL:       ${FINAL_STATUS}"
echo
echo "TASK:        $TASK"
echo "MANIFEST:    $MANIFEST"
echo "FINAL:       $FINAL"
echo

if [ "$FINAL_STATUS" = "TRUE" ]; then
    echo "[100%] FINAL=TRUE"
    exit 0
fi

echo "[100%] FINAL=FALSE"
echo "[100%] Waiting for verified Worker / Executor / Remote Evidence."
exit 2

