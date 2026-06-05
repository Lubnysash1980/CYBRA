#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CYBRA SPLIT 6000-LINE TRADING BOT INTO MODULES 1..64 ==="

mkdir -p \
  trading_bot/v64/models \
  trading_bot/v64/modules \
  trading_bot/v64/modules/_core \
  trading_bot/v64/reports \
  posts feeds proofs data/cybra_trading_bot/reports

SOURCE="${1:-trading_bot/v64/models/original_full_bot_6000_latest.mjs}"

if [ ! -f "$SOURCE" ]; then
  echo "❌ Файл не знайдено:"
  echo "$SOURCE"
  echo
  echo "Створи його так:"
  echo "nano trading_bot/v64/models/original_full_bot_6000_latest.mjs"
  exit 2
fi

cp "$SOURCE" trading_bot/v64/models/original_full_bot_6000_latest.mjs
cp "$SOURCE" trading_bot/v64/models/original_full_bot_v64_latest.mjs

python3 - <<'PY'
import re, json, hashlib, time, subprocess, os, shutil
from pathlib import Path

ROOT = Path.home() / "CYBRA"
SRC = ROOT / "trading_bot/v64/models/original_full_bot_6000_latest.mjs"
OUT = ROOT / "trading_bot/v64/modules"
EXTRACT = ROOT / "trading_bot/v64/models/extracted_modules"

if OUT.exists():
    for p in OUT.iterdir():
        if p.is_dir():
            shutil.rmtree(p, ignore_errors=True)
        else:
            p.unlink(missing_ok=True)

OUT.mkdir(parents=True, exist_ok=True)
EXTRACT.mkdir(parents=True, exist_ok=True)

text = SRC.read_text(encoding="utf-8", errors="ignore")
lines = text.splitlines()

def sha_bytes(b):
    return hashlib.sha256(b).hexdigest()

def sha_text(s):
    return hashlib.sha256(s.encode("utf-8", errors="ignore")).hexdigest()

def dsha(obj):
    raw = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    return sha_text(sha_text(raw))

def clean_title(s):
    s = re.sub(r"^[\s:=\-+]+", "", s or "")
    s = re.sub(r"[^a-zA-Z0-9_а-яА-ЯіїєґІЇЄҐ+-]+", "_", s.strip())
    return (s[:90] or "module").strip("_")

def parse_module_numbers(line):
    m = re.search(r"MODULE\s+([0-9][0-9\s,+\-]*)", line, re.I)
    if not m:
        return []
    spec = m.group(1).strip()
    nums = []
    parts = re.split(r"[,+\s]+", spec)
    for part in parts:
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            if a.isdigit() and b.isdigit():
                a, b = int(a), int(b)
                nums.extend(range(min(a, b), max(a, b) + 1))
        elif part.isdigit():
            nums.append(int(part))
    return sorted(set(nums))

def get_title(line):
    if ":" in line:
        return line.split(":", 1)[1].strip(" =/")
    if "-" in line:
        return line.split("-", 1)[1].strip(" =/")
    return line.strip(" /=")

markers = []
for idx, line in enumerate(lines):
    if re.search(r"MODULE\s+[0-9]", line, re.I):
        nums = parse_module_numbers(line)
        if nums:
            markers.append({
                "line": idx,
                "header": line.strip(),
                "numbers": nums,
                "title": get_title(line)
            })

entries = []
module_map = {i: [] for i in range(1, 65)}

# Core / preamble before first MODULE
if markers and markers[0]["line"] > 0:
    core_block = "\n".join(lines[:markers[0]["line"]]).rstrip() + "\n"
    core_dir = OUT / "_core"
    core_dir.mkdir(parents=True, exist_ok=True)
    core_path = core_dir / "core_runtime_before_module_01.mjs"
    core_path.write_text(core_block, encoding="utf-8")
else:
    core_block = ""

# Split module blocks
for i, mk in enumerate(markers):
    start = mk["line"]
    end = markers[i + 1]["line"] if i + 1 < len(markers) else len(lines)
    block = "\n".join(lines[start:end]).rstrip() + "\n"
    block_sha = sha_text(block)
    title = clean_title(mk["title"])

    for num in mk["numbers"]:
        if 1 <= num <= 64:
            folder = OUT / f"{num:02d}"
            folder.mkdir(parents=True, exist_ok=True)

            part_no = len(module_map[num]) + 1
            file_name = f"module_{num:02d}_part_{part_no:02d}_{title}.mjs"
            file_path = folder / file_name

            wrapper = [
                "// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT",
                f"// module_number: {num}",
                f"// part: {part_no}",
                f"// original_header: {mk['header']}",
                f"// original_line_start: {start + 1}",
                f"// original_line_end: {end}",
                "// policy: preserved_source_model",
                "// live_force_trading: disabled_by_cybra_safety_policy",
                "",
                block
            ]

            file_path.write_text("\n".join(wrapper), encoding="utf-8")

            flat_path = EXTRACT / file_name
            flat_path.write_text("\n".join(wrapper), encoding="utf-8")

            entry = {
                "module": num,
                "part": part_no,
                "numbers_in_original_header": mk["numbers"],
                "title": mk["title"],
                "header": mk["header"],
                "original_line_start": start + 1,
                "original_line_end": end,
                "lines": end - start,
                "file": str(file_path.relative_to(ROOT)),
                "flat_file": str(flat_path.relative_to(ROOT)),
                "sha256": block_sha,
                "policy": "preserved_source_model_not_direct_live_execution"
            }
            entries.append(entry)
            module_map[num].append(entry)

