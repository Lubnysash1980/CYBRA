const fs = require('fs');
const ethers = require('ethers');
require('dotenv').config();

const mode = process.argv[2];
const txPath = './wallet/runtime/pending_deploy.tx';

if (!fs.existsSync(txPath)) {
    console.error('❌ Немає pending_deploy.tx');
    process.exit(1);
}
const txData = JSON.parse(fs.readFileSync(txPath, 'utf8'));
const provider = new ethers.providers.JsonRpcProvider(process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/');

if (mode === 'hot') {
    const key = process.env.HOT_PRIVATE_KEY;
    if (!key || key === '0x0000000000000000000000000000000000000000000000000000000000000000') {
        console.error('❌ HOT_PRIVATE_KEY не встановлено або заглушка');
        process.exit(1);
    }
    const wallet = new ethers.Wallet(key, provider);
    wallet.sendTransaction(txData).then(tx => {
        console.log('✅ Хеш:', tx.hash);
        fs.writeFileSync('./wallet/runtime/deploy_hash.txt', tx.hash);
        return tx.wait();
    }).then(receipt => {
        console.log('✅ Адреса:', receipt.contractAddress);
        fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
    }).catch(e => console.error('❌ Помилка:', e.message));
} else if (mode === 'cold') {
    console.log('❄️ Підпишіть вручну:');
    console.log(JSON.stringify(txData, null, 2));
    console.log('Після підпису збережіть signed.tx у wallet/runtime/signed.tx');
} else {
    console.log('Використання: node wallet/sign.js hot|cold');
}
