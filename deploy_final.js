const fs = require('fs');
const ethers = require('ethers');
require('dotenv').config();

async function main() {
    // 1. Провайдер і гаманець
    const provider = new ethers.providers.JsonRpcProvider(
        process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/'
    );
    const wallet = new ethers.Wallet(process.env.HOT_PRIVATE_KEY, provider);

    // 2. Байткод
    let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
    if (!bytecode.startsWith('0x')) bytecode = '0x' + bytecode;
    console.log('📄 Байткод завантажено, довжина:', bytecode.length);

    // 3. Отримуємо nonce та gasPrice
    const nonce = await wallet.getTransactionCount();
    console.log('🔹 nonce:', nonce);

    let gasPrice = await provider.getGasPrice();
    const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
    if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;
    console.log('🔹 gasPrice (Gwei):', ethers.utils.formatUnits(gasPrice, 'gwei'));

    // 4. Формуємо транзакцію (передаємо gasPrice як BigNumber – ethers сам перетворить у hex)
    const tx = {
        data: bytecode,
        gasLimit: 3000000,
        chainId: 56,
        nonce: nonce,
        gasPrice: gasPrice   // <-- BigNumber, ethers приймає
    };

    console.log('📦 Транзакція сформована (без підпису)');

    // 5. Підписуємо
    const signedTx = await wallet.signTransaction(tx);
    console.log('✅ Підписано, довжина:', signedTx.length);
    fs.writeFileSync('./wallet/runtime/signed.tx', signedTx);
    console.log('💾 signed.tx збережено');

    // 6. Надсилаємо
    const response = await provider.sendTransaction(signedTx);
    console.log('✅ Хеш:', response.hash);
    fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);

    // 7. Очікуємо підтвердження
    console.log('⏳ Очікуємо підтвердження...');
    const receipt = await response.wait();
    console.log('✅ Адреса контракту:', receipt.contractAddress);
    fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
}

main().catch(err => {
    console.error('❌ КРИТИЧНА ПОМИЛКА:', err.message);
    console.error('Стек:', err.stack);
    process.exit(1);
});
