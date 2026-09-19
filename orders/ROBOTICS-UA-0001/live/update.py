#!/usr/bin/env python3
import json
import os
from datetime import datetime, timezone

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTROL = os.path.join(BASE, "control")
os.makedirs(CONTROL, exist_ok=True)

state = {
    "order": "ROBOTICS-UA-0001",
    "component": "live_update",
    "status": "READY",
    "timestamp": datetime.now(timezone.utc).isoformat()
}

with open(os.path.join(CONTROL, "live_update.json"), "w") as f:
    json.dump(state, f, indent=2)

print(json.dumps(state, indent=2))
