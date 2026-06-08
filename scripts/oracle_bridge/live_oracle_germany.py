#!/usr/bin/env python3
# LIVE CYBRA ORACLE GERMANY PATCH — PAPER/TESTNET ONLY
import os, sys, json, time, subprocess, tarfile
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler

ROOT = Path.home() / "CYBRA"
REGION = {
    "country": "Germany",
    "region": "eu-frankfurt-1",
    "tz": "Europe/Berlin",
    "profile": "DE_EU_SAFE"
}
SAFETY = {
    "live_orders": False,
    "real_trading": False,
    "paper_trading": True,
    "testnet": True,
    "auto_withdrawals": False,
    "owner_approval": True
}

def now(): return time.strftime("%Y-%m-%dT%H:%M:%S")

def live_status():
    return {
        "timestamp": now(),
        "status": "LIVE_ORACLE_GERMANY_ACTIVE",
        "region": REGION,
        "safety": SAFETY,
        "flow": "Termux→GitHub→Oracle(fra)→SpaceOracle→CodeSpace"
    }

def serve(port):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(live_status(), indent=2).encode())
        def log_message(self, fmt, *args): pass
    print(f"▶ LIVE Oracle Germany dashboard: http://127.0.0.1:{port}")
    HTTPServer(("127.0.0.1", int(port)), Handler).serve_forever()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        print(json.dumps(live_status(), indent=2))
    elif cmd == "serve":
        serve(sys.argv[2] if len(sys.argv) > 2 else 8804)
    else:
        print("live: status | serve [port]")
