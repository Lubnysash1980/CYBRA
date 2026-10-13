#!/data/data/com.termux/files/usr/bin/bash
# CYBRA MIGRATE — оновлення старих контрактів до нової схеми

set -u
export LC_ALL=C

MOD="$HOME/CYBRA/modules/module_19_contract_tui_menu"
CONTRACTS="$MOD/contracts"
BACKUP="$MOD/backups/migration_$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$BACKUP"

MIGRATED=0
SKIPPED=0

migrate_contract() {
    local f="$1"
    local cid="$(basename "$f" .env)"

    # Перевірка: чи вже має REFUND_ENABLED
    if grep -qm1 '^REFUND_ENABLED=' "$f"; then
        SKIPPED=$((SKIPPED+1))
        return 0
    fi

    # Backup
    cp "$f" "$BACKUP/$cid.env"

    # --- Обчислюємо deadline ---
    local deadline
    deadline="$(date -u -d "+72 hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
                date -u -d "@$(($(date +%s) + 72*3600))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
                date -u +%Y-%m-%dT%H:%M:%SZ)"

    # --- Перевіряємо чи є NET_WEI (для fallback) ---
    local net_wei="$(grep -m1 '^NET_WEI=' "$f" | cut -d= -f2-)"
    local buyer="$(grep -m1 '^BUYER=' "$f" | cut -d= -f2-)"

    # --- Додаємо REFUND блок перед REAL_TRANSACTION_SENT ---
    if grep -qm1 '^REAL_TRANSACTION_SENT=' "$f"; then
        # Вставляємо перед цим рядком
        awk -v deadline="$deadline" '
            /^REAL_TRANSACTION_SENT=/ {
                print "# === REFUND (migrated) ==="
                print "REFUND_ENABLED=TRUE"
                print "REFUND_TIMEOUT_HOURS=72"
                print "REFUND_DEADLINE=" deadline
                print "BUYER_FINAL_DECISION=CONFIRMED"
                print "BUYER_FINAL_DECISION_AT="
                print "FINAL_DELIVERY_ALLOWED=TRUE"
                print "REFUND_STATUS=NOT_REQUIRED"
                print "REFUND_TRIGGER="
                print "REFUND_AMOUNT_WEI=0"
                print "REFUND_RECIPIENT="
                print "REFUNDED_AT="
                print "CUSTOM_TERMS_COUNT=0"
                print ""
            }
            { print }
        ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    else
        # Просто додаємо в кінець
        cat >> "$f" <<EOF

# === REFUND (migrated) ===
REFUND_ENABLED=TRUE
REFUND_TIMEOUT_HOURS=72
REFUND_DEADLINE=$deadline
BUYER_FINAL_DECISION=CONFIRMED
BUYER_FINAL_DECISION_AT=
FINAL_DELIVERY_ALLOWED=TRUE
REFUND_STATUS=NOT_REQUIRED
REFUND_TRIGGER=
REFUND_AMOUNT_WEI=0
REFUND_RECIPIENT=
REFUNDED_AT=
CUSTOM_TERMS_COUNT=0
EOF
    fi

    # --- Оновлюємо stage якщо треба ---
    local stage="$(grep -m1 '^STAGE=' "$f" | cut -d= -f2-)"
    if [ "$stage" = "COMPLETE" ]; then
        # COMPLETE контракти не потребують refund
        sed -i 's/^REFUND_STATUS=.*/REFUND_STATUS=NOT_REQUIRED/' "$f"
        sed -i 's/^BUYER_FINAL_DECISION=.*/BUYER_FINAL_DECISION=CONFIRMED/' "$f"
    fi

    MIGRATED=$((MIGRATED+1))
    printf '  [OK] %s\n' "$cid"
}

echo "=== CYBRA MIGRATE CONTRACTS ==="
echo "Backup: $BACKUP"
echo ""

for f in "$CONTRACTS"/*.env; do
    [ -f "$f" ] || continue
    migrate_contract "$f"
done

echo ""
echo "--- Результат ---"
printf '  Migrated: %s\n' "$MIGRATED"
printf '  Skipped:  %s\n' "$SKIPPED"
echo ""
echo "Backup: $BACKUP"
