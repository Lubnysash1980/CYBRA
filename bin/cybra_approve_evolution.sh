#!/data/data/com.termux/files/usr/bin/bash
set -u
module="$1"
[ -z "$module" ] && { echo "Usage: cybra_approve_evolution <module_name>"; exit 1; }
dir="$HOME/CYBRA/modules/$module"
[ ! -d "$dir" ] && { echo "Module not found: $module"; exit 1; }

hash="$(
    cd "$dir" || exit 1
    find . -type f \
        ! -name '*.log' \
        ! -name '*.test.log' \
        ! -name 'test_output.txt' \
        ! -name 'test_output.sha256' \
        ! -name 'SNAPSHOT_SHA256.txt' \
        -print0 |
    sort -z |
    xargs -0 -r sha256sum |
    sha256sum | awk '{print $1}'
)"

mkdir -p "$HOME/CYBRA/evolution"
printf '%s' "$hash" > "$HOME/CYBRA/evolution/${module}.approved"
echo "Evolution approved for $module"
echo "Hash: $hash"
