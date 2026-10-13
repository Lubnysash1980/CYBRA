#!/data/data/com.termux/files/usr/bin/bash
set -u
module="$1"
[ -z "$module" ] && { echo "Usage: cybra_seal_snapshot.sh <module_name>"; exit 1; }
dir="$HOME/CYBRA/modules/$module"
[ ! -d "$dir" ] && { echo "Module not found: $module"; exit 1; }

snap=""
for s in "$dir/snapshot" "$dir/snapshots"; do
    [ -d "$s" ] && { snap="$s"; break; }
done
[ -z "$snap" ] && { echo "No snapshot dir in $module"; exit 1; }

target="$snap"
sub="$(find "$snap" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z | tail -z -n1 | tr -d '\0')"
[ -n "$sub" ] && target="$sub"

echo "Sealing: $target"

(
    cd "$target" || exit 1
    find . -type f \
        ! -name 'final_manifest.sha256' \
        ! -name 'snapshot.sha256' \
        ! -name 'SNAPSHOT_SHA256.txt' \
        ! -name 'SNAPSHOT_DOUBLE_SHA256.txt' \
        ! -name 'double_sha256' \
        ! -name '*.log' \
        -print0 2>/dev/null |
    sort -z |
    xargs -0 -r sha256sum 2>/dev/null
) > "$target/final_manifest.sha256"

count=$(wc -l < "$target/final_manifest.sha256" 2>/dev/null || echo 0)
if [ "$count" -eq 0 ]; then
    printf '# EMPTY_SNAPSHOT module=%s ts=%s\n' "$module" "$(date -u +%Y%m%dT%H%M%SZ)" \
        > "$target/final_manifest.sha256"
    echo "  [OK] empty manifest created (no files yet)"
    exit 0
fi

if (cd "$target" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
    echo "  [OK] final_manifest.sha256 (files=$count)"
else
    echo "  [WARN] verify failed"
    exit 1
fi
