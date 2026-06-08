#!/usr/bin/env python3
import json, time, os
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler

ROOT = Path.home() / "CYBRA"
LIVE = {
    "profile": "Germany/eu-frankfurt-1",
    "tz": "Europe/Berlin",
    "live_orders": False,
    "paper_trading": True,
    "testnet": True,
    "audit": True,
    "flow": "Termux→GitHub→Oracle→SpaceOracle→CodeSpace"
}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({
            "status": "LIVE_ORACLE_GERMANY",
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "live": LIVE
        }, indent=2).encode())
    def log_message(self, fmt, *args): pass

def main():
    port = int(os.environ.get("PORT", sys.argv[1] if len(sys.argv) > 1 else 8804))
    print(f"▶ LIVE Oracle Germany: http://127.0.0.1:{port}")
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()

if __name__ == "__main__":
    import sys
    main()
