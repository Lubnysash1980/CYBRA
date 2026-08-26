#!/data/data/com.termux/files/usr/bin/bash

ROOT="$HOME/CYBRA"
ENV_FILE="$ROOT/cybroncybra_domain.env"

if [ -f "$ENV_FILE" ]; then
    . "$ENV_FILE"
fi

export DOMAIN
export CYBRA_DOMAIN
export CYBRON_DOMAIN
export CYBRONCYBRA_DOMAIN
export CYBRONCYBRA_ROOT

echo "CYBRON DOMAIN: $CYBRONCYBRA_DOMAIN"
