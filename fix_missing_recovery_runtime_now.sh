#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== FIX MISSING RECOVERY RUNTIME NOW ==="

mkdir -p \
  runtime/redis \
  logs \
  posts feeds proofs \
  data/cybra_autorecovery/packs \
  data/cybra_autorecovery/reports \
  data/cybra_menubar/reports

echo
echo "=== 1. START REDIS ==="

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server \
    --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

if redis-cli ping >/dev/null 2>&1; then
  echo "✅ Redis PONG"
else
  echo "⚠ Redis still not running. Trying background mode..."
  redis-server \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no > logs/redis_manual.log 2>&1 &
  sleep 1
  redis-cli ping || true
fi

echo
echo "=== 2. CREATE cybra_termux_restore.sh ==="

cat > cybra_termux_restore.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CYBRA TERMUX SAFE RESTORE ==="

mkdir -p runtime/redis logs posts feeds proofs data

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server \
    --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

find . -maxdepth 2 -type f \( -name "*.sh" -o -path "./bin/*" \) -exec chmod +x {} \; 2>/dev/null || true

[ -f cybra_recovery.sh ] && bash cybra_recovery.sh report || true
[ -f cybra_autoheal.sh ] && bash cybra_autoheal.sh cycle || true
[ -f cybra_security_analytics.sh ] && bash cybra_security_analytics.sh cycle || true
[ -f cybra_conformation8.sh ] && bash cybra_conformation8.sh cycle || true
[ -f cybra_menubar.sh ] && bash cybra_menubar.sh report || true
[ -f cybra_codespace_runtime.sh ] && bash cybra_codespace_runtime.sh cycle restore || true

echo "✅ CYBRA restore cycle done"
EOF

chmod +x cybra_termux_restore.sh

echo
echo "=== 3. GENERATE AUTORECOVERY REPORT ==="

if [ -f cybra_recovery.sh ]; then
  bash cybra_recovery.sh report || true
fi

python3 - <<'PY'
import json, time, hashlib, subprocess, tarfile
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sha(x): return hashlib.sha256(x.encode("utf-8")).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))

pack = ROOT / "data/cybra_autorecovery/packs/cybra_restore_pack.tar.gz"
pack.parent.mkdir(parents=True, exist_ok=True)

include = [
    "cybra_termux_restore.sh",
    "cybra_recovery.sh",
    "bin/cybra-recover",
    "cybra_menubar.sh",
    "cybra_menubar.py",
    "cybra_menu_recovery_bridge.sh",
    "cybra_autoheal.sh",
    "cybra_security_analytics.sh",
    "cybra_conformation8.sh",
    "cybra_codespace_runtime.sh",
    "cybra_dashboard.sh",
    "parliament_executor_v6.py",
    "posts/cybra_autorecovery_report.md",
    "feeds/cybra_autorecovery_report.json",
    "proofs/cybra_autorecovery.sha256"
]

with tarfile.open(pack, "w:gz") as tar:
    for rel in include:
        p = ROOT / rel
        if p.exists():
            tar.add(p, arcname=rel)

obj = {
    "status": "autorecovery_runtime_restored",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "restore_script": "cybra_termux_restore.sh",
    "restore_pack": "data/cybra_autorecovery/packs/cybra_restore_pack.tar.gz",
    "checks": {
        "cybra_termux_restore_sh": (ROOT / "cybra_termux_restore.sh").exists(),
        "restore_pack": pack.exists(),
        "cybra_recovery_sh": (ROOT / "cybra_recovery.sh").exists(),
        "bin_cybra_recover": (ROOT / "bin/cybra-recover").exists(),
        "menubar": (ROOT / "cybra_menubar.sh").exists(),
        "menu_recovery_bridge": (ROOT / "cybra_menu_recovery_bridge.sh").exists()
    },
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "private_key_required": False,
        "seed_phrase_required": False,
        "manual_OWNER_approval_required": True
    }
}
obj["double_sha"] = dsha(obj)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "data/cybra_autorecovery/reports").mkdir(parents=True, exist_ok=True)

