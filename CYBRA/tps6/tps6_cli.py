import sys, json
from tps6.core.blockchain_core import create_genesis, balances, load_chain
from tps6.tx.transaction_core import create_tx
from tps6.validator.validator_core import validate_tx
from tps6.core.blockchain_core import add_block
from tps6.proof.proof_core import make_proof
from tps6.explorer.explorer_core import status

OWNER = "FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y"

cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

if cmd == "genesis":
    print(json.dumps(create_genesis(OWNER, 1000000), ensure_ascii=False, indent=2))

elif cmd == "balance":
    print(json.dumps(balances(), ensure_ascii=False, indent=2))

elif cmd == "send":
    sender, receiver, amount = sys.argv[2], sys.argv[3], sys.argv[4]
    tx = create_tx(sender, receiver, amount)
    ok, reason = validate_tx(tx)
    if not ok:
        print(json.dumps({"ok": False, "error": reason}, ensure_ascii=False, indent=2))
    else:
        block = add_block([tx])
        print(json.dumps({"ok": True, "block": block}, ensure_ascii=False, indent=2))

elif cmd == "proof":
    print(json.dumps(make_proof(), ensure_ascii=False, indent=2))

elif cmd == "chain":
    print(json.dumps(load_chain(), ensure_ascii=False, indent=2))

else:
    print(json.dumps(status(), ensure_ascii=False, indent=2))
