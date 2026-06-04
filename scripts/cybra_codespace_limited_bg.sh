#!/usr/bin/env bash
set +e
cd "${CYBRA_ROOT:-$PWD}" || exit 1
mkdir -p logs/hybrid runtime/redis
bash scripts/cybra_cloud_heavy_cycle.sh
