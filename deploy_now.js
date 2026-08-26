const fs = require('fs');
const ethers = require('ethers');
require('dotenv').config();

async function main() {
    const provider = new ethers.providers.JsonRpcProvider(process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/');
    const wallet = new ethers.Wallet(process.env.HOT_PRIVATE_KEY, provider);

    // Читаємо байткод і додаємо 0x
    let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
    if (!bytecode.startsWith('0x')) bytecode = '0x' + bytecode;

    // Отримуємо nonce та gasPrice
    const nonce = await wallet.getTransactionCount();
    let gasPrice = await provider.getGasPrice();
    const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
    if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;

    // Створюємо об'єкт транзакції
    const tx = {
        data: bytecode,
        gasLimit: 3000000,
        chainId: 56,
        nonce: nonce,
        gasPrice: gasPrice   // ethers приймає BigNumber
    };

    console.log('✅ Транзакція створена:');
    console.log('   nonce:', nonce);
    console.log('   gasPrice:', ethers.utils.formatUnits(gasPrice, 'gwei'), 'Gwei');

    // Підписуємо
    const signedTx = await wallet.signTransaction(tx);
    console.log('✅ Підписано, довжина:', signedTx.length);

    // Зберігаємо підписану транзакцію
    fs.writeFileSync('./wallet/runtime/signed.tx', signedTx);
    console.log('✅ signed.tx збережено');

    // Надсилаємо
    const response = await provider.sendTransaction(signedTx);
    console.log('✅ Хеш:', response.hash);
    fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);

    // Очікуємо підтвердження
    console.log('⏳ Очікуємо підтвердження...');
    const receipt = await response.wait();
    console.log('✅ Адреса контракту:', receipt.contractAddress);
    fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
}

main().catch(err => {
    console.error('❌ Помилка:', err.message);
    process.exit(1);
});
