#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"; cd "$ROOT"

REPORT_DIR="$ROOT/hash_ecosystem/disaster_recovery_tests"
REPORT="$(ls -t "$REPORT_DIR"/test_*.json 2>/dev/null | head -1)"
[ -n "$REPORT" ] || { echo "ERROR: no DR report"; exit 1; }

GLOBAL="$ROOT/hash_ecosystem/global_runtime_state.json"

echo "============================================================"
echo " CYBRA — UPDATE GLOBAL RUNTIME STATE (DR BASELINE)"
echo "============================================================"
echo "REPORT=$REPORT"
echo "GLOBAL=$GLOBAL"
echo

# safety: refuse if DR report is not hardened TRUE_100
python3 - "$REPORT" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert x.get("version")=="HARDENED_V2",     "not hardened"
assert x.get("status")=="TRUE_100",          "not TRUE_100"
assert x.get("dna_stable") is True,          "DNA drift"
assert x.get("passed")==6 and x.get("total")==6
for L in x["levels"]:
    assert L["result"]=="PASS",                          f"L{L['level']} not PASS"
    assert L["damage_hash"]!=L["recovered_hash"],        f"L{L['level']} tautology"
    assert L.get("baseline_match") is True,              f"L{L['level']} baseline mismatch"
print("REFUSE_CHECK=OK")
PY

REPORT_SHA="$(sha256sum "$REPORT" | awk '{print $1}')"
REPORT_DOUBLE_SHA="$(printf '%s' "$REPORT_SHA" | sha256sum | awk '{print $1}')"
ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# backup
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
cp -a "$GLOBAL" "$GLOBAL.bak_$STAMP"
echo "backup: $GLOBAL.bak_$STAMP"

python3 - "$REPORT" "$GLOBAL" "$REPORT_SHA" "$REPORT_DOUBLE_SHA" "$ISO" <<'PY'
import json,sys,os

rep,glob,sha,dsha,iso=sys.argv[1:]
r=json.load(open(rep))

if os.path.exists(glob):
    g=json.load(open(glob))
else:
    g={}

g["disaster_recovery_baseline"]={
  "task_id":"AI-CYBRA-DISASTER-RECOVERY-100-001",
  "timestamp":iso,
  "version":"HARDENED_V2",
  "status":"TRUE_100",
  "percent":100.0,
  "levels_tested":6,
  "levels_passed":6,
  "baseline_match_all":True,
  "dna_stable":True,
  "reference_sha256":r.get("reference_sha256"),
  "dna_hash":"852d8245571895e7760c4a90097763924bab50e8689cf337e86d5ad908bb2ca4",
  "source_report":rep,
  "source_report_sha256":sha,
  "source_report_double_sha256":dsha,
  "production_modified":False,
  "physical_manufacturing":False
}

json.dump(g, open(glob,"w"), indent=2)
with open(glob,"a") as f: f.write("\n")
print(f"UPDATED={glob}")
PY

echo
echo "GLOBAL RUNTIME STATE UPDATED (NOT committed)"
echo "Run 'git diff $GLOBAL' to inspect."
