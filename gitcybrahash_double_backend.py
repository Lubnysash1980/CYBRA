#!/usr/bin/env python3

# gitcybrahash_double_backend.py
# © 2026 CYBRA
#
# Hardened Version with:
# - Safe event-loop handling
# - Audio input validation
# - Additional self-tests
# - Improved JSON serialization safety
# - CYBRA Parliament V6 Redis integration
# - CYBRA_TASK_JSON task validation
# - Root-hash verification before Parliament submission
# - No TRUE_100 / SNAPSHOT_100 / LIVE declaration
# - Real root hash only, no Math.random / fake evidence

import os
import json
import time
import asyncio
import hashlib
import subprocess
from pathlib import Path
from collections import OrderedDict
from typing import Any, Dict, Tuple


# ============================================================
# CYBRA CONFIGURATION
# ============================================================

HASH_FOLDER = "hash_storage"
HASH_GROUP_SIZE = 100
OWNER_ID = "OWNER_ONLY"
BATCH_SIZE = 10
MAX_HASH_MEMORY = 202

CYBRA_ROOT = Path.home() / "CYBRA"

# Parliament V6 Redis queues
PARLIAMENT_QUEUE = "cybra:parliament:queue"
PARLIAMENT_SUBMISSIONS = "cybra:parliament:submissions"
PARLIAMENT_RESULTS = "cybra:parliament:results"
PARLIAMENT_FAILED = "cybra:parliament:failed"

# Redis
REDIS_HOST = os.environ.get("CYBRA_REDIS_HOST", "127.0.0.1")
REDIS_PORT = int(os.environ.get("CYBRA_REDIS_PORT", "6379"))

# Parliament task type registered in parliament_executor_v6.py
PARLIAMENT_TASK_TYPE = "hash_module_test_task"

# Source identity
PARLIAMENT_SOURCE = "HASH_BACKEND"
PARLIAMENT_COMPONENT = "CYBRA_HASH_BACKEND"

# Explicit integration switch.
#
# Default = OFF.
#
# It becomes active when:
#   CYBRA_PARLIAMENT_SUBMIT=1
#
# or when a valid CYBRA_TASK_JSON is supplied by Parliament.
PARLIAMENT_SUBMIT_ENABLED = (
    os.environ.get("CYBRA_PARLIAMENT_SUBMIT", "0") == "1"
)


# ============================================================
# Utilities
# ============================================================

