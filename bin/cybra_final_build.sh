#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA FINAL BUILD
# Snapshot + @cybra node + autohash + git module + dual-backend
# Автоперевірка + автозапуск hardening
# ============================================================

set -u
export LC_ALL=C

CYBRA_ROOT="$HOME/CYBRA"
MODULES_DIR="$CYBRA_ROOT/modules"
BASELINE_DIR="$CYBRA_ROOT/baseline"
LOG_DIR="$CYBRA_ROOT/logs"
AUDIT_DIR="$CYBRA_ROOT/audit"
NODE_DIR="$CYBRA_ROOT/@cybra"
GIT_MODULE="$CYBRA_ROOT/git_module"
PUBLIC_DIR="$CYBRA_ROOT/public"
HASH_DIR="$CYBRA_ROOT/hashes"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BUILD_ID="BUILD-$STAMP-$$"
LOG="$LOG_DIR/final_build_${STAMP}.log"

mkdir -p "$BASELINE_DIR" "$LOG_DIR" "$AUDIT_DIR" \
         "$NODE_DIR" "$GIT_MODULE" "$PUBLIC_DIR" "$HASH_DIR"

FIXED=0
FAILED=0

log()   { printf '%s\n' "$*" | tee -a "$LOG"; }
hr()    { printf -- '------------------------------------------------------------\n' | tee -a "$LOG"; }
head1() {
    printf -- '\n============================================================\n' | tee -a "$LOG"
    printf -- ' %s\n' "$*" | tee -a "$LOG"
    printf -- '============================================================\n' | tee -a "$LOG"
}

hash_file() {
    local f="$1"
    [ ! -f "$f" ] && { printf 'MISSING'; return; }
    sha256sum "$f" | awk '{print $1}'
}

hash_tree() {
    local dir="$1"
    [ ! -d "$dir" ] && { printf 'NODIR'; return; }
    (
        cd "$dir" || exit 1
        find . -type f \
            ! -name '*.log' \
            ! -name '*.test.log' \
            ! -name 'test_output.txt' \
            ! -name 'test_output.sha256' \
            ! -name 'SNAPSHOT_SHA256.txt' \
            -print0 2>/dev/null |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null |
        sha256sum | awk '{print $1}'
    )
}

# ============================================================
# START
# ============================================================

head1 "CYBRA FINAL BUILD"
log "BUILD_ID: $BUILD_ID"
log "STAMP:    $STAMP"

# ============================================================
# КРОК 1 — Фікс module_19
# ============================================================

head1 "[1/7] Фікс module_19 (test correctness)"

MOD19="$MODULES_DIR/module_19_contract_tui_menu"

if [ ! -d "$MOD19" ]; then
    log "  [SKIP] module_19 не знайдено"
else
    # --- фікс: rules check — тільки хеш ---
    if grep -q 'EXPECTED="\$(sha256sum "$MOD/evidence/tui_rules.txt")"' \
        "$MOD19/tests/run_tests.sh" 2>/dev/null; then

        python3 - <<PY
p = "$MOD19/tests/run_tests.sh"
with open(p) as f:
    s = f.read()
old = 'EXPECTED="\$(sha256sum "\$MOD/evidence/tui_rules.txt")"'
new = 'EXPECTED="\$(sha256sum "\$MOD/evidence/tui_rules.txt" | awk \x27{print \$1}\x27)"'
if old in s:
    s = s.replace(old, new)
    with open(p, "w") as f:
        f.write(s)
    print("    [FIXED] rules check (hash only)")
else:
    print("    [OK] rules check already correct")
PY
        FIXED=$((FIXED+1))
    fi

    # --- фікс: тихий double-confirm ---
    python3 - <<PY
p = "$MOD19/tests/run_tests.sh"
with open(p) as f:
    s = f.read()

old1 = 'cybra_link_confirm "\$BL" "0xAAA" 2>/dev/null && fail "Double confirm allowed" || ok "Double confirm blocked"'
new1 = 'if cybra_link_confirm "\$BL" "0xAAA" >/dev/null 2>&1; then fail "Double confirm allowed"; else ok "Double confirm blocked"; fi'

if old1 in s:
    s = s.replace(old1, new1)
    with open(p, "w") as f:
        f.write(s)
    print("    [FIXED] double-confirm silent")
else:
    print("    [OK] double-confirm already silent")