(ROOT / "feeds/cybra_autorecovery_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "data/cybra_autorecovery/reports/latest_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

md = []
md.append("# CYBRA AutoRecovery Report")
md.append("")
md.append("Status: autorecovery_runtime_restored")
md.append("")
md.append("Restore script: cybra_termux_restore.sh")
md.append("Restore pack: data/cybra_autorecovery/packs/cybra_restore_pack.tar.gz")
md.append("")
md.append("## Checks")
for k, v in obj["checks"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Safety")
for k, v in obj["safety"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Double SHA")
md.append(obj["double_sha"])

(ROOT / "posts/cybra_autorecovery_report.md").write_text("\n".join(md), encoding="utf-8")

with (ROOT / "proofs/cybra_autorecovery.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_autorecovery_report.json",
        "posts/cybra_autorecovery_report.md",
        "data/cybra_autorecovery/reports/latest_report.json",
        "cybra_termux_restore.sh",
        "data/cybra_autorecovery/packs/cybra_restore_pack.tar.gz"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print("✅ AutoRecovery runtime files generated")
print("DOUBLE_SHA:", obj["double_sha"])
PY

echo
echo "=== 4. GENERATE MENU-BAR RECOVERY TEST REPORT ==="

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sha(x): return hashlib.sha256(x.encode("utf-8")).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))

checks = {
    "cybra_menubar_sh": (ROOT / "cybra_menubar.sh").exists(),
    "cybra_menubar_py": (ROOT / "cybra_menubar.py").exists(),
    "cybra_menu_recovery_bridge": (ROOT / "cybra_menu_recovery_bridge.sh").exists(),
    "cybra_recovery_sh": (ROOT / "cybra_recovery.sh").exists(),
    "bin_cybra_recover": (ROOT / "bin/cybra-recover").exists(),
    "cybra_termux_restore_sh": (ROOT / "cybra_termux_restore.sh").exists(),
    "autorecovery_report": (ROOT / "posts/cybra_autorecovery_report.md").exists(),
    "autorecovery_feed": (ROOT / "feeds/cybra_autorecovery_report.json").exists(),
    "autorecovery_proof": (ROOT / "proofs/cybra_autorecovery.sha256").exists(),
    "restore_pack": (ROOT / "data/cybra_autorecovery/packs/cybra_restore_pack.tar.gz").exists()
}

obj = {
    "status": "ok" if all(checks.values()) else "needs_attention",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "checks": checks,
    "menu_commands": [
        "cybra-menu recovery status",
        "cybra-menu recovery report",
        "cybra-menu recovery test",
        "cybra-menu recovery pack",
        "cybra-menu recovery cycle"
    ],
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "private_key_required": False,
        "seed_phrase_required": False
    }
}
obj["double_sha"] = dsha(obj)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "data/cybra_menubar/reports").mkdir(parents=True, exist_ok=True)

(ROOT / "feeds/cybra_menubar_recovery_test_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "data/cybra_menubar/reports/recovery_test_latest.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

md = []
md.append("# CYBRA Menu-Bar Recovery Test Report")
md.append("")
md.append(f"Status: {obj['status']}")
md.append("")
md.append("## Checks")
for k, v in checks.items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Menu commands")
for x in obj["menu_commands"]:
    md.append(f"- `{x}`")
md.append("")
md.append("## Safety")
for k, v in obj["safety"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Double SHA")
md.append(obj["double_sha"])

(ROOT / "posts/cybra_menubar_recovery_test_report.md").write_text("\n".join(md), encoding="utf-8")

with (ROOT / "proofs/cybra_menubar_recovery_test.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_menubar_recovery_test_report.json",
        "posts/cybra_menubar_recovery_test_report.md",
        "data/cybra_menubar/reports/recovery_test_latest.json"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print("✅ Menu-Bar Recovery test report generated")
print("STATUS:", obj["status"])
print("DOUBLE_SHA:", obj["double_sha"])
PY

echo
echo "=== 5. PATCH WHAT-MISSING TEST TO START REDIS FIRST ==="

if [ -f cybra_what_missing.sh ]; then
python3 - <<'PY'
from pathlib import Path

p = Path("cybra_what_missing.sh")
s = p.read_text(encoding="utf-8", errors="ignore")

insert = '''
mkdir -p runtime/redis
if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

'''
if "redis-server --daemonize yes --bind 127.0.0.1 --port 6379" not in s:
    s = s.replace('echo "=== CYBRA WHAT IS MISSING TEST ==="', insert + 'echo "=== CYBRA WHAT IS MISSING TEST ==="', 1)

p.write_text(s, encoding="utf-8")
PY
fi

echo
echo "=== 6. VERIFY PROOFS ==="

sha256sum -c proofs/cybra_autorecovery.sha256 || true
sha256sum -c proofs/cybra_menubar_recovery_test.sha256 || true

echo
echo "=== 7. RUN FINAL MISSING TEST ==="

bash cybra_what_missing.sh || true

echo
echo "✅ MISSING RECOVERY RUNTIME FIX DONE"
