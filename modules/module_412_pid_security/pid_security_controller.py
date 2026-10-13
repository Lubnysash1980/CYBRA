#!/usr/bin/env python3
import os
import sys
import json
import time
import hashlib
import subprocess
import fcntl
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.home() / "CYBRA"
RUN = ROOT / "run"
DATA = ROOT / "out" / "pid_security"

PID_FILE = RUN / "pid_security_controller.pid"
LOCK_FILE = RUN / "pid_security_controller.lock"
BASELINE_FILE = DATA / "identity_baseline.json"
LATEST_FILE = DATA / "latest.json"
LOG_FILE = DATA / "controller.log"

INTERVAL = 15


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def double_sha256(data):
    first = hashlib.sha256(data).hexdigest().encode()
    return hashlib.sha256(first).hexdigest()


def atomic_write(path, content):
    path = Path(path)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(content)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def log(message):
    with LOG_FILE.open("a") as f:
        f.write(f"{utc_now()} {message}\n")


def process_identity(pid):
    proc = Path("/proc") / str(pid)

    try:
        raw_cmd = (proc / "cmdline").read_bytes()
        cmd = raw_cmd.replace(b"\0", b" ").decode(
            errors="replace"
        ).strip()

        stat = (proc / "stat").read_text()
        fields = stat[stat.rfind(")") + 2:].split()

        # Linux process start time, field 22 in /proc/PID/stat.
        start_ticks = fields[19]

        if not cmd:
            return None

        return {
            "pid": pid,
            "start_ticks": start_ticks,
            "cmdline": cmd,
            "cmdline_sha256": sha256(cmd.encode()),
        }
    except (OSError, IndexError, ValueError):
        return None


def load_baseline():
    try:
        return json.loads(BASELINE_FILE.read_text())
    except (OSError, ValueError):
        return {}


def save_report(report):
    payload = json.dumps(
        report, sort_keys=True, ensure_ascii=False, indent=2
    )
    raw = payload.encode()

    atomic_write(LATEST_FILE, payload + "\n")
    atomic_write(
        Path(str(LATEST_FILE) + ".sha256"),
        sha256(raw) + "\n",
    )
    atomic_write(
        Path(str(LATEST_FILE) + ".double_sha256"),
        double_sha256(raw) + "\n",
    )


def scan_once():
    DATA.mkdir(parents=True, exist_ok=True)
    RUN.mkdir(parents=True, exist_ok=True)

    baseline = load_baseline()
    entries = []
    baseline_changed = False

    pid_files = sorted(RUN.rglob("*.pid"))

    for file in pid_files:
        relative = str(file.relative_to(ROOT))

        try:
            raw_pid = file.read_text().strip()
            pid = int(raw_pid)

            if pid <= 1:
                raise ValueError("PID must be greater than 1")
        except (OSError, ValueError):
            entries.append({
                "pid_file": relative,
                "status": "FALSE_INVALID_PID",
            })
            continue

        current = process_identity(pid)

        if current is None:
            entries.append({
                "pid_file": relative,
                "pid": pid,
                "status": "FALSE_STALE_OR_UNREADABLE",
            })
            continue

        # A live process is not automatically a verified CYBRA process.
        if str(ROOT) not in current["cmdline"]:
            entries.append({
                "pid_file": relative,
                "pid": pid,
                "status": "FALSE_IDENTITY_UNCONFIRMED",
                "cmdline": current["cmdline"],
            })
            continue

        previous = baseline.get(relative)

        if previous is None:
            baseline[relative] = current
            baseline_changed = True
            status = "PENDING_FIRST_OBSERVATION"

        elif (
            previous.get("pid") == current["pid"]
            and previous.get("start_ticks") == current["start_ticks"]
            and previous.get("cmdline_sha256")
                == current["cmdline_sha256"]
        ):
            status = "VERIFIED_STABLE_IDENTITY"

        else:
            # Do not silently replace the trusted baseline.
            status = "FALSE_IDENTITY_CHANGED_REVIEW_REQUIRED"

        entries.append({
            "pid_file": relative,
            "pid": pid,
            "status": status,
            "start_ticks": current["start_ticks"],
            "cmdline_sha256": current["cmdline_sha256"],
        })

    if baseline_changed:
        atomic_write(
            BASELINE_FILE,
            json.dumps(
                baseline, sort_keys=True, ensure_ascii=False, indent=2
            ) + "\n",
        )

    counts = {}
    for entry in entries:
        status = entry["status"]
        counts[status] = counts.get(status, 0) + 1

    report = {
        "controller": "CYBRA_PID_SECURITY_CONTROLLER",
        "version": 1,
        "timestamp_utc": utc_now(),
        "mode": "OBSERVE_VERIFY_NO_KILL",
        "pid_files_found": len(pid_files),
        "results": counts,
        "entries": entries,
        "sha256": "computed_for_report",
        "double_sha256": "computed_for_report",
        "true_100": False,
        "note": (
            "Initial observations are not proof of historical ownership. "
            "Changed identities require review. No process was terminated."
        ),
    }

    save_report(report)
    log("SCAN " + json.dumps(counts, sort_keys=True))
    return report


