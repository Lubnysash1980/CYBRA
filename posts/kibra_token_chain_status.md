# KIBRA Image Token Chain

Status: active proof-chain

## Token

- Type: **Image**
- Name: **Кібра**
- Symbol: **KIBRA**
- Total Supply: **49 000 000 000 000 000**
- OWNER allocation 60%: **29 400 000 000 000 000**
- Pool allocation 40%: **19 600 000 000 000 000**

## Chain

- Height: 7
- Target interval: 30 sec
- Difficulty min: 2
- Difficulty max safe/mobile: 4
- External blockchain anchor: queued manually, not automatic

## Latest block


- Latest index: `6`
- Latest hash: `008d79a470194224659a2b6c6a109594eb5818446a444732fb7fd57991dc6d17`
- Latest double SHA: `276c074e3c6e0cb4a3d716e2c256755a6843d425bf0062ab0b7a3a317cf480a2`
- Latest difficulty: `2`
- POW OK: `True`
- Shares: `40`


## Difficulty stream

- block `0` difficulty `2` hash `0009ef400c073dd2b1e2f3fe...` shares `14` pow_ok `True`
- block `1` difficulty `3` hash `0007773a785ed4037da542d0...` shares `2` pow_ok `True`
- block `2` difficulty `4` hash `000054cc3d0b18f2b6c5eff6...` shares `6` pow_ok `True`
- block `3` difficulty `4` hash `000080003f082db86ad705ec...` shares `22` pow_ok `True`
- block `4` difficulty `3` hash `0000f65c9116a62d651b768c...` shares `21` pow_ok `True`
- block `5` difficulty `2` hash `003a676ebdf5bf79ef0e082e...` shares `21` pow_ok `True`
- block `6` difficulty `2` hash `008d79a470194224659a2b6c...` shares `40` pow_ok `True`


## Proof meaning

Кожен блок містить:

- timestamp;
- previous block hash;
- token policy hash;
- AI tasks merkle root;
- local mined shares;
- difficulty;
- proof-of-work hash;
- block double SHA;
- manual external blockchain anchor queue.

Це створює доказову локальну мережу Кібри.  
Для публічного зовнішнього блокчейну потрібен окремий ручний on-chain anchor.

## Files

- `parliament/token_kibra/kibra_token_policy.json`
- `blockchain/kibra_chain/latest.block.json`
- `blockchain/kibra_chain/latest.block.hash`
- `blockchain/kibra_chain/difficulty_stream.jsonl`
- `feeds/kibra_token_chain_status.json`
- `posts/kibra_token_chain_status.md`
- `proofs/kibra_token_chain.sha256`
