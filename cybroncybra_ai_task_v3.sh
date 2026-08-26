#!/data/data/com.termux/files/usr/bin/bash

set -u
set -o pipefail

ROOT="$HOME/CYBRA"
RUNTIME="$ROOT/runtime"
BUFFER="$RUNTIME/buffer"
TRIAD="$RUNTIME/triad"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
TASK_ID="CYBRONCYBRA-TRIAD-$TS"
TASK="$BUFFER/queue/$TASK_ID"

mkdir -p \
  "$TASK" \
  "$BUFFER/running" \
  "$BUFFER/completed" \
  "$BUFFER/failed" \
  "$TRIAD/git" \
  "$TRIAD/termux" \
  "$TRIAD/temp_server_venv"

cat > "$TASK/TASK.env" <<TASKENV
TASK_ID=$TASK_ID
TASK_TYPE=AI_TRIAD_TASK
PROTOCOL_VERSION=3

EXECUTION_MODE=BLACK_BOX
INDEPENDENT_BUFFER=TRUE

GIT_WORKER_REQUIRED=TRUE
TERMUX_WORKER_REQUIRED=TRUE
TEMP_SERVER_VENV_WORKER_REQUIRED=TRUE

GIT_EVIDENCE_REQUIRED=TRUE
TERMUX_EVIDENCE_REQUIRED=TRUE
TEMP_SERVER_VENV_EVIDENCE_REQUIRED=TRUE

HASH_EVIDENCE_REQUIRED=TRUE
INDEPENDENT_VALIDATION_REQUIRED=TRUE

FINAL_RULE=TRUE_ONLY_AT_100_PERCENT
FAIL_CLOSED=TRUE
MANUAL_TRUE_FORBIDDEN=TRUE
AI_TRUE_FORBIDDEN=TRUE
TASKENV

cat > "$TASK/TRIAD_CONTRACT.md" <<'CONTRACT'
# CYBRONCYBRA TRIAD EXECUTION CONTRACT

The AI only creates the task.

The AI does NOT:
- execute the task;
- approve its own result;
- create remote evidence;
- set FINAL=TRUE.

## THREE INDEPENDENT EXECUTION LAYERS

### 1. GIT
Responsible for repository/hash evidence:
- repository identity
- HEAD
- working state
- commit/diff evidence
- remote evidence when applicable
- cryptographic evidence

### 2. TERMUX
Responsible for local execution/control:
- task intake
- orchestration
- worker control
- local evidence
- exit status

### 3. TEMP SERVER + VENV
Responsible for isolated execution:
- temporary environment
- dependency validation
- worker execution
- isolated evidence
- execution result

## INDEPENDENCE

One layer may not declare another layer successful.

Missing evidence is NOT success.

Unknown is NOT success.

PENDING is NOT success.

Failure is NOT success.

## FINAL

FINAL=TRUE is permitted only when:

GIT=TRUE
TERMUX=TRUE
TEMP_SERVER_VENV=TRUE
HASH=TRUE
EVIDENCE=TRUE
COMPLETION=100%

Otherwise:

FINAL=FALSE
CONTRACT

cat > "$TASK/WORKER_INSTRUCTION.md" <<'WORKER'
# AI TASK — BLACK BOX TRIAD

Process this TASK_ID through the three independent execution layers.

Do not return internal implementation details as the primary interface.

Return only the verified external result:

TASK_ID
STATUS
COMPLETION
FINAL
EVIDENCE_HASH

The internal systems may solve their own implementation problems.

The AI must not convert an unsuccessful result into TRUE.
WORKER

cat > "$TASK/BINARY_BUFFER.md" <<'BINARY'
# INDEPENDENT BINARY BUFFER

If binary data is involved:

INCOMING
→ HASH
→ QUARANTINE
→ TYPE/SIZE VALIDATION
→ INDEPENDENT VERIFICATION
→ WORKER
→ EXECUTOR
→ POST-EXECUTION HASH
→ EVIDENCE
→ 100% GATE

Binary data must not bypass the independent buffer.
BINARY

cat > "$TASK/RESULT_SCHEMA" <<'RESULT'
TASK_ID=<task id>
STATUS=COMPLETED|FAILED|PENDING
COMPLETION=<0-100>
FINAL=TRUE|FALSE
EVIDENCE_HASH=<verified hash or EMPTY>
RESULT_SCHEMA
RESULT

sha256sum "$TASK/TASK.env" \
  "$TASK/TRIAD_CONTRACT.md" \
  "$TASK/WORKER_INSTRUCTION.md" \
  "$TASK/BINARY_BUFFER.md" \
  > "$TASK/TASK_MANIFEST.sha256"

cat > "$TASK/STATE" <<STATE
TASK_ID=$TASK_ID
STATUS=QUEUED
GIT=FALSE
TERMUX=FALSE
TEMP_SERVER_VENV=FALSE
HASH=FALSE
EVIDENCE=FALSE
COMPLETION=0
FINAL=FALSE
STATE

echo
echo "================================================"
echo " CYBRONCYBRA — TRIAD AI TASK"
echo "================================================"
echo "TASK_ID:       $TASK_ID"
echo "BUFFER:        $TASK"
echo
echo "GIT:           REQUIRED"
echo "TERMUX:        REQUIRED"
echo "TEMP SERVER:   REQUIRED"
echo "VENV:          REQUIRED"
echo "HASH:          REQUIRED"
echo "EVIDENCE:      REQUIRED"
echo
echo "BLACK_BOX:     TRUE"
echo "FAIL_CLOSED:   TRUE"
echo "100% GATE:     TRUE"
echo
echo "FINAL=FALSE"
echo "================================================"