def controller_alive(pid):
    identity = process_identity(pid)
    return bool(
        identity
        and str(Path(__file__).resolve()) in identity["cmdline"]
    )


def start():
    if PID_FILE.exists():
        try:
            old_pid = int(PID_FILE.read_text().strip())
            if old_pid > 1 and controller_alive(old_pid):
                print("CONTROLLER_ALREADY_RUNNING")
                print("PID:", old_pid)
                return 0
        except (ValueError, OSError):
            pass

    with LOG_FILE.open("a") as log_file:
        child = subprocess.Popen(
            [sys.executable, str(Path(__file__).resolve()), "daemon"],
            stdin=subprocess.DEVNULL,
            stdout=log_file,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            close_fds=True,
        )

    time.sleep(1)

    if controller_alive(child.pid):
        print("CONTROLLER_START: PROCESS_VISIBLE")
        print("PID:", child.pid)
        print("MODE: OBSERVE_VERIFY_NO_KILL")
        return 0

    print("CONTROLLER_START: FALSE/RETRY")
    print("Inspect:", LOG_FILE)
    return 1


def daemon():
    RUN.mkdir(parents=True, exist_ok=True)
    DATA.mkdir(parents=True, exist_ok=True)

    lock = LOCK_FILE.open("a+")
    try:
        fcntl.flock(
            lock.fileno(),
            fcntl.LOCK_EX | fcntl.LOCK_NB
        )
    except BlockingIOError:
        print("LOCK_BUSY")
        return 73

    atomic_write(PID_FILE, str(os.getpid()) + "\n")
    log("CONTROLLER_STARTED pid=" + str(os.getpid()))

    try:
        while True:
            try:
                report = scan_once()
                log(
                    "SCAN_COMPLETE pid_files="
                    + str(report["pid_files_found"])
                )
            except Exception as exc:
                log("FALSE_RETRY " + repr(exc))
            time.sleep(INTERVAL)
    finally:
        try:
            if PID_FILE.read_text().strip() == str(os.getpid()):
                PID_FILE.unlink()
        except OSError:
            pass
        log("CONTROLLER_EXIT")
        lock.close()

    return 0


def status():
    print("=== CYBRA PID SECURITY CONTROLLER ===")

    try:
        pid = int(PID_FILE.read_text().strip())
        print("PID:", pid)
        print("PROCESS:", "RUNNING" if controller_alive(pid) else "NOT_VERIFIED")
    except (OSError, ValueError):
        print("PROCESS: NOT_VERIFIED")

    try:
        report = json.loads(LATEST_FILE.read_text())
        print("LAST_SCAN:", report.get("timestamp_utc"))
        print("PID_FILES:", report.get("pid_files_found"))
        print("RESULTS:", json.dumps(report.get("results", {})))
        print("TRUE_100:", report.get("true_100"))
    except (OSError, ValueError):
        print("LAST_SCAN: PENDING")

    for suffix in (".sha256", ".double_sha256"):
        path = Path(str(LATEST_FILE) + suffix)
        print(suffix[1:].upper() + ":", path.exists())

    return 0


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "status"

    if command == "start":
        sys.exit(start())
    elif command == "daemon":
        sys.exit(daemon())
    elif command == "once":
        report = scan_once()
        print(json.dumps(report["results"], indent=2))
    elif command == "status":
        sys.exit(status())
    else:
        print("Usage: pid_security_controller.py start|status|once")
        sys.exit(2)
