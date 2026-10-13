"""Перевірка структури та дозволів."""
import os, stat, json
from pathlib import Path

H = Path.home() / "CYBRA"

REQUIRED = [
    ("modules/module_108_metamask_sign/main.sh", 0o755, "critical"),
    ("modules/module_109_metamask_verify/main.sh", 0o755, "warn"),
    ("modules/module_114_autonode/main.sh", 0o755, "warn"),
    ("modules/module_114_autonode/daemon.py", 0o755, "warn"),
    ("modules/module_119_qr_sign/main.sh", 0o755, "warn"),
    ("modules/module_119_qr_sign/cli.py", 0o755, "warn"),
    ("modules/module_19_contract_tui_menu/bin/cybra_menu.sh", 0o755, "critical"),
    ("public/sign", None, "warn"),
    ("modules/module_19_contract_tui_menu/evidence", None, "warn"),
    ("config/metamask.env", None, "warn"),
]

def run():
    out = []
    for rel, want_mode, lvl in REQUIRED:
        p = H / rel
        if not p.exists():
            out.append({"id":f"file.{rel}","name":f"Файл {rel}",
                        "status":"fail" if lvl=="critical" else "warn",
                        "detail":"не існує","fix_hint":""})
            continue
        if want_mode is not None:
            m = stat.S_IMODE(p.stat().st_mode)
            if m != want_mode:
                out.append({"id":f"file.{rel}","name":f"Права {rel}",
                            "status":"warn","detail":f"0o{m:o} (треба 0o{want_mode:o})",
                            "fix_hint":f"chmod {want_mode:o} {p}"})
                continue
        out.append({"id":f"file.{rel}","name":f"Файл {rel}",
                    "status":"ok","detail":"є","fix_hint":""})

    # Ключі
    keys_dir = H / "modules/module_119_qr_sign/keys"
    if keys_dir.exists():
        for k in ["hmac.key","ed25519.priv"]:
            f = keys_dir / k
            if f.exists():
                m = stat.S_IMODE(f.stat().st_mode)
                if m & 0o077:
                    out.append({"id":f"key.{k}","name":f"Ключ {k}",
                                "status":"critical","detail":f"права 0o{m:o} — доступний іншим!",
                                "fix_hint":f"chmod 600 {f}"})
                else:
                    out.append({"id":f"key.{k}","name":f"Ключ {k}",
                                "status":"ok","detail":"права 600","fix_hint":""})
    return out