def _safe_json_dumps(obj: Any) -> bytes:
    """
    Deterministic JSON encoding.
    """
    return json.dumps(
        obj,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def _double_sha256(data: bytes) -> str:
    """
    SHA256(SHA256(data)).
    """
    first = hashlib.sha256(data).digest()
    return hashlib.sha256(first).hexdigest()


def _sha256_text(text: str) -> str:
    return hashlib.sha256(
        text.encode("utf-8")
    ).hexdigest()


def _double_sha256_text(text: str) -> str:
    return _double_sha256(
        text.encode("utf-8")
    )


def _valid_hash(value: str) -> bool:
    """
    Validate a SHA-256 hexadecimal string.
    """
    if not isinstance(value, str):
        return False

    if len(value) != 64:
        return False

    try:
        int(value, 16)
    except ValueError:
        return False

    return True


# ============================================================
# CYBRA Parliament V6 Adapter
# ============================================================

class ParliamentV6Adapter:
    """
    Minimal Redis adapter for CYBRA Parliament V6.

    Important:
    This adapter submits evidence/task information only.

    It DOES NOT:
      - set TRUE_100
      - set SNAPSHOT_100
      - set LIVE
      - authorize LIVE
      - bypass Parliament
      - create fake evidence
    """

    def __init__(
        self,
        host: str = REDIS_HOST,
        port: int = REDIS_PORT,
    ):
        self.host = host
        self.port = port

    def _redis_cli(
        self,
        args,
        input_text: str | None = None,
    ) -> str:
        cmd = [
            "redis-cli",
            "-h",
            self.host,
            "-p",
            str(self.port),
        ] + list(args)

        try:
            result = subprocess.run(
                cmd,
                input=input_text,
                text=True,
                capture_output=True,
                check=False,
                timeout=10,
            )
        except Exception as exc:
            raise RuntimeError(
                f"redis-cli execution failed: {exc}"
            ) from exc

        if result.returncode != 0:
            raise RuntimeError(
                result.stderr.strip()
                or f"redis-cli returncode={result.returncode}"
            )

        return result.stdout.strip()

    def ping(self) -> bool:
        try:
            return self._redis_cli(["PING"]) == "PONG"
        except Exception:
            return False

    def queue_length(self, queue_name: str) -> int:
        value = self._redis_cli(
            ["LLEN", queue_name]
        )

        try:
            return int(value)
        except ValueError:
            return 0

    def queue_status(self) -> dict:
        return {
            "queue": self.queue_length(PARLIAMENT_QUEUE),
            "submissions": self.queue_length(PARLIAMENT_SUBMISSIONS),
            "results": self.queue_length(PARLIAMENT_RESULTS),
            "failed": self.queue_length(PARLIAMENT_FAILED),
        }

    def submit_hash(
        self,
        root_hash: str,
        source: str = PARLIAMENT_SOURCE,
    ) -> dict:

        if not _valid_hash(root_hash):
            raise ValueError(
                "Invalid root_hash: expected 64 hexadecimal characters"
            )

        packet = {
            "type": PARLIAMENT_TASK_TYPE,
            "source": source,
            "component": PARLIAMENT_COMPONENT,

            "root_hash": root_hash,

            "requested_action": "HASH_BACKEND_INTEGRATION",

            # This means only that the task may be processed.
            # It is NOT TRUE_100 authorization.
            "execution_allowed": True,

            # Truth gates remain closed.
            "snapshot_100": False,
            "true_100": False,
            "live": False,

            "authority": "CYBRA_PARLIAMENT",

            "timestamp": time.time(),
            "time_iso": time.strftime(
                "%Y-%m-%dT%H:%M:%S%z"
            ),
        }

        raw = json.dumps(
            packet,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )

        self._redis_cli(
            [
                "LPUSH",
                PARLIAMENT_SUBMISSIONS,
                raw,
            ]
        )

        return packet


# Global adapter.
PARLIAMENT = ParliamentV6Adapter()


# ============================================================
# CYBRA TASK CONTEXT
# ============================================================

def load_cybra_task() -> dict | None:
    """
    Read task supplied by Parliament V6.

    Parliament V6 exports:
        CYBRA_TASK_JSON=<json>

    No task means normal standalone backend mode.
    """

    raw = os.environ.get("CYBRA_TASK_JSON")

    if not raw:
        return None

    try:
        task = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"CYBRA_TASK_JSON is invalid JSON: {exc}"
        ) from exc

    if not isinstance(task, dict):
        raise RuntimeError(
            "CYBRA_TASK_JSON must contain a JSON object"
        )

    return task


def validate_cybra_task(task: dict | None) -> dict | None:
    """
    Validate Parliament task without changing truth state.
    """

    if task is None:
        return None

    task_type = task.get("type") or task.get("task_type")

    if task_type != PARLIAMENT_TASK_TYPE:
        raise RuntimeError(
            f"Unsupported Parliament task type: {task_type}"
        )

    root_hash = task.get("root_hash")

    if not _valid_hash(root_hash):
        raise RuntimeError(
            "Parliament task contains invalid root_hash"
        )

    return {
        "type": task_type,
        "root_hash": root_hash,
        "source": task.get(
            "source",
            PARLIAMENT_SOURCE,
        ),
        "authority": task.get(
            "authority",
            "CYBRA_PARLIAMENT",
        ),
    }


# ============================================================
# Root hash verification
# ============================================================

def load_stored_root_hash() -> str:
    """
    Read root_hash from:
        hash_storage/root_hash.json
    """

    path = (
        CYBRA_ROOT /
        HASH_FOLDER /
        "root_hash.json"
    )

    if not path.exists():
        raise FileNotFoundError(
            f"Root hash file not found: {path}"
        )

    with path.open(
        "r",
        encoding="utf-8",
    ) as f:
        data = json.load(f)

    root_hash = data.get("root_hash")

    if not _valid_hash(root_hash):
        raise RuntimeError(
            "Stored root_hash is invalid"
        )

    return root_hash


def verify_task_root_hash(
    task: dict | None,
    stored_root_hash: str,
) -> bool:
    """
    If Parliament supplied a root_hash,
    it MUST match the actual stored root hash.

    No match = hard failure.
    """

    if task is None:
        return True

    expected = task["root_hash"]

    if expected != stored_root_hash:
        raise RuntimeError(
            "ROOT_HASH_MISMATCH: "
            f"Parliament={expected} "
            f"stored={stored_root_hash}"
        )

    print(
        "[PARLIAMENT_V6] ROOT_HASH_MATCH=PASS"
    )

    return True


