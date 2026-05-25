from tps6.core.blockchain_core import load_chain, balances

def status():
    chain = load_chain()
    return {
        "blocks": len(chain),
        "latest_hash": chain[-1]["hash"] if chain else None,
        "balances": balances()
    }