# Missing placeholders
missing = []
for num in range(1, 65):
    folder = OUT / f"{num:02d}"
    folder.mkdir(parents=True, exist_ok=True)
    if not module_map[num]:
        missing.append(num)
        miss = folder / f"MISSING_MODULE_{num:02d}.md"
        miss.write_text(
            f"# MODULE {num:02d} not found in source headers\n\n"
            f"The original 6000-line file was preserved, but no `MODULE {num}` header was detected.\n",
            encoding="utf-8"
        )

# Per-module index files
for num in range(1, 65):
    folder = OUT / f"{num:02d}"
    idx = []
    idx.append(f"# MODULE {num:02d}")
    idx.append("")
    if module_map[num]:
        for e in module_map[num]:
            idx.append(f"- part {e['part']}: `{e['file']}`")
            idx.append(f"  - original lines: {e['original_line_start']}..{e['original_line_end']}")
            idx.append(f"  - sha256: `{e['sha256']}`")
    else:
        idx.append("No block detected by header.")
    (folder / "INDEX.md").write_text("\n".join(idx), encoding="utf-8")

found = sorted([n for n, arr in module_map.items() if arr])
module64_files = [e["file"] for e in module_map[64]]

registry = {
    "status": "ORIGINAL_6000_LINES_SPLIT_TO_MODULES_1_64",
    "created_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "original_file": "trading_bot/v64/models/original_full_bot_6000_latest.mjs",
    "original_line_count": len(lines),
    "original_sha256": sha_bytes(SRC.read_bytes()),
    "core_preamble_lines": len(core_block.splitlines()) if core_block else 0,
    "detected_module_headers": len(markers),
    "extracted_module_parts": len(entries),
    "found_modules": found,
    "missing_modules": missing,
    "module64_found": bool(module64_files),
    "module64_files": module64_files,
    "modules_root": "trading_bot/v64/modules",
    "flat_extracted_root": "trading_bot/v64/models/extracted_modules",
    "entries": entries,
    "safety": {
        "original_6000_lines_preserved": True,
        "modules_1_64_split_separately": True,
        "module64_preserved": bool(module64_files),
        "live_force_trading_disabled": True,
        "real_trading_now": False,
        "automatic_external_tx": False,
        "manual_OWNER_approval_required": True
    }
}
registry["double_sha"] = dsha(registry)

for p in [
    ROOT / "feeds/cybra_trading_bot_6000_modules_registry.json",
    ROOT / "data/cybra_trading_bot/reports/6000_modules_registry_latest.json"
]:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(registry, ensure_ascii=False, indent=2), encoding="utf-8")

report = []
report.append("# CYBRA 6000-Line Trading Bot Modules Report")
report.append("")
report.append(f"Status: {registry['status']}")
report.append(f"Original file: `{registry['original_file']}`")
report.append(f"Original line count: {registry['original_line_count']}")
report.append(f"Original SHA256: `{registry['original_sha256']}`")
report.append(f"Detected MODULE headers: {registry['detected_module_headers']}")
report.append(f"Extracted module parts: {registry['extracted_module_parts']}")
report.append("")
report.append("## Found modules")
report.append(", ".join(map(str, found)) if found else "none")
report.append("")
report.append("## Missing modules")
report.append(", ".join(map(str, missing)) if missing else "none")
report.append("")
report.append("## Module 64")
if module64_files:
    report.append("FOUND: True")
    for f in module64_files:
        report.append(f"- `{f}`")
else:
    report.append("FOUND: False")
report.append("")
report.append("## Modules 1..64")
for num in range(1, 65):
    report.append(f"### MODULE {num:02d}")
    if module_map[num]:
        for e in module_map[num]:
            report.append(f"- part {e['part']}: `{e['file']}`")
            report.append(f"  - lines: {e['original_line_start']}..{e['original_line_end']}")
            report.append(f"  - sha256: `{e['sha256']}`")
    else:
        report.append(f"- `trading_bot/v64/modules/{num:02d}/MISSING_MODULE_{num:02d}.md`")
    report.append("")
