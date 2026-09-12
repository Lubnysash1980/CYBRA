#!/usr/bin/env python3
# ============================================================
# CYBRA — SINGLE SNAPSHOT STATE
# ============================================================
# Окрема snapshot-логіка.
# Основний gitcybrahash_double_backend.py не змінюється.
#
# Формула:
#   snapshot_hash = SHA256(SHA256(canonical_state))
#
# snapshot_hash не входить у власний payload.
# ============================================================

import argparse
import hashlib
import json
import time
from pathlib import Path
from typing import Any


CYBRA_ROOT = Path.home() / "CYBRA"

HASH_FILE = (
    CYBRA_ROOT /
    "hash_storage" /
    "root_hash.json"
)

SNAPSHOT_DIR = (
    CYBRA_ROOT /
    "snapshots"
)

SNAPSHOT_FILE = (
    SNAPSHOT_DIR /
    "cybra_snapshot.json"
)


def safe_json(obj: Any) -> bytes:
    return json.dumps(
        obj,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def double_sha256(data: bytes) -> str:
    first = hashlib.sha256(
        data
    ).digest()

    return hashlib.sha256(
        first
    ).hexdigest()


def valid_hash(value: Any) -> bool:
    if not isinstance(value, str):
        return False

    if len(value) != 64:
        return False

    try:
        int(value, 16)
    except ValueError:
        return False

    return True


def load_root_hash() -> str:
    if not HASH_FILE.is_file():
        raise FileNotFoundError(
            f"root_hash.json not found: {HASH_FILE}"
        )

    with open(
        HASH_FILE,
        "r",
        encoding="utf-8",
    ) as f:
        data = json.load(f)

    root_hash = data.get(
        "root_hash"
    )

    if not valid_hash(root_hash):
        raise RuntimeError(
            "root_hash.json contains invalid root_hash"
        )

    return root_hash


def build_snapshot() -> dict:
    root_hash = load_root_hash()

    state = {
        "version": 1,
        "timestamp": time.time(),
        "root_hash": root_hash,
    }

    state["snapshot_hash"] = double_sha256(
        safe_json(state)
    )

    return state


def save_snapshot() -> dict:
    SNAPSHOT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    state = build_snapshot()

    temporary = SNAPSHOT_FILE.with_suffix(
        ".tmp"
    )

    with open(
        temporary,
        "w",
        encoding="utf-8",
    ) as f:
        json.dump(
            state,
            f,
            indent=2,
            ensure_ascii=False,
        )
        f.flush()

    temporary.replace(
        SNAPSHOT_FILE
    )

    print(
        "[CYBRA SNAPSHOT] ROOT_HASH:",
        state["root_hash"],
    )

    print(
        "[CYBRA SNAPSHOT] TIMESTAMP:",
        state["timestamp"],
    )

    print(
        "[CYBRA SNAPSHOT] SNAPSHOT_HASH:",
        state["snapshot_hash"],
    )

    print(
        "[CYBRA SNAPSHOT] FILE:",
        SNAPSHOT_FILE,
    )

    return state


def verify_snapshot() -> dict:
    if not SNAPSHOT_FILE.is_file():
        raise FileNotFoundError(
            f"Snapshot not found: {SNAPSHOT_FILE}"
        )

    with open(
        SNAPSHOT_FILE,
        "r",
        encoding="utf-8",
    ) as f:
        state = json.load(f)

    stored_hash = state.get(
        "snapshot_hash"
    )

    if not valid_hash(stored_hash):
        raise RuntimeError(
            "Snapshot contains invalid snapshot_hash"
        )

    payload = dict(state)

    del payload[
        "snapshot_hash"
    ]

    calculated_hash = double_sha256(
        safe_json(payload)
    )

    if stored_hash != calculated_hash:
        raise RuntimeError(
            "SNAPSHOT HASH VERIFICATION FAILED"
        )

    root_hash = state.get(
        "root_hash"
    )

    if not valid_hash(root_hash):
        raise RuntimeError(
            "Snapshot contains invalid root_hash"
        )

    print(
        "[CYBRA SNAPSHOT] VERIFY=PASS"
    )

    print(
        "[CYBRA SNAPSHOT] ROOT_HASH:",
        root_hash,
    )

    print(
        "[CYBRA SNAPSHOT] SNAPSHOT_HASH:",
        stored_hash,
    )

    return state


def status() -> None:
    if not SNAPSHOT_FILE.is_file():
        print(
            "[CYBRA SNAPSHOT] STATUS=NO_SNAPSHOT"
        )
        return

    state = verify_snapshot()

    print(
        "[CYBRA SNAPSHOT] STATUS=VALID"
    )

    print(
        "[CYBRA SNAPSHOT] TIMESTAMP:",
        state["timestamp"],
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="CYBRA single snapshot state"
    )

    parser.add_argument(
        "command",
        choices=[
            "save",
            "verify",
            "status",
        ],
    )

    args = parser.parse_args()

    if args.command == "save":
        save_snapshot()

    elif args.command == "verify":
        verify_snapshot()

    elif args.command == "status":
        status()


if __name__ == "__main__":
    main()
