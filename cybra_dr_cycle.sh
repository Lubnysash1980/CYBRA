#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"; cd "$ROOT"

GEN="cybra_disaster_recovery_test.sh"
REG="cybra_register_disaster_recovery_100.sh"
APPLY="cybra_dr_apply.sh"
CYCLE="cybra_dr_cycle.sh"

REPORT_DIR="hash_ecosystem/disaster_recovery_tests"
GLOBAL="hash_ecosystem/global_runtime_state.json"
MANIFEST="hash_ecosystem/self_recovery_dna/disaster_recovery_true100_manifest.txt"
TASK_JSON="hash_ecosystem/ai_tasks/AI-CYBRA-DISASTER-RECOVERY-100-001.json"
EVIDENCE_DIR="orders/ROBOTICS-UA-0001/evidence"

MODE="${1:-all}"
ASSUME_YES=0
[ "${2:-}" = "--yes" ] && ASSUME_YES=1

latest_report()   { ls -t "$REPORT_DIR"/test_*.json 2>/dev/null | head -1 || true; }
latest_registry() { ls -t "$REPORT_DIR"/AI-CYBRA-DISASTER-RECOVERY-100-001_*.json 2>/dev/null | head -1 || true; }
latest_evidence() { ls -t "$EVIDENCE_DIR"/AI-CYBRA-DISASTER-RECOVERY-100-001_*.json 2>/dev/null | head -1 || true; }

do_check() {
    echo "============================================================"
    echo " CHECK"
    echo "============================================================"
    local fail=0

    for f in "$GEN" "$REG"; do
        if [ ! -f "$f" ]; then echo "MISSING: $f"; fail=1; continue; fi
        if [ ! -x "$f" ]; then echo "NOT-EXEC: $f"; fail=1; else echo "OK script: $f"; fi
    done

    local report
    report="$(latest_report)"
    if [ -z "$report" ]; then
        echo "NO DR REPORT"; fail=1
    else
        echo "REPORT=$report"
        if python3 - "$report" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert x.get("version")=="HARDENED_V2",     "version"
assert x.get("status")=="TRUE_100",          "status"
assert x.get("dna_stable") is True,          "dna_stable"
assert x.get("passed")==6 and x.get("total")==6, "count"
for L in x["levels"]:
    assert L["result"]=="PASS",                   f"L{L['level']} result"
    assert L["damage_hash"]!=L["recovered_hash"], f"L{L['level']} tautology"
    assert L.get("baseline_match") is True,       f"L{L['level']} baseline"
print("REPORT_VALID=TRUE")
PY
        then :; else echo "REPORT INVALID"; fail=1; fi
    fi

    if [ -f "$MANIFEST" ]; then echo "OK manifest"; else echo "MISSING manifest"; fail=1; fi
    [ -f "$TASK_JSON" ] && echo "OK task" || { echo "MISSING task"; fail=1; }
    [ -n "$(latest_registry)" ] && echo "OK registry" || { echo "MISSING registry"; fail=1; }
    [ -n "$(latest_evidence)" ] && echo "OK evidence" || { echo "MISSING evidence"; fail=1; }

    if [ -n "$report" ]; then
        if python3 - "$GLOBAL" "$report" <<'PY'
import json,sys,os
g,rep=sys.argv[1:]
if not os.path.exists(g):
    print("GLOBAL missing"); sys.exit(1)
d=json.load(open(g)).get("disaster_recovery_baseline")
if not d:
    print("GLOBAL no DR baseline"); sys.exit(1)
if d.get("version")!="HARDENED_V2":
    print(f"GLOBAL stale version={d.get('version')}"); sys.exit(1)
r=json.load(open(rep))
if d.get("reference_sha256")!=r.get("reference_sha256"):
    print("GLOBAL reference mismatch"); sys.exit(1)
if d.get("dna_stable") is not True:
    print("GLOBAL dna_stable false"); sys.exit(1)
print("GLOBAL_OK")
PY
        then :; else fail=1; fi
    fi

    local stray
    stray="$(find . -maxdepth 1 \( -name '*.hardened' -o -name '*.hardened_*' \) -type f 2>/dev/null | wc -l)"
    if [ "$stray" -gt 0 ]; then
        echo "STALE hardened files: $stray"
        find . -maxdepth 1 \( -name '*.hardened' -o -name '*.hardened_*' \) -type f 2>/dev/null | sed 's/^/  /'
        fail=1
    else
        echo "OK no stray .hardened"
    fi

    echo "---"
    if [ "$fail" -eq 0 ]; then echo "CHECK=OK"; return 0; else echo "CHECK=FAIL"; return 1; fi
}

