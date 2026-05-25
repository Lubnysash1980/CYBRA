from tps6.core.blockchain_core import balances

def validate_tx(tx):
    if int(tx.get("amount", 0)) <= 0:
        return False, "amount_must_be_positive"
    sender = tx.get("from")
    if sender:
        bal = balances().get(sender, 0)
        if bal < int(tx["amount"]):
            return False, "insufficient_balance"
    return True, "ok"
