#!/usr/bin/env python3
import os
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

BASE = Path.home() / "CYBRA"

Q_QUEUE = "cybra:parliament:queue"
Q_SUBMISSIONS = "cybra:parliament:submissions"
Q_RESULTS = "cybra:parliament:results"
Q_FAILED = "cybra:parliament:failed"
Q_AUDIT = "cybra:audit"

SCRIPT_MAP = {
    "kibra_mint_liquidity_task": "kibra_mint_liquidity_handler.sh",
    "ai_block_enforcer_task": "ai_block_enforcer_handler.sh",
    "kibra_stats_recommendations_task": "kibra_stats_recommendations_handler.sh",
    "kibra_mint_management_task": "kibra_mint_management_handler.sh",
    "kibra_mint_audit_task": "kibra_mint_audit_handler.sh",
    "kibra_mint_promotion_task": "kibra_mint_promotion_handler.sh",
    "ai_tasks_to_blocks_task": "ai_tasks_to_blocks_handler.sh",
    "air_missile_danger_task": "air_missile_danger_handler.sh",
    "kibra_block_ai_support_task": "kibra_block_ai_support_handler.sh",
    "kibra_price_sell_repair_task": "kibra_price_sell_repair_handler.sh",
    "kibra_bridge_pool_task": "kibra_bridge_pool_handler.sh",
    "generic_ai_safe_task": "generic_ai_safe_task_handler.sh",
    "native_kibra_evolution_task": "native_kibra_evolution_handler.sh",
    "ai_until_done_task": "ai_until_done_handler.sh",
    "finance_gap_evolution_task": "finance_gap_evolution_handler.sh",
    "finance_token_profit_audit_task": "finance_token_profit_audit_handler.sh",
    "kibra_market_exchange_task": "kibra_market_exchange_handler.sh",
    "finance_infrastructure_task": "finance_infrastructure_handler.sh",
    "existing_tasks_activation_task": "existing_tasks_activation_handler.sh",
    "evolution_deployment_task": "evolution_deployment_handler.sh",
    "monetization_department_task": "monetization_department_handler.sh",
    "owner_orchestrator_task": "owner_orchestrator_handler.sh",
    "kibra_token_chain_task": "kibra_token_chain_handler.sh",
    "token_pool_ai_task": "token_pool_ai_handler.sh",
    "finance_department_task": "finance_department_handler.sh",
    "institution_audit_task": "institution_audit_handler.sh",
    "hash_module_test_task": "hash_module_test_handler.sh",
    "evolution_guard_task": "evolution_guard_handler.sh",
    "biometric_succession_task": "biometric_succession_handler.sh",
    "closed_evolution_selfseal_task": "closed_evolution_selfseal_handler.sh",
    "audit_dedupe_test_task": "audit_dedupe_test_handler.sh",
    "dialogue_key_task": "dialogue_key_handler.sh",
    "committee_creation_task": "evo_committee_handler.sh",
    "evo_committee_task": "evo_committee_handler.sh",
    "revision_organ_task": "revision_organ_handler.sh",
    "analytics_committee_task": "analytics_committee_handler.sh",
    "air_alert_task": "air_alert_handler.sh",
    "watchdog_task": "air_alert_handler.sh",
    "ai_network_task": "neural_runtime_handler.sh",
    "audit_task": "mainnet_gate_audit_handler.sh",
    "ai_research_task": "ai_web_bridge_handler.sh",
    "design_task": "design_task_handler.sh",
    "test_basic_task": "basic_task_handler.sh",
    "ai_question_task": "ai_research_backend.sh",
    "emergency_alert_task": "emergency_alert_handler.sh",
    "emergency_alert_test_task": "emergency_alert_handler.sh",
    "legal_registry_check_task": "legal_registry_check_handler.sh",
    "native_token_ecosystem_task": "create_native_token_ecosystem.sh",
    "native_token_evolution_task": "native_token_evolution.sh",
    "cybra_coin_completion_task": "cybra_coin_completion.sh",
    "secure_token_vault_task": "token_vault_autofix.sh",
    "wallet_visible_token_plan_task": "wallet_visible_token_plan.sh",
    "github_pages_task": "cybra_self_healing_supervisor.sh",
    "workers_task": "cybra_self_healing_supervisor.sh",
    "cybra_autofix_task": "cybra_autofix.sh",
    "smart_autofix_mining_pool_task": "cybra_mining_autofix.sh",
    "pmz_historical_metadata_task": "create_pmz_registry.sh"
}

def double_sha(text: str) -> str:
    b = text.encode("utf-8")
    return hashlib.sha256(hashlib.sha256(b).digest()).hexdigest()

def run_script(script_name: str, task: dict):
    script = BASE / script_name
    if not script.exists():
        return {
            "ok": False,
            "returncode": 127,
            "stdout": "",
            "stderr": f"script not found: {script_name}"
        }

    env = os.environ.copy()
    env["CYBRA_TASK_JSON"] = json.dumps(task, ensure_ascii=False)

    p = subprocess.run(
        ["bash", str(script)],
        cwd=str(BASE),
        text=True,
        capture_output=True,
        timeout=1200,
        env=env
    )

    return {
        "ok": p.returncode == 0,
        "returncode": p.returncode,
        "stdout": p.stdout,
        "stderr": p.stderr
    }

def main():
    print("=== CYBRA PARLIAMENT EXECUTOR V6 RESTORED STARTED ===")

    r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

    while True:
        raw = r.rpop(Q_QUEUE)

        if raw is None:
            raw = r.rpop(Q_SUBMISSIONS)

        if raw is None:
            break

        try:
            task = json.loads(raw)
            task_type = task.get("type")
            topic = task.get("topic", "unknown")
            h = double_sha(raw)

            r.lpush(Q_AUDIT, h)

            script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)

            if not script_name:
                result = {
                    "topic": topic,
                    "type": task_type,
                    "status": "no_executor_mapping",
                    "double_sha": h,
                    "message": "No script mapping yet"
                }
                r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))
                print("⚠️ no_executor_mapping:", topic)
                continue

            execution = run_script(script_name, task)

            result = {
                "topic": topic,
                "type": task_type,
                "status": "executed" if execution["ok"] else "failed",
                "script": script_name,
                "double_sha": h,
                "retries": 0,
                "execution": execution,
                "time": time.time()
            }

            r.lpush(Q_RESULTS, json.dumps(result, ensure_ascii=False))

            if execution["ok"]:
                print("✅ executed:", topic)
            else:
                r.lpush(Q_FAILED, json.dumps(result, ensure_ascii=False))
                print("❌ failed:", topic)

        except Exception as e:
            fail_hash = double_sha(raw)
            fail = {
                "raw": raw,
                "double_sha": fail_hash,
                "error": str(e),
                "time": time.time()
            }
            r.lpush(Q_FAILED, json.dumps(fail, ensure_ascii=False))
            print("❌ parse/runtime failed:", fail_hash)

if __name__ == "__main__":
    main()
