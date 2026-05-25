from tps6.core.blockchain_core import create_genesis, add_block, balances
from tps6.tx.transaction_core import create_tx
from tps6.validator.validator_core import validate_tx
from tps6.proof.proof_core import make_proof
from tps6.explorer.explorer_core import status
import json
from pathlib import Path

OWNER = "FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y"

genesis = create_genesis(OWNER, 1000000)
tx = create_tx(OWNER, "tps6_test_wallet_001", 100)
ok, reason = validate_tx(tx)

if ok:
    block = add_block([tx])
else:
    block = {"error": reason}

proof = make_proof()
report = {
    "genesis": genesis,
    "test_tx_valid": ok,
    "test_block": block,
    "proof": proof,
    "status": status()
}

out = Path.home() / "CYBRA" / "tps6" / "reports" / "tps6_report.json"
out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