# ============================================================
# Parliament submission
# ============================================================

def submit_root_hash_to_parliament(
    root_hash: str,
    force: bool = False,
) -> dict | None:
    """
    Submit the real root hash to Parliament V6.

    Submission is deliberately explicit.

    No submission happens during normal self-tests
    unless CYBRA_PARLIAMENT_SUBMIT=1 or force=True.
    """

    enabled = (
        force
        or PARLIAMENT_SUBMIT_ENABLED
    )

    if not enabled:
        print(
            "[PARLIAMENT_V6] submission disabled"
        )
        return None

    if not _valid_hash(root_hash):
        raise RuntimeError(
            "Cannot submit invalid root_hash"
        )

    if not PARLIAMENT.ping():
        raise RuntimeError(
            "Redis/Parliament unavailable"
        )

    packet = PARLIAMENT.submit_hash(
        root_hash=root_hash,
        source=PARLIAMENT_SOURCE,
    )

    print(
        "[PARLIAMENT_V6] submitted root hash:",
        root_hash,
    )

    return packet


# ============================================================
# Double SHA-256 Workers
# ============================================================

async def double_hash_worker_async(
    info_dict: dict,
) -> Tuple[str, dict]:

    if not isinstance(info_dict, dict):
        raise TypeError(
            "info_dict must be a dictionary"
        )

    raw = _safe_json_dumps(info_dict)

    h = _double_sha256(raw)

    print(
        "[DEBUG] double_hash_worker_async "
        "computed hash:",
        h,
    )

    return h, info_dict


async def double_audio_hash_worker_async(
    audio_bytes: bytes,
    sample_rate: int = 44100,
) -> Tuple[str, dict]:

    # -------- input validation --------

    if audio_bytes is None:
        raise ValueError(
            "audio_bytes cannot be None"
        )

    if not isinstance(
        audio_bytes,
        (bytes, bytearray),
    ):
        raise TypeError(
            "audio_bytes must be bytes-like"
        )

    if len(audio_bytes) == 0:
        raise ValueError(
            "audio_bytes cannot be empty"
        )

    if (
        not isinstance(sample_rate, int)
        or not (8000 <= sample_rate <= 384000)
    ):
        raise ValueError(
            "sample_rate must be an integer "
            "between 8000 and 384000"
        )

    # --------------------------------

    h = _double_sha256(
        bytes(audio_bytes)
    )

    meta = {
        "type": "audio",
        "sample_rate": sample_rate,
        "length_bytes": len(audio_bytes),
    }

    print(
        "[DEBUG] double_audio_hash_worker_async "
        "computed audio hash:",
        h,
    )

    return h, meta


# ============================================================
# RootHash
# ============================================================

class RootHash:

    def __init__(self):
        self.menu_index: "OrderedDict[str, Dict]" = (
            OrderedDict()
        )

    def add_entry(
        self,
        level: int,
        h: str,
        meta: dict,
    ):

        if len(self.menu_index) >= MAX_HASH_MEMORY:

            oldest_key = next(
                iter(self.menu_index)
            )

            del self.menu_index[
                oldest_key
            ]

            print(
                "[DEBUG] Removed oldest hash "
                "to maintain memory limit:",
                oldest_key,
            )

        self.menu_index[h] = {
            "level": level,
            "timestamp": time.time(),
            "meta": meta,
        }

    def build_root_hash(self) -> str:

        obj = _safe_json_dumps(
            self.menu_index
        )

        root = _double_sha256(obj)

        print(
            "[DEBUG] Root hash computed:",
            root,
        )

        return root

    def export(self) -> dict:

        return {
            "menu": dict(
                self.menu_index
            ),
            "root_hash": self.build_root_hash(),
        }


# ============================================================
# Rule Engine
# ============================================================

class RuleEngine:

    def __init__(
        self,
        owner_id: str,
    ):
        self.owner_id = owner_id

    def authorize(
        self,
        requester_id: str,
    ) -> bool:

        return (
            requester_id
            == self.owner_id
        )

    def biometric_protection(
        self,
        meta: dict,
    ) -> bool:

        forbidden = {
            "fingerprint",
            "face",
            "iris",
        }

        return not any(
            k in meta
            for k in forbidden
        )

    def evolution_rule(
        self,
        stats: dict,
    ) -> dict:

        return {
            "version":
                stats.get("version", 1)
                + 1
        }