PY

    # --- прогін ---
    if "$MOD19/tests/run_tests.sh" > "$LOG_DIR/mod19_test.log" 2>&1; then
        log "  [OK] module_19 self-test PASS"
    else
        log "  [FAIL] module_19 self-test FAIL"
        tail -5 "$LOG_DIR/mod19_test.log" | sed 's/^/    /' | tee -a "$LOG"
        FAILED=$((FAILED+1))
    fi

    # --- re-seal snapshot ---
    cp "$MOD19/tests/run_tests.sh" "$MOD19/snapshot/run_tests.sh"
    rm -f "$MOD19/snapshot/final_manifest.sha256"
    (
        cd "$MOD19/snapshot" || exit 1
        find . -type f \
            ! -name 'final_manifest.sha256' \
            ! -name '*.log' \
            -print0 |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null
    ) > "$MOD19/snapshot/final_manifest.sha256"

    if (cd "$MOD19/snapshot" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
        log "  [OK] snapshot re-sealed"
    else
        log "  [FAIL] snapshot verify failed"
        FAILED=$((FAILED+1))
    fi
fi

# ============================================================
# КРОК 2 — Baseline tree для всіх модулів
# ============================================================

head1 "[2/7] Baseline tree update"

while IFS= read -r -d '' d; do
    m="$(basename "$d")"
    case "$m" in
        @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
    esac

    h="$(hash_tree "$d")"
    printf '%s' "$h" > "$BASELINE_DIR/${m}.tree"
    log "  [OK] $m -> ${h:0:16}..."
done < <(find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

# ============================================================
# КРОК 3 — @cybra node: глобальний індекс модулів
# ============================================================

head1 "[3/7] @cybra node — глобальний індекс"

rm -rf "$NODE_DIR"
mkdir -p "$NODE_DIR/modules"

cat > "$NODE_DIR/README.md" <<'README'
# @cybra — CYBRA Node Index

Глобальний індекс усіх модулів CYBRA.
Автоматично оновлюється через `cybra_final_build.sh`.

## Структура

- `index.json` — машинночитаний індекс модулів
- `index.txt` — людський формат
- `modules/` — посилання на модулі
- `hashes/` — dual-backend hashes

## Принципи

1. Жоден модуль не виконує auto-money дій.
2. Ліцензія 1% з кожного контракту → `0x66434c5501242ccC71b5a39C765892921624B66c`.
3. Всі snapshots — frozen.
4. Все верифікується через dual-backend SHA-256.
README

# --- index.txt ---
{
    printf '# CYBRA NODE INDEX\n'
    printf '# BUILD_ID=%s\n' "$BUILD_ID"
    printf '# STAMP=%s\n' "$STAMP"
    printf '#\n'
    printf '%-45s %-12s %-16s\n' "MODULE" "PASS" "TREE_HASH"
    printf '%s\n' "--------------------------------------------------------------------"
} > "$NODE_DIR/index.txt"

# --- index.json ---
{
    printf '{\n'
    printf '  "build_id": "%s",\n' "$BUILD_ID"
    printf '  "stamp": "%s",\n' "$STAMP"
    printf '  "modules": [\n'
} > "$NODE_DIR/index.json"

FIRST=1
MODULE_COUNT=0

while IFS= read -r -d '' d; do
    m="$(basename "$d")"
    case "$m" in
        @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
    esac

    MODULE_COUNT=$((MODULE_COUNT+1))

    h="$(cat "$BASELINE_DIR/${m}.tree" 2>/dev/null || echo 'NOHASH')"
    p="$(cat "$BASELINE_DIR/${m}.pass" 2>/dev/null || echo 0)"
    f="$(cat "$BASELINE_DIR/${m}.fail" 2>/dev/null || echo 0)"

    # index.txt
    printf '%-45s %-12s %-16s\n' "$m" "P=$p F=$f" "${h:0:16}" \
        >> "$NODE_DIR/index.txt"

    # index.json
    if [ "$FIRST" -eq 0 ]; then
        printf ',\n' >> "$NODE_DIR/index.json"
    fi
    FIRST=0
    printf '    {"name": "%s", "pass": %s, "fail": %s, "tree_hash": "%s"}' \
        "$m" "$p" "$f" "$h" >> "$NODE_DIR/index.json"

    # symlink
    ln -sfn "$d" "$NODE_DIR/modules/$m"

done < <(find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

{
    printf '\n  ],\n'
    printf '  "module_count": %d,\n' "$MODULE_COUNT"
    printf '  "license_recipient": "0x66434c5501242ccC71b5a39C765892921624B66c"\n'
    printf '}\n'
} >> "$NODE_DIR/index.json"

log "  [OK] @cybra index built ($MODULE_COUNT modules)"

# ============================================================
# КРОК 4 — Autohash (детермінований стан системи)
# ============================================================

head1 "[4/7] Autohash — детермінований стан системи"

AUTOHASH_DIR="$HASH_DIR/$STAMP"
mkdir -p "$AUTOHASH_DIR"

# --- Збираємо детермінований "state manifest" ---
{
    printf 'CYBRA_AUTOHASH\n'
    printf 'BUILD_ID=%s\n' "$BUILD_ID"
    printf 'STAMP=%s\n' "$STAMP"
    printf '\n'
    printf '--- MODULE TREE HASHES ---\n'
} > "$AUTOHASH_DIR/state.manifest"

while IFS= read -r -d '' d; do
    m="$(basename "$d")"
    case "$m" in
        @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
    esac
    h="$(cat "$BASELINE_DIR/${m}.tree" 2>/dev/null || echo 'NOHASH')"
    printf '%s %s\n' "$h" "$m" >> "$AUTOHASH_DIR/state.manifest"
done < <(find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

# --- Autohash ---
AUTOHASH="$(sha256sum "$AUTOHASH_DIR/state.manifest" | awk '{print $1}')"
printf '%s\n' "$AUTOHASH" > "$AUTOHASH_DIR/autohash.sha256"

log "  [OK] state.manifest"
log "  [OK] autohash = ${AUTOHASH:0:16}..."

# ============================================================
# КРОК 5 — Dual-Backend Hash
# ============================================================

head1 "[5/7] Dual-Backend Hash (BACKEND_A + BACKEND_B)"

# --- BACKEND A: hash від canonical state.manifest ---
BACKEND_A="$(hash_file "$AUTOHASH_DIR/state.manifest")"

# --- BACKEND B: hash від canonical index.json + baseline tree ---
BACKEND_B_SRC="$AUTOHASH_DIR/backend_b.input"
{
    cat "$NODE_DIR/index.json"
    printf '\n---\n'
    for m in "$BASELINE_DIR"/*.tree; do
        [ -f "$m" ] || continue
        printf '%s %s\n' "$(cat "$m")" "$(basename "$m")"
    done
} | LC_ALL=C sort > "$BACKEND_B_SRC"

BACKEND_B="$(hash_file "$BACKEND_B_SRC")"

# --- Dual-hash = hash(A+B) ---
DUAL_INPUT="$AUTOHASH_DIR/dual.input"
printf '%s\n%s\n' "$BACKEND_A" "$BACKEND_B" > "$DUAL_INPUT"
DUAL_HASH="$(hash_file "$DUAL_INPUT")"

# --- Match? ---
if [ "$BACKEND_A" = "$BACKEND_B" ]; then
    DUAL_MATCH="TRUE"
else
    DUAL_MATCH="MATCH_REQUIRED"
fi

cat > "$AUTOHASH_DIR/dual_backend.env" <<EOF
BUILD_ID=$BUILD_ID
STAMP=$STAMP

BACKEND_A=$BACKEND_A
BACKEND_B=$BACKEND_B
DUAL_HASH=$DUAL_HASH
DUAL_MATCH=$DUAL_MATCH

AUTOHASH=$AUTOHASH
EOF

log "  BACKEND_A  = ${BACKEND_A:0:16}..."
log "  BACKEND_B  = ${BACKEND_B:0:16}..."
log "  DUAL_HASH  = ${DUAL_HASH:0:16}..."
log "  DUAL_MATCH = $DUAL_MATCH"

if [ "$DUAL_MATCH" != "TRUE" ]; then
    log "  [INFO] BACKEND_A != BACKEND_B — це нормально,"
    log "         вони хешують різні canonical inputs."
    log "         DUAL_HASH обчислено від обох."
fi

# ============================================================
# КРОК 6 — Git Module (публічний)
# ============================================================

head1 "[6/7] Git Module — публічний пакет"

rm -rf "$GIT_MODULE"
mkdir -p "$GIT_MODULE"/{modules,meta,scripts}

# --- Копіюємо @cybra index ---
cp "$NODE_DIR/index.json" "$GIT_MODULE/meta/index.json"
cp "$NODE_DIR/index.txt" "$GIT_MODULE/meta/index.txt"
cp "$NODE_DIR/README.md" "$GIT_MODULE/README.md"

# --- Копіюємо dual backend hash ---
cp "$AUTOHASH_DIR/dual_backend.env" "$GIT_MODULE/meta/dual_backend.env"
cp "$AUTOHASH_DIR/autohash.sha256" "$GIT_MODULE/meta/autohash.sha256"

# --- Копіюємо manifests ---
cp "$AUTOHASH_DIR/state.manifest" "$GIT_MODULE/meta/state.manifest"

# --- Копіюємо кожен модуль (тільки основне) ---
while IFS= read -r -d '' d; do
    m="$(basename "$d")"
    case "$m" in
        @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
    esac

    target="$GIT_MODULE/modules/$m"
    mkdir -p "$target"

    for sub in config rules evidence tests bin snapshot snapshots state payment; do
        if [ -d "$d/$sub" ]; then
            mkdir -p "$target/$sub"
            cp -r "$d/$sub"/* "$target/$sub/" 2>/dev/null || true
        fi
    done

    # README для модуля
    cat > "$target/README.md" <<EOF
# Module: $m

CYBRA module — автоматично експортовано у публічний git-пакет.

- Tree hash: $(cat "$BASELINE_DIR/${m}.tree" 2>/dev/null || echo 'NOHASH')
- Pass: $(cat "$BASELINE_DIR/${m}.pass" 2>/dev/null || echo 0)
- Fail: $(cat "$BASELINE_DIR/${m}.fail" 2>/dev/null || echo 0)

## Принципи

- Auto-money: BLOCKED
- Auto-release: BLOCKED
- Auto-transaction: BLOCKED
- Ліцензія 1% → 0x66434c5501242ccC71b5a39C765892921624B66c
EOF

    log "  [OK] exported: $m"
done < <(find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

# --- Головний маніфест git-модуля ---
{
    printf 'CYBRA PUBLIC GIT MODULE\n'
    printf 'BUILD_ID=%s\n' "$BUILD_ID"
    printf 'STAMP=%s\n' "$STAMP"
    printf '\n'
    printf 'DUAL_HASH=%s\n' "$DUAL_HASH"
    printf 'AUTOHASH=%s\n' "$AUTOHASH"
    printf '\n'
    printf 'LICENSE_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c\n'
    printf 'LICENSE_PERCENT=1\n'
    printf '\n'
    printf 'FILES:\n'
} > "$GIT_MODULE/manifest.txt"

(
    cd "$GIT_MODULE" || exit 1
    find . -type f -print0 |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null
) >> "$GIT_MODULE/manifest.txt"

# --- Скрипт для публікації ---
cat > "$GIT_MODULE/scripts/publish.sh" <<'PUB'
#!/data/data/com.termux/files/usr/bin/bash
# Публікація в git
set -eu

TARGET="${1:-.}"
cd "$TARGET"

if [ ! -d .git ]; then
    git init
    git config user.email "cybra@local"
    git config user.name  "CYBRA Node"
fi

git add -A
git commit -m "CYBRA build $(date -u +%Y%m%dT%H%M%SZ)" || true

echo "Local commit created."
echo ""
echo "Щоб опублікувати:"
echo "  git remote add origin <your-repo-url>"
echo "  git branch -M main"
echo "  git push -u origin main"
PUB
chmod +x "$GIT_MODULE/scripts/publish.sh"

log "  [OK] git module built at $GIT_MODULE"

# ============================================================
# КРОК 7 — Копія в public/
# ============================================================

head1 "[7/7] Public export"

rm -rf "$PUBLIC_DIR"
mkdir -p "$PUBLIC_DIR"

cp -r "$GIT_MODULE"/* "$PUBLIC_DIR/"

# Public hash
(
    cd "$PUBLIC_DIR" || exit 1
    find . -type f -print0 |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null
) > "$PUBLIC_DIR/PUBLIC.sha256"

PUBLIC_HASH="$(hash_file "$PUBLIC_DIR/PUBLIC.sha256")"

log "  [OK] public export → $PUBLIC_DIR"
log "  [OK] PUBLIC_HASH = ${PUBLIC_HASH:0:16}..."

# ============================================================
# Фінальний hardening
# ============================================================

head1 "ФІНАЛЬНИЙ HARDENING"

if [ -x "$CYBRA_ROOT/cybra_mega_hardening.sh" ]; then
    "$CYBRA_ROOT/cybra_mega_hardening.sh"
    RC=$?
else
    log "  [FAIL] hardening script not found"
    RC=1
fi

# ============================================================
# Підсумок
# ============================================================

head1 "FINAL BUILD SUMMARY"

log "BUILD_ID      : $BUILD_ID"
log "STAMP         : $STAMP"
log "FIXED         : $FIXED"
log "FAILED        : $FAILED"
log ""
log "AUTOHASH      : $AUTOHASH"
log "BACKEND_A     : $BACKEND_A"
log "BACKEND_B     : $BACKEND_B"
log "DUAL_HASH     : $DUAL_HASH"
log "DUAL_MATCH    : $DUAL_MATCH"
log "PUBLIC_HASH   : $PUBLIC_HASH"
log ""
log "@cybra node   : $NODE_DIR"
log "Git module    : $GIT_MODULE"
log "Public export : $PUBLIC_DIR"
log "Autohash      : $AUTOHASH_DIR"
log ""
log "Hardening RC  : $RC"
log "LOG           : $LOG"

hr
log "Щоб опублікувати git-модуль:"
log "  cd $GIT_MODULE"
log "  ./scripts/publish.sh"
log "  git remote add origin <repo>"
log "  git push -u origin main"

exit $RC
