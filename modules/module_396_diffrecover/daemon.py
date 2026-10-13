import time, subprocess
from pathlib import Path
D = Path(__file__).resolve().parent
while True:
    subprocess.run(["python3", str(D/"recover.py"), "fix"],
                  capture_output=True, timeout=120)
    time.sleep(1800)
