import time, subprocess, sys
from pathlib import Path
D = Path(__file__).resolve().parent
while True:
    subprocess.run(["python3", str(D/"structure.py"), "verify"],
                  capture_output=True, timeout=60)
    time.sleep(1800)
