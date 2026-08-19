#!/bin/bash
ORDER="R⚕️"
BASE="$HOME/CYBRA/orders/order_${ORDER}"
CSV="$BASE/production/suppliers/validation/candidates_real.csv"

calculate_medians() {
    tail -n +2 "$CSV" | awk -F',' '
    {
        category=$1; price=$5;
        if (price != "") {
            prices[category][count[category]] = price;
            count[category]++;
        }
    }
    END {
        for (cat in prices) {
            n = count[cat];
            for (i=0; i<n-1; i++) {
                for (j=i+1; j<n; j++) {
                    if (prices[cat][i] > prices[cat][j]) {
                        tmp = prices[cat][i];
                        prices[cat][i] = prices[cat][j];
                        prices[cat][j] = tmp;
                    }
                }
            }
            if (n % 2 == 1) {
                median = prices[cat][int(n/2)];
            } else {
                median = (prices[cat][int(n/2)-1] + prices[cat][int(n/2)]) / 2;
            }
            print cat, median;
        }
    }'
}

MEDIANS_FILE=$(mktemp)
calculate_medians > "$MEDIANS_FILE"

tail -n +2 "$CSV" | while IFS=',' read -r CATEGORY MANUFACTURER MODEL COUNTRY PRICE_USD QTY DELIVERY_DAYS WARRANTY_MONTHS CERT_URL TECH_DOC_URL REF_COUNT CONTACT_EMAIL SOURCE VERIFIED_BY DATE_VERIFIED QUALITY_SCORE YEARS_ON_MARKET; do
    if [ -z "$PRICE_USD" ]; then
        continue
    fi
    MEDIAN=$(awk -v cat="$CATEGORY" '$1==cat {print $2}' "$MEDIANS_FILE")
    if [ -z "$MEDIAN" ]; then
        PRICE_SCORE=70
    else
        DIFF=$(echo "$PRICE_USD $MEDIAN" | awk '{print ($1 - $2) / $2 * 100}')
        PRICE_SCORE=$(echo "$DIFF" | awk '{score = 100 - ($1 * 2); if (score < 0) score = 0; if (score > 100) score = 100; printf "%.0f", score}')
    fi
    echo "$CATEGORY,$MANUFACTURER,$MODEL,$PRICE_USD,$PRICE_SCORE"
done > "$BASE/control/price_scores.txt"

echo "✅ Розрахунок price_score завершено"
