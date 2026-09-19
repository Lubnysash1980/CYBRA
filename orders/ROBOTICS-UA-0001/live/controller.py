#!/usr/bin/env python3
import json
import hashlib
import os
import subprocess
import sys
from datetime import datetime, timezone

ORDER = "ROBOTICS-UA-0001"
LIVE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(LIVE)
CONTROL = os.path.join(BASE, "control")
LOGS = os.path.join(LIVE, "logs")

os.makedirs(CONTROL, exist_ok=True)
os.makedirs(LOGS, exist_ok=True)

started = datetime.now(timezone.utc)

steps = [
    ("update", os.path.join(LIVE, "update.py")),
    ("equipment", os.path.join(LIVE, "equipment.py")),
    ("problem", os.path.join(LIVE, "problem.py")),
    ("dashboard", os.path.join(LIVE, "dashboard.py")),
]

results = []

for name, script in steps:
    if not os.path.isfile(script):
        results.append({
            "task": name,
            "status": "FAILED",
            "reason": "SCRIPT_MISSING"
        })
        continue

    proc = subprocess.run(
        [sys.executable, script],
        capture_output=True,
        text=True
    )

    results.append({
        "task": name,
        "status": "SUCCESS" if proc.returncode == 0 else "FAILED",
        "returncode": proc.returncode,
        "stdout_sha256": hashlib.sha256(
            proc.stdout.encode()
        ).hexdigest(),
        "stderr": proc.stderr[-1000:]
    })

finished = datetime.now(timezone.utc)

all_success = bool(results) and all(
    x["status"] == "SUCCESS" for x in results
)

execution = {
    "order": ORDER,
    "execution_id": hashlib.sha256(
        (
            ORDER +
            started.isoformat() +
            finished.isoformat()
        ).encode()
    ).hexdigest(),
    "execution_type": "LOCAL_SOFTWARE_RUNTIME_TEST",
    "execution_completed": all_success,
    "physical_manufacturing_completed": False,
    "physical_equipment_attached": False,
    "started_at": started.isoformat(),
    "finished_at": finished.isoformat(),
    "tasks": results,
}

canonical = json.dumps(
    execution,
    sort_keys=True,
    separators=(",", ":")
)

execution["receipt_sha256"] = hashlib.sha256(
    canonical.encode()
).hexdigest()

receipt = os.path.join(
    LOGS,
    "execution_receipt.json"
)

with open(receipt, "w") as f:
    json.dump(execution, f, indent=2)

print(json.dumps(execution, indent=2))
print()
print("EXECUTION_RECEIPT=" + receipt)
print("EXECUTION_COMPLETED=" + str(all_success).lower())
