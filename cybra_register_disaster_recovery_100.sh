#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"; cd "$ROOT"
ORDER="ROBOTICS-UA-0001"
TASK_ID="AI-CYBRA-DISASTER-RECOVERY-100-001"

REPORT_DIR="$ROOT/hash_ecosystem/disaster_recovery_tests"
REPORT="$(ls -t "$REPORT_DIR"/test_*.json 2>/dev/null | head -1)"
[ -n "$REPORT" ] || { echo "ERROR: no DR report"; exit 1; }

DNA_DIR="$ROOT/hash_ecosystem/self_recovery_dna"
TASK_DIR="$ROOT/hash_ecosystem/ai_tasks"
EVIDENCE="$ROOT/orders/$ORDER/evidence"
mkdir -p "$DNA_DIR" "$TASK_DIR" "$REPORT_DIR" "$EVIDENCE"

echo "============================================================"
echo " CYBRA — REGISTER DR TRUE_100 (HARDENED)"
echo "============================================================"
echo "REPORT=$REPORT"
echo

python3 - "$REPORT" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert x.get("test")=="CYBRA_DISASTER_RECOVERY",  "wrong test"
assert x.get("version")=="HARDENED_V2",            "not hardened report"
assert x.get("passed")==6 and x.get("total")==6,   "not 6/6"
assert float(x.get("percent",0))==100.0,           "not 100%"
assert x.get("status")=="TRUE_100",                "not TRUE_100"
assert x.get("cause")=="ALL_SIMULATED_DATA_LOSS_LEVELS_RECOVERED_AND_BASELINE_VERIFIED", "cause"
assert x.get("production_modified") is False,      "prod modified"
assert x.get("dna_stable") is True,                "DNA drift"
s=x.get("safety",{})
assert s.get("physical_manufacturing") is False
assert s.get("physical_equipment_attached") is False
lv=x.get("levels",[])
assert len(lv)==6, "not 6 levels"
for L in lv:
    n=L["level"]
    assert L["result"]=="PASS",                   f"L{n} not PASS"
    assert L["damage_hash"]!=L["recovered_hash"], f"L{n} tautology"
    assert L.get("baseline_match") is True,       f"L{n} baseline not matched"
    assert L.get("production_modified") is False, f"L{n} prod modified"
print("REPORT_VALID=TRUE (HARDENED)")
PY

REPORT_SHA="$(sha256sum "$REPORT" | awk '{print $1}')"
REPORT_DOUBLE_SHA="$(printf '%s' "$REPORT_SHA" | sha256sum | awk '{print $1}')"
NOW="$(date -u +%Y%m%dT%H%M%SZ)"
ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

TASK_FILE="$TASK_DIR/${TASK_ID}.json"
REGISTRY="$REPORT_DIR/${TASK_ID}_${NOW}.json"
EVIDENCE_FILE="$EVIDENCE/${TASK_ID}_${NOW}.json"

python3 - "$REPORT" "$TASK_FILE" "$REGISTRY" "$EVIDENCE_FILE" \
          "$TASK_ID" "$ISO" "$ORDER" "$REPORT_SHA" "$REPORT_DOUBLE_SHA" <<'PY'
import json,sys
rep,task_f,reg_f,ev_f,tid,iso,order,sha,dsha=sys.argv[1:]
r=json.load(open(rep))
task={
 "task_id":tid,"timestamp":iso,"status":"TRUE_100","percent":100.0,
 "test":"CYBRA_DISASTER_RECOVERY","version":"HARDENED_V2",
 "levels_tested":6,"levels_passed":6,
 "cause":r["cause"],
 "source_report":rep,
 "source_report_sha256":sha,
 "source_report_double_sha256":dsha,
 "reference_sha256":r.get("reference_sha256"),
 "dna_hash_before":r.get("dna_hash_before"),
 "dna_hash_after":r.get("dna_hash_after"),
 "dna_stable":r.get("dna_stable"),
 "recovery_source":r.get("recovery_source"),
 "production_modified":False,
 "physical_manufacturing":False,
 "physical_equipment_attached":False,
 "rule":"TRUE_ONLY_AT_100_PERCENT_REQUIRED_CONFIRMATION"
}
json.dump(task, open(task_f,"w"), indent=2)
with open(task_f,"a") as f: f.write("\n")
reg={
 "registry_type":"CYBRA_DISASTER_RECOVERY_TRUE_100",
 "task_id":tid,"timestamp":iso,"order":order,
 "status":"TRUE_100","percent":100.0,"version":"HARDENED_V2",
 "levels":{"tested":6,"passed":6},
 "source_report":rep,
 "source_report_sha256":sha,
 "source_report_double_sha256":dsha,
 "reference_sha256":r.get("reference_sha256"),
 "dna_stable":r.get("dna_stable"),
 "recovery":{f"level_{i['level']}":i["result"] for i in r["levels"]},
 "baseline_match_all":all(i.get("baseline_match") for i in r["levels"]),
 "safety":{"production_modified":False,
           "physical_manufacturing":False,
           "physical_equipment_attached":False,
           "manufacturing_execution_enabled":False},
 "rule":"TRUE_ONLY_AT_100_PERCENT_REQUIRED_CONFIRMATION"
}
json.dump(reg, open(reg_f,"w"), indent=2)
with open(reg_f,"a") as f: f.write("\n")
json.dump(reg, open(ev_f,"w"),  indent=2)
with open(ev_f,"a") as f: f.write("\n")
print(f"WROTE task={task_f}")
print(f"WROTE registry={reg_f}")
print(f"WROTE evidence={ev_f}")
PY

MANIFEST="$DNA_DIR/disaster_recovery_true100_manifest.txt"
{
  echo "TASK_ID=$TASK_ID"
  echo "TIMESTAMP=$ISO"
  echo "VERSION=HARDENED_V2"
  echo "STATUS=TRUE_100"
  echo "PERCENT=100.0"
  echo "LEVELS_TESTED=6"
  echo "LEVELS_PASSED=6"
  echo "REPORT=$REPORT"
  echo "REPORT_SHA256=$REPORT_SHA"
  echo "REPORT_DOUBLE_SHA256=$REPORT_DOUBLE_SHA"
  echo "BASELINE_MATCH_ALL=true"
  echo "DNA_STABLE=true"
  echo "PRODUCTION_MODIFIED=false"
  echo "PHYSICAL_MANUFACTURING=false"
  echo "MANUFACTURING_EXECUTION_ENABLED=false"
} > "$MANIFEST"

echo
echo "REGISTRATION PREPARED (files written, NOT committed)"
echo "GLOBAL_RUNTIME_STATE.json — NOT touched by this script."
echo "Run 'git status --short' to inspect before committing."
