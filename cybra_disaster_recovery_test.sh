#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"
ORDER="ROBOTICS-UA-0001"
SOURCE="$ROOT/orders/$ORDER"

TEST_ROOT="$ROOT/runtime/disaster_recovery_test"
REPORT_DIR="$ROOT/hash_ecosystem/disaster_recovery_tests"
DNA_DIR="$ROOT/hash_ecosystem/self_recovery_dna"

rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT" "$REPORT_DIR"

REPORT="$REPORT_DIR/test_$(date -u +%Y%m%dT%H%M%SZ).json"
TEST="$TEST_ROOT/cybra"

echo "============================================================"
echo " CYBRA — DISASTER RECOVERY (HARDENED_V2)"
echo "============================================================"
echo "SOURCE=$SOURCE"
echo "REPORT=$REPORT"
echo "production CYBRA не видаляється."
echo

build_image() {
    rm -rf "$TEST"
    mkdir -p "$TEST/control" "$TEST/evidence" \
             "$TEST/runtime_snapshot" "$TEST/live/logs" \
             "$TEST/hash_ecosystem"
    if [ -d "$SOURCE/control" ];          then cp -a "$SOURCE/control/."          "$TEST/control/"          2>/dev/null || true; fi
    if [ -d "$SOURCE/evidence" ];         then cp -a "$SOURCE/evidence/."         "$TEST/evidence/"         2>/dev/null || true; fi
    if [ -d "$SOURCE/runtime_snapshot" ]; then cp -a "$SOURCE/runtime_snapshot/." "$TEST/runtime_snapshot/" 2>/dev/null || true; fi
    if [ -d "$SOURCE/live" ];             then cp -a "$SOURCE/live/."             "$TEST/live/"             2>/dev/null || true; fi
    if [ -d "$DNA_DIR" ];                 then cp -a "$DNA_DIR"                   "$TEST/hash_ecosystem/"   2>/dev/null || true; fi
    mkdir -p "$TEST/software"
    for f in "$ROOT/cybra_ai_master_orchestrator.py" \
             "$ROOT/robotics_ai_execute_verify_patch.sh" \
             "$ROOT/robotics_verify_now.sh" \
             "$ROOT/real_executor.py"; do
        if [ -f "$f" ]; then cp "$f" "$TEST/software/"; fi
    done
}

tree_hash() {
    find "$TEST" -type f ! -name '*.log' -print0 2>/dev/null \
        | sort -z | xargs -0 -r sha256sum 2>/dev/null \
        | sha256sum | awk '{print $1}'
}

dna_hash() {
    if [ ! -d "$DNA_DIR" ]; then echo "NONE"; return; fi
    find "$DNA_DIR" -type f -print0 2>/dev/null \
        | sort -z | xargs -0 -r sha256sum 2>/dev/null \
        | sha256sum | awk '{print $1}'
}

DNA_HASH_BEFORE="$(dna_hash)"
build_image
REFERENCE_HASH="$(tree_hash)"

echo "DNA_HASH_BEFORE = $DNA_HASH_BEFORE"
echo "REFERENCE_HASH  = $REFERENCE_HASH"
echo

recover_test() {
    for dir in control evidence runtime_snapshot live; do
        rm -rf "$TEST/$dir"; mkdir -p "$TEST/$dir"
        if [ -d "$SOURCE/$dir" ]; then
            cp -a "$SOURCE/$dir/." "$TEST/$dir/" 2>/dev/null || true
        fi
    done
    rm -rf "$TEST/hash_ecosystem/self_recovery_dna"
    if [ -d "$DNA_DIR" ]; then cp -a "$DNA_DIR" "$TEST/hash_ecosystem/"; fi
    mkdir -p "$TEST/software"
    for f in "$ROOT/cybra_ai_master_orchestrator.py" \
             "$ROOT/robotics_ai_execute_verify_patch.sh" \
             "$ROOT/robotics_verify_now.sh" \
             "$ROOT/real_executor.py"; do
        if [ -f "$f" ]; then cp "$f" "$TEST/software/"; fi
    done
}

validate_test() {
    [ -f "$TEST/control/state.json" ]               || return 1
    [ -f "$TEST/control/required_tasks.json" ]      || return 1
    [ -f "$TEST/evidence/final_proof.json" ]        || return 1
    [ -f "$TEST/live/controller.py" ]               || return 1
    [ -f "$TEST/live/logs/execution_receipt.json" ] || return 1
    python3 - "$TEST/live/logs/execution_receipt.json" <<'PY' || return 1
import json,sys
x=json.load(open(sys.argv[1]))
assert x.get("order")=="ROBOTICS-UA-0001"
assert x.get("execution_completed") is True
assert x.get("execution_type")=="LOCAL_SOFTWARE_RUNTIME_TEST"
PY
    python3 - "$TEST/evidence/final_proof.json" <<'PY' || return 1
import json,sys
x=json.load(open(sys.argv[1]))
assert x.get("order")=="ROBOTICS-UA-0001"
assert x.get("rule")=="TRUE_ONLY_AT_100_PERCENT_REQUIRED_CONFIRMATION"
PY
    return 0
}