# ============================================================
# IT Department
# ============================================================

class ITDepartment:

    def __init__(self):

        self.logs = []

        self.system_health = {
            "hash_levels": 0,
            "total_hashes": 0,
            "last_check": None,
        }

    def log_event(
        self,
        message: str,
    ):

        entry = {
            "time": time.time(),
            "message": message,
        }

        self.logs.append(entry)

        print(
            "[DEBUG] IT log event:",
            message,
        )

    def audit(
        self,
        levels: dict,
    ):

        total = sum(
            len(v)
            for v in levels.values()
        )

        self.system_health.update({
            "hash_levels": len(levels),
            "total_hashes": total,
            "last_check": time.time(),
        })

        self.log_event(
            "System audit completed"
        )

    def report(self) -> dict:

        return {
            "health":
                self.system_health,

            "logs":
                self.logs[-10:],
        }


# ============================================================
# AutoMemoryCollector
# ============================================================

class AutoMemoryCollector:

    def __init__(
        self,
        owner_id: str = OWNER_ID,
    ):

        self.levels = {
            0: {}
        }

        self.root = RootHash()

        self.rules = RuleEngine(
            owner_id
        )

        self.it_department = (
            ITDepartment()
        )

        Path(
            HASH_FOLDER
        ).mkdir(
            parents=True,
            exist_ok=True,
        )

    def _collapse_level(
        self,
        level: int,
    ):

        stack = [level]

        while stack:

            lvl = stack.pop()

            items = list(
                self.levels[lvl].items()
            )

            if not items:
                continue

            raw = _safe_json_dumps(
                items
            )

            collapsed_hash = (
                _double_sha256(raw)
            )

            self.levels[lvl] = {}

            next_level = lvl + 1

            self.levels.setdefault(
                next_level,
                {},
            )

            meta = {
                "count": len(items)
            }

            self.levels[
                next_level
            ][collapsed_hash] = meta

            self.root.add_entry(
                next_level,
                collapsed_hash,
                meta,
            )

            print(
                f"[DEBUG] Collapsed level "
                f"{lvl} into hash "
                f"{collapsed_hash}"
            )

            if (
                len(
                    self.levels[
                        next_level
                    ]
                )
                >= HASH_GROUP_SIZE
            ):
                stack.append(
                    next_level
                )

    async def collect_batch(
        self,
        info_list,
        requester_id=OWNER_ID,
    ):

        if not self.rules.authorize(
            requester_id
        ):
            return None

        results = []

        for i in range(
            0,
            len(info_list),
            BATCH_SIZE,
        ):

            batch = info_list[
                i:i + BATCH_SIZE
            ]

            print(
                "[DEBUG] Starting batch",
                i // BATCH_SIZE + 1,
            )

            batch_results = (
                await asyncio.gather(
                    *[
                        double_hash_worker_async(
                            info
                        )
                        for info in batch
                    ]
                )
            )

            results.extend(
                batch_results
            )

        for h, info in results:

            self.levels[0][h] = info

            self.root.add_entry(
                0,
                h,
                {"type": "data"},
            )

            if (
                len(
                    self.levels[0]
                )
                >= HASH_GROUP_SIZE
            ):
                self._collapse_level(0)

        self.it_department.audit(
            self.levels
        )

        return (
            self.root.build_root_hash()
        )

    async def collect_audio(
        self,
        audio_bytes,
        sample_rate=44100,
        requester_id=OWNER_ID,
    ):

        if not self.rules.authorize(
            requester_id
        ):
            return None

        h, meta = (
            await double_audio_hash_worker_async(
                audio_bytes,
                sample_rate,
            )
        )

        if not self.rules.biometric_protection(
            meta
        ):
            return None

        self.levels[0][h] = {
            "audio": True
        }

        self.root.add_entry(
            0,
            h,
            meta,
        )

        if (
            len(
                self.levels[0]
            )
            >= HASH_GROUP_SIZE
        ):
            self._collapse_level(0)

        self.it_department.audit(
            self.levels
        )

        return h

    async def export_root(
        self,
        submit_to_parliament=False,
    ):
        """
        Export real root hash.

        Parliament submission is optional and explicit.
        """

        data = self.root.export()

        file_path = (
            Path(HASH_FOLDER)
            / "root_hash.json"
        )

        with open(
            file_path,
            "w",
            encoding="utf-8",
        ) as f:

            json.dump(
                data,
                f,
                indent=2,
                ensure_ascii=False,
            )

        # ----------------------------------------------------
        # Verify exported root hash before Git/Parliament
        # ----------------------------------------------------

        exported_root_hash = data.get(
            "root_hash"
        )

        if not _valid_hash(
            exported_root_hash
        ):
            raise RuntimeError(
                "Generated root_hash is invalid"
            )

        print(
            "[HASH_BACKEND] "
            "ROOT_HASH:",
            exported_root_hash,
        )

        # ----------------------------------------------------
        # Optional Parliament integration
        # ----------------------------------------------------

        task = load_cybra_task()

        validated_task = (
            validate_cybra_task(task)
        )

        verify_task_root_hash(
            validated_task,
            exported_root_hash,
        )

        if (
            submit_to_parliament
            or PARLIAMENT_SUBMIT_ENABLED
        ):
            submit_root_hash_to_parliament(
                exported_root_hash,
                force=True,
            )

        # ----------------------------------------------------
        # Existing GitHub integration
        # ----------------------------------------------------

        try:

            subprocess.run(
                [
                    "git",
                    "add",
                    str(file_path),
                ],
                check=False,
            )

            subprocess.run(
                [
                    "git",
                    "commit",
                    "-m",
                    "Update root_hash",
                ],
                check=False,
            )

            subprocess.run(
                [
                    "git",
                    "push",
                ],
                check=False,
            )

        except Exception as e:

            print(
                "GitHub integration error:",
                e,
            )

        print(
            "[DEBUG] Root hash exported"
        )

        return data

    def it_report(self):

        return (
            self.it_department.report()
        )


