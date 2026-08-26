#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/CYBRA"

[ -f .env ] || { echo "❌ .env відсутній"; exit 1; }
set -a; source .env; set +a

echo "ℹ️  Створення pending_deploy.tx..."
node -e "
const fs = require('fs');
const ethers = require('ethers');
const provider = new ethers.providers.JsonRpcProvider(process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/');
const wallet = new ethers.Wallet(process.env.HOT_PRIVATE_KEY, provider);
const bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
const clean = bytecode.startsWith('0x') ? bytecode : '0x' + bytecode;
(async () => {
    const nonce = await wallet.getTransactionCount();
    let gasPrice = await provider.getGasPrice();
    const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
    if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;
    const tx = { data: clean, gasLimit: 3000000, chainId: 56, nonce, gasPrice: gasPrice.toHexString() };
    fs.writeFileSync('./wallet/runtime/pending_deploy.tx', JSON.stringify(tx, null, 2));
    console.log('✅ pending_deploy.tx створено');
})();
"

echo "ℹ️  Підпис..."
node -e "
const fs=require('fs');
const ethers=require('ethers');
const txData=JSON.parse(fs.readFileSync('./wallet/runtime/pending_deploy.tx','utf8'));
const wallet=new ethers.Wallet(process.env.HOT_PRIVATE_KEY);
wallet.signTransaction(txData).then(signed=>{
    fs.writeFileSync('./wallet/runtime/signed.tx', signed);
    console.log('✅ signed.tx створено');
}).catch(e=>{ console.error('❌ Помилка підпису:', e.message); process.exit(1); });
"

echo "ℹ️  Надсилання..."
node -e "
const fs=require('fs');
const ethers=require('ethers');
const signed=fs.readFileSync('./wallet/runtime/signed.tx','utf8').trim();
const provider=new ethers.providers.JsonRpcProvider(process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/');
provider.sendTransaction(signed).then(tx=>{
    console.log('✅ Хеш:', tx.hash);
    fs.writeFileSync('./wallet/runtime/deploy_hash.txt', tx.hash);
    return tx.wait();
}).then(receipt=>{
    console.log('✅ Адреса контракту:', receipt.contractAddress);
    fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
}).catch(e=>{ console.error('❌ Помилка надсилання:', e.message); process.exit(1); });
"

echo "✅ Деплой завершено!"