damage_level() {
    case "$1" in
        1) rm -f "$TEST/control/state.json" ;;
        2) rm -f "$TEST/control/state.json" \
                 "$TEST/control/required_tasks.json" \
                 "$TEST/evidence/final_proof.json" ;;
        3) rm -f "$TEST/live/controller.py" \
                 "$TEST/live/logs/execution_receipt.json" ;;
        4) rm -f "$TEST/control/state.json" \
                 "$TEST/evidence/final_proof.json"
           printf '%s\n' '{"hash":"CORRUPTED","state":"INVALID"}' \
                > "$TEST/control/corrupted_hash_state.json" ;;
        5) rm -rf "$TEST/control" "$TEST/evidence" "$TEST/runtime_snapshot"
           mkdir -p "$TEST/control" "$TEST/evidence" "$TEST/runtime_snapshot" ;;
        6) rm -rf "$TEST/control" "$TEST/evidence" \
                  "$TEST/runtime_snapshot" "$TEST/live"
           mkdir -p "$TEST/control" "$TEST/evidence" \
                    "$TEST/runtime_snapshot" "$TEST/live/logs"
           printf '%s\n' '{"TOTAL_LOSS":"SIMULATED","RECOVERY_REQUIRED":true}' \
                > "$TEST/control/DATA_LOSS_MARKER.json" ;;
        *) echo "unknown level $1"; return 1 ;;
    esac
}

python3 - "$REPORT" "$REFERENCE_HASH" "$DNA_HASH_BEFORE" <<'PY'
import json,sys
out,ref,dna=sys.argv[1:]
json.dump({
  "test":"CYBRA_DISASTER_RECOVERY",
  "version":"HARDENED_V2",
  "reference_sha256":ref,
  "dna_hash_before":dna,
  "rule":"TRUE_ONLY_AT_100_PERCENT_REQUIRED_CONFIRMATION",
  "production_modified":False,
  "recovery_source":"orders/ROBOTICS-UA-0001 + hash_ecosystem/self_recovery_dna",
  "levels":[]
}, open(out,"w"), indent=2)
with open(out,"a") as f: f.write("\n")
PY

for LEVEL in 1 2 3 4 5 6; do
    echo "------------------------------------------------------------"
    echo " LEVEL $LEVEL"
    echo "------------------------------------------------------------"
    build_image
    damage_level "$LEVEL"
    DAMAGE_HASH="$(tree_hash)"
    echo "DAMAGED_HASH   = $DAMAGE_HASH"
    recover_test
    RECOVERED_HASH="$(tree_hash)"
    echo "RECOVERED_HASH = $RECOVERED_HASH"
    RESULT="PASS"
    validate_test || RESULT="FAIL_STRUCTURE"
    BASELINE_MATCH=false
    if [ "$RECOVERED_HASH" = "$REFERENCE_HASH" ]; then BASELINE_MATCH=true; fi
    if [ "$RESULT" = "PASS" ] && [ "$BASELINE_MATCH" != "true" ]; then
        RESULT="FAIL_BASELINE_MISMATCH"
    fi
    if [ "$DAMAGE_HASH" = "$RECOVERED_HASH" ]; then
        RESULT="FAIL_TAUTOLOGY"
    fi
    echo "BASELINE_MATCH = $BASELINE_MATCH"
    echo "RESULT         = $RESULT"
    python3 - "$REPORT" "$LEVEL" "$DAMAGE_HASH" "$RECOVERED_HASH" \
                  "$RESULT" "$BASELINE_MATCH" <<'PY'
import json,sys
p,lvl,d,r,res,m=sys.argv[1:]
x=json.load(open(p))
x["levels"].append({
  "level":int(lvl),"damage_hash":d,"recovered_hash":r,
  "baseline_match": m=="true","result":res,"production_modified":False
})
json.dump(x, open(p,"w"), indent=2)
with open(p,"a") as f: f.write("\n")
PY
done

DNA_HASH_AFTER="$(dna_hash)"
echo
echo "DNA_HASH_AFTER = $DNA_HASH_AFTER"

python3 - "$REPORT" "$DNA_HASH_AFTER" <<'PY'
import json,sys
p,dna_after=sys.argv[1:]
x=json.load(open(p))
x["dna_hash_after"]=dna_after
x["dna_stable"]=(x.get("dna_hash_before")==dna_after)
passed=sum(1 for i in x["levels"] if i["result"]=="PASS")
total=len(x["levels"])
x["passed"]=passed; x["total"]=total
x["percent"]=round((passed/total)*100,2) if total else 0
if passed==total and x["dna_stable"]:
    x["status"]="TRUE_100"
    x["cause"]="ALL_SIMULATED_DATA_LOSS_LEVELS_RECOVERED_AND_BASELINE_VERIFIED"
elif passed==total:
    x["status"]="PENDING"; x["cause"]="DNA_DRIFT_DETECTED"
else:
    x["status"]="PENDING"; x["cause"]="RECOVERY_LEVEL_FAILED"
x["safety"]={"production_modified":False,
             "physical_manufacturing":False,
             "physical_equipment_attached":False}
json.dump(x, open(p,"w"), indent=2)
with open(p,"a") as f: f.write("\n")
print()
print("============================================================")
print(" CYBRA DISASTER RECOVERY FINAL — HARDENED_V2")
print("============================================================")
print(f"PASSED      = {passed}/{total}")
print(f"PERCENT     = {x['percent']}")
print(f"DNA_STABLE  = {x['dna_stable']}")
print(f"STATUS      = {x['status']}")
print(f"CAUSE       = {x['cause']}")
PY