# ============================================================
# Menu
# ============================================================

class MenuBarFromRoot:

    def __init__(
        self,
        root_data,
    ):

        self.menu = root_data[
            "menu"
        ]

    def show(self):

        print(
            "\n=== ROOT HASH MENU ==="
        )

        for i, (h, v) in enumerate(
            self.menu.items(),
            start=1,
        ):

            t = (
                v.get(
                    "meta",
                    {},
                ).get(
                    "type",
                    "data",
                )
            )

            print(
                f"{i}. HASH {h[:12]} "
                f"| level={v['level']} "
                f"| type={t}"
            )

        print(
            "[DEBUG] Menu displayed with",
            len(self.menu),
            "entries",
        )


# ============================================================
# Safe Async Runner
# ============================================================

def run_async_safely(coro):

    try:

        loop = (
            asyncio.get_running_loop()
        )

    except RuntimeError:

        return asyncio.run(coro)

    else:

        return loop.create_task(
            coro
        )


# ============================================================
# Self Tests
# ============================================================

async def _self_test():

    collector = (
        AutoMemoryCollector()
    )

    # --------------------------------------------------------
    # Test 1: Batch hashing
    # --------------------------------------------------------

    batch = [
        {"frame": i}
        for i in range(5)
    ]

    root_hash = (
        await collector.collect_batch(
            batch
        )
    )

    assert isinstance(
        root_hash,
        str,
    )

    assert _valid_hash(
        root_hash
    )

    # --------------------------------------------------------
    # Test 2: Valid audio
    # --------------------------------------------------------

    audio_hash = (
        await collector.collect_audio(
            b"TEST_AUDIO",
            44100,
        )
    )

    assert isinstance(
        audio_hash,
        str,
    )

    assert _valid_hash(
        audio_hash
    )

    # --------------------------------------------------------
    # Test 3: Invalid audio
    # --------------------------------------------------------

    try:

        await collector.collect_audio(
            b"",
            44100,
        )

    except ValueError:

        pass

    else:

        raise AssertionError(
            "Empty audio should raise ValueError"
        )

    # --------------------------------------------------------
    # Test 4: Deterministic JSON
    # --------------------------------------------------------

    a = _safe_json_dumps(
        {"b": 2, "a": 1}
    )

    b = _safe_json_dumps(
        {"a": 1, "b": 2}
    )

    assert a == b

    # --------------------------------------------------------
    # Test 5: Double SHA
    # --------------------------------------------------------

    test_hash = _double_sha256(
        b"CYBRA"
    )

    assert _valid_hash(
        test_hash
    )

    # --------------------------------------------------------
    # Test 6: Stored root hash
    # --------------------------------------------------------

    root_path = (
        CYBRA_ROOT
        / HASH_FOLDER
        / "root_hash.json"
    )

    if root_path.exists():

        stored_root = (
            load_stored_root_hash()
        )

        assert _valid_hash(
            stored_root
        )

        print(
            "[DEBUG] Stored root hash:",
            stored_root,
        )

    # --------------------------------------------------------
    # Test 7: Redis / Parliament connectivity
    # --------------------------------------------------------

    redis_ok = (
        PARLIAMENT.ping()
    )

    print(
        "[DEBUG] Parliament Redis:",
        "ONLINE"
        if redis_ok
        else "OFFLINE",
    )

    # --------------------------------------------------------
    # IMPORTANT:
    # Self-test NEVER submits automatically.
    # --------------------------------------------------------

    print(
        "[DEBUG] Parliament submission:",
        "ENABLED"
        if PARLIAMENT_SUBMIT_ENABLED
        else "DISABLED",
    )

    print(
        "[DEBUG] TRUE_100 declaration:",
        "NOT_PERFORMED",
    )

    print(
        "[DEBUG] SNAPSHOT_100 declaration:",
        "NOT_PERFORMED",
    )

    print(
        "[DEBUG] LIVE declaration:",
        "NOT_PERFORMED",
    )

    print(
        "[DEBUG] Self-tests passed"
    )


