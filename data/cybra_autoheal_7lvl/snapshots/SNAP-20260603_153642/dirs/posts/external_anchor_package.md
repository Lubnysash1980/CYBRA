# CYBRA External Blockchain Anchor Package

Status: **manual_external_anchor_package_ready**

- Automatic on-chain tx: **false**
- Manual wallet signature required: **true**
- Source items packaged: **12**
- Latest KIBRA hash: `008a14703eb452470cbbed74931d44f6220897823d71c436b3dacb5fab11f896`
- Anchor package root: `8e6a795d5883000714fd0af9a6274518021f43c56d8c5577ee2652503aa743c1`

## Meaning

Proof-и з Redis anchor queue зібрані в один anchor package.  
Реальна зовнішня blockchain-транзакція не виконувалась.  
Для зовнішнього anchor треба вручну взяти `anchor_package_root` і записати його окремою on-chain транзакцією.

## Files

- `feeds/external_anchor_package.json`
- `posts/external_anchor_package.md`
- `proofs/external_anchor_package.sha256`