do_fix() {
    echo "============================================================"
    echo " FIX"
    echo "============================================================"

    chmod +x "$GEN" "$REG" 2>/dev/null || true
    echo "exec bits ensured"

    local removed=0 f
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        rm -f "$f"; removed=$((removed+1))
    done < <(find . -maxdepth 1 \( -name '*.hardened' -o -name '*.hardened_*' \) -type f 2>/dev/null)
    echo "removed $removed stale .hardened file(s)"

    local report
    report="$(latest_report)"
    [ -n "$report" ] || { echo "FATAL: no report"; return 1; }

    python3 - "$report" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert x.get("version")=="HARDENED_V2"
assert x.get("status")=="TRUE_100"
assert x.get("dna_stable") is True
for L in x["levels"]:
    assert L["result"]=="PASS"
    assert L["damage_hash"]!=L["recovered_hash"]
    assert L.get("baseline_match") is True
print("REFUSE_CHECK=OK")
PY

    local stamp backup
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    if [ -f "$GLOBAL" ]; then
        backup="$GLOBAL.bak_$stamp"
        cp -a "$GLOBAL" "$backup"
        echo "backup: $backup"
    fi

    local sha dsha iso
    sha="$(sha256sum "$report" | awk '{print $1}')"
    dsha="$(printf '%s' "$sha" | sha256sum | awk '{print $1}')"
    iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    python3 - "$report" "$GLOBAL" "$sha" "$dsha" "$iso" <<'PY'
import json,sys,os
rep,glob,sha,dsha,iso=sys.argv[1:]
r=json.load(open(rep))
g=json.load(open(glob)) if os.path.exists(glob) else {}
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
  "dna_hash_before":r.get("dna_hash_before"),
  "dna_hash_after":r.get("dna_hash_after"),
  "source_report":rep,
  "source_report_sha256":sha,
  "source_report_double_sha256":dsha,
  "production_modified":False,
  "physical_manufacturing":False
}
json.dump(g, open(glob,"w"), indent=2)
with open(glob,"a") as f: f.write("\n")
print(f"GLOBAL UPDATED={glob}")
PY

    echo "FIX=DONE"
}

do_add() {
    echo "============================================================"
    echo " ADD"
    echo "============================================================"

    local report registry evidence
    report="$(latest_report)"
    registry="$(latest_registry)"
    evidence="$(latest_evidence)"

    local files=(
        "$GEN"
        "$REG"
        "$APPLY"
        "$CYCLE"
        "$TASK_JSON"
        "$report"
        "$registry"
        "$MANIFEST"
        "$GLOBAL"
        "$evidence"
    )

    local to_add=()
    local f
    for f in "${files[@]}"; do
        [ -n "$f" ] && [ -f "$f" ] && to_add+=("$f")
    done

    echo "staging:"
    printf '  %s\n' "${to_add[@]}"
    echo

    git add -- "${to_add[@]}"

    echo "--- staged ---"
    git diff --cached --stat
    echo

    if git diff --cached --quiet; then
        echo "NOTHING STAGED"
        return 0
    fi

    local msg="CYBRA: harden DR TRUE_100 — baseline+DNA verified, global state synced"
    local ans="n"
    if [ "$ASSUME_YES" = "1" ]; then
        ans="y"
    else
        read -r -p "commit? [y/N] " ans
    fi
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
        git commit -m "$msg"
        echo "COMMIT=$(git rev-parse HEAD)"
    else
        echo "staged only (no commit)"
    fi
}

case "$MODE" in
    check) do_check ;;
    fix)   do_fix ;;
    add)   do_add ;;
    all)
        do_check || { echo; echo "CHECK failed — running FIX"; do_fix; echo; do_check; }
        echo
        do_add
        ;;
    *) echo "usage: $0 {check|fix|add|all} [--yes]"; exit 2 ;;
esac