# ============================================================
# Parliament Task Execution
# ============================================================

async def run_parliament_task():

    task = load_cybra_task()

    if task is None:

        raise RuntimeError(
            "CYBRA_TASK_JSON not provided"
        )

    validated_task = (
        validate_cybra_task(task)
    )

    expected_root = (
        validated_task["root_hash"]
    )

    stored_root = (
        load_stored_root_hash()
    )

    print(
        "[PARLIAMENT_V6] "
        "Expected root_hash:",
        expected_root,
    )

    print(
        "[PARLIAMENT_V6] "
        "Stored root_hash:",
        stored_root,
    )

    # --------------------------------------------------------
    # HARD GATE
    # --------------------------------------------------------

    verify_task_root_hash(
        validated_task,
        stored_root,
    )

    print(
        "[PARLIAMENT_V6] "
        "ROOT_HASH_VERIFICATION=PASS"
    )

    # --------------------------------------------------------
    # No TRUE_100 here.
    # No snapshot here.
    # No LIVE here.
    # --------------------------------------------------------

    result = {
        "ok": True,

        "type":
            PARLIAMENT_TASK_TYPE,

        "component":
            PARLIAMENT_COMPONENT,

        "root_hash":
            stored_root,

        "root_hash_verified":
            True,

        "authority":
            "CYBRA_PARLIAMENT",

        "true_100":
            False,

        "snapshot_100":
            False,

        "live":
            False,

        "execution":
            "HASH_BACKEND_VERIFICATION_ONLY",

        "timestamp":
            time.time(),
    }

    print(
        json.dumps(
            result,
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
    )

    return result


# ============================================================
# Main Execution
# ============================================================


# ============================================================
# CYBRA HASH AUTOMATION WORKER
# ============================================================
#
# This block intentionally lives at the bottom of this file.
#
# It:
#   HASH -> VERIFY -> PARLIAMENT V6 -> WAIT
#
# It does NOT:
#   TRUE_100
#   SNAPSHOT_100
#   LIVE
#   create another Parliament executor
#   generate endless self-tasks
#
# ============================================================

HASH_AUTO_WORKER_INTERVAL = int(
    os.environ.get("CYBRA_HASH_AUTO_INTERVAL", "30")
)

HASH_AUTO_WORKER_STOP = os.environ.get(
    "CYBRA_HASH_AUTO_STOP",
    "0",
) == "1"


def hash_automation_worker_once():
    """
    One real verification cycle.

    Existing root_hash.json is read.
    No artificial hash is generated.
    No task is generated from the result.
    """

    root_file = (
        CYBRA_ROOT
        / HASH_FOLDER
        / "root_hash.json"
    )

    if not root_file.exists():
        print(
            "[HASH_AUTO] ROOT_HASH_FILE=NOT_FOUND"
        )
        return False

    try:
        root_hash = load_stored_root_hash()
    except Exception as exc:
        print(
            "[HASH_AUTO] ROOT_HASH_READ=FAILED:",
            exc,
        )
        return False

    print(
        "[HASH_AUTO] ROOT_HASH:",
        root_hash,
    )

    # --------------------------------------------------------
    # Redis / Parliament availability
    # --------------------------------------------------------

    if not PARLIAMENT.ping():
        print(
            "[HASH_AUTO] PARLIAMENT=OFFLINE"
        )
        return False

    print(
        "[HASH_AUTO] PARLIAMENT=ONLINE"
    )

    # --------------------------------------------------------
    # Existing Parliament task, if supplied.
    # Do not create a new task automatically.
    # --------------------------------------------------------

    task_raw = os.environ.get(
        "CYBRA_TASK_JSON"
    )

    if task_raw:

        try:
            task = validate_cybra_task(
                load_cybra_task()
            )

            verify_task_root_hash(
                task,
                root_hash,
            )

            print(
                "[HASH_AUTO] TASK_ROOT_VERIFY=PASS"
            )

        except Exception as exc:

            print(
                "[HASH_AUTO] TASK_VERIFY=FAILED:",
                exc,
            )

            return False

    # --------------------------------------------------------
    # Parliament V6 submission.
    #
    # The worker submits the REAL existing root_hash through
    # the already existing submit_root_hash_to_parliament()
    # path. This does NOT declare TRUE_100, SNAPSHOT_100 or LIVE.
    # --------------------------------------------------------

    try:
        packet = submit_root_hash_to_parliament(
            root_hash=root_hash,
            force=True,
        )

        if packet is None:
            print(
                "[HASH_AUTO] PARLIAMENT_SUBMISSION=NOT_SUBMITTED"
            )
            return False

        print(
            "[HASH_AUTO] PARLIAMENT_SUBMISSION=PASS"
        )

    except Exception as exc:
        print(
            "[HASH_AUTO] PARLIAMENT_SUBMISSION=FAILED:",
            exc,
        )
        return False

    # --------------------------------------------------------
    # State gates.
    # Worker never opens these gates.
    # --------------------------------------------------------

    print(
        "[HASH_AUTO] TRUE_100=NOT_DECLARED"
    )

    print(
        "[HASH_AUTO] SNAPSHOT_100=NOT_DECLARED"
    )

    print(
        "[HASH_AUTO] LIVE=NOT_DECLARED"
    )

    print(
        "[HASH_AUTO] CYCLE=PASS"
    )

    return True


def hash_automation_worker():
    """
    Living worker.

    It remains inside this same Python file.
    It performs verification cycles only.
    """

    print(
        "============================================================"
    )

    print(
        " CYBRA HASH AUTOMATION WORKER ACTIVE"
    )

    print(
        "============================================================"
    )

    print(
        "[HASH_AUTO] interval:",
        HASH_AUTO_WORKER_INTERVAL,
        "seconds",
    )

    print(
        "[HASH_AUTO] source:",
        PARLIAMENT_COMPONENT,
    )

    print(
        "[HASH_AUTO] authority:",
        "CYBRA_PARLIAMENT",
    )

    while True:

        if HASH_AUTO_WORKER_STOP:
            print(
                "[HASH_AUTO] STOP=1"
            )
            break

        try:
            hash_automation_worker_once()

        except KeyboardInterrupt:
            print(
                "[HASH_AUTO] STOPPED"
            )
            break

        except Exception as exc:
            print(
                "[HASH_AUTO] ERROR:",
                repr(exc),
            )

        time.sleep(
            HASH_AUTO_WORKER_INTERVAL
        )


# ============================================================
# Final dispatcher
# ============================================================

if __name__ == "__main__":

    mode = os.environ.get(
        "CYBRA_HASH_MODE",
        "selftest",
    ).lower()

    if mode == "worker":

        hash_automation_worker()

    elif os.environ.get(
        "CYBRA_TASK_JSON"
    ):

        print(
            "============================================================"
        )

        print(
            " CYBRA HASH BACKEND — PARLIAMENT V6 TASK MODE"
        )

        print(
            "============================================================"
        )

        run_async_safely(
            run_parliament_task()
        )

    else:

        print(
            "============================================================"
        )

        print(
            " CYBRA HASH BACKEND — SELF TEST"
        )

        print(
            "============================================================"
        )

        run_async_safely(
            _self_test()
        )