report.append("## Safety")
for k, v in registry["safety"].items():
    report.append(f"{k}: {v}")
report.append("")
report.append("## Double SHA")
report.append(registry["double_sha"])

(ROOT / "posts/cybra_trading_bot_6000_modules_report.md").write_text("\n".join(report), encoding="utf-8")

all_index = []
all_index.append("# CYBRA Trading Bot Modules 1..64 Index")
all_index.append("")
all_index.append(f"Original: `{registry['original_file']}`")
all_index.append(f"Original lines: {registry['original_line_count']}")
all_index.append("")
for num in range(1, 65):
    all_index.append(f"## MODULE {num:02d}")
    if module_map[num]:
        for e in module_map[num]:
            all_index.append(f"- `{e['file']}`")
    else:
        all_index.append("- missing header in source")
    all_index.append("")
(OUT / "ALL_MODULES_INDEX.md").write_text("\n".join(all_index), encoding="utf-8")

# Proof with all files
proof_file = ROOT / "proofs/cybra_trading_bot_6000_modules.sha256"
module_files = []
for p in sorted(OUT.rglob("*")):
    if p.is_file():
        module_files.append(str(p.relative_to(ROOT)))
for extra in [
    "trading_bot/v64/models/original_full_bot_6000_latest.mjs",
    "feeds/cybra_trading_bot_6000_modules_registry.json",
    "posts/cybra_trading_bot_6000_modules_report.md",
    "data/cybra_trading_bot/reports/6000_modules_registry_latest.json"
]:
    module_files.append(extra)

with proof_file.open("w") as f:
    subprocess.run(["sha256sum"] + module_files, cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print("✅ SPLIT DONE")
print("ORIGINAL_LINES:", registry["original_line_count"])
print("ORIGINAL_FILE:", registry["original_file"])
print("FOUND_MODULES:", found)
print("MISSING_MODULES:", missing)
print("MODULE64_FOUND:", registry["module64_found"])
print("MODULE64_FILES:", module64_files)
print("REPORT: posts/cybra_trading_bot_6000_modules_report.md")
print("INDEX: trading_bot/v64/modules/ALL_MODULES_INDEX.md")
print("DOUBLE_SHA:", registry["double_sha"])
PY

cat > cybra-trade64-modules <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

CMD="${1:-list}"
N="${2:-}"

case "$CMD" in
  list)
    cat trading_bot/v64/modules/ALL_MODULES_INDEX.md
    ;;
  report)
    cat posts/cybra_trading_bot_6000_modules_report.md
    ;;
  original)
    echo "FILE: trading_bot/v64/models/original_full_bot_6000_latest.mjs"
    wc -l trading_bot/v64/models/original_full_bot_6000_latest.mjs
    sha256sum trading_bot/v64/models/original_full_bot_6000_latest.mjs
    ;;
  module)
    if [ -z "$N" ]; then
      echo "Usage: cybra-trade64-modules module 64"
      exit 1
    fi
    NN="$(printf "%02d" "$N")"
    echo "=== MODULE $NN ==="
    cat "trading_bot/v64/modules/$NN/INDEX.md" 2>/dev/null || true
    echo
    ls -lh "trading_bot/v64/modules/$NN" 2>/dev/null || true
    ;;
  show)
    if [ -z "$N" ]; then
      echo "Usage: cybra-trade64-modules show 64"
      exit 1
    fi
    NN="$(printf "%02d" "$N")"
    for f in trading_bot/v64/modules/$NN/module_${NN}_*.mjs; do
      [ -f "$f" ] || continue
      echo "===== $f ====="
      sed -n '1,220p' "$f"
      echo
    done
    ;;
  verify)
    sha256sum -c proofs/cybra_trading_bot_6000_modules.sha256
    ;;
  *)
    echo "Usage:"
    echo "  cybra-trade64-modules list"
    echo "  cybra-trade64-modules report"
    echo "  cybra-trade64-modules original"
    echo "  cybra-trade64-modules module 64"
    echo "  cybra-trade64-modules show 64"
    echo "  cybra-trade64-modules verify"
    ;;
esac
EOF

chmod +x cybra-trade64-modules
ln -sf "$HOME/CYBRA/cybra-trade64-modules" "$PREFIX/bin/cybra-trade64-modules" 2>/dev/null || true

echo
echo "=== VERIFY ==="
sha256sum -c proofs/cybra_trading_bot_6000_modules.sha256 || true

echo
echo "=== RESULT ==="
cybra-trade64-modules original
echo
cybra-trade64-modules module 64

echo
echo "✅ DONE"
