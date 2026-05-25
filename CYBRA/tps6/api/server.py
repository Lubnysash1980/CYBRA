from fastapi import FastAPI
from pydantic import BaseModel
from tps6.core.blockchain_core import create_genesis, balances, load_chain, add_block
from tps6.tx.transaction_core import create_tx
from tps6.validator.validator_core import validate_tx
from tps6.proof.proof_core import make_proof
from tps6.explorer.explorer_core import status

OWNER = "FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y"

app = FastAPI(title="TPS6 Native Chain API")

class SendTx(BaseModel):
    sender: str
    receiver: str
    amount: int

@app.get("/status")
def api_status():
    return status()

@app.get("/balance")
def api_balance():
    return balances()

@app.get("/chain")
def api_chain():
    return load_chain()

@app.get("/proof")
def api_proof():
    return make_proof()

@app.post("/genesis")
def api_genesis():
    return create_genesis(OWNER, 1000000)

@app.post("/send")
def api_send(tx: SendTx):
    payload = create_tx(tx.sender, tx.receiver, tx.amount)
    ok, reason = validate_tx(payload)
    if not ok:
        return {"ok": False, "error": reason}
    block = add_block([payload])
    return {"ok": True, "block": block}
