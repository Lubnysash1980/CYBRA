const fs = require('fs');
const ethers = require('ethers');

// Читання .env вручну
const env = fs.readFileSync('.env', 'utf8')
  .split('\n')
  .filter(line => line.trim() && !line.startsWith('#'))
  .reduce((acc, line) => {
    const [key, ...val] = line.split('=');
    acc[key.trim()] = val.join('=').trim();
    return acc;
  }, {});

const privateKey = env.HOT_PRIVATE_KEY.startsWith('0x') 
  ? env.HOT_PRIVATE_KEY 
  : '0x' + env.HOT_PRIVATE_KEY;

const provider = new ethers.providers.JsonRpcProvider(
  env.BSC_RPC || 'https://bsc-dataseed.binance.org/'
);
const wallet = new ethers.Wallet(privateKey, provider);

async function main() {
  console.log('🔹 Завантаження байткоду...');
  let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
  if (!bytecode.startsWith('0x')) bytecode = '0x' + bytecode;
  console.log('🔹 Довжина байткоду:', bytecode.length);

  console.log('🔹 Отримання nonce...');
  const nonce = await wallet.getTransactionCount();
  console.log('🔹 nonce:', nonce);

  console.log('🔹 Отримання gasPrice...');
  let gasPrice = await provider.getGasPrice();
  const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
  if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;
  console.log('🔹 gasPrice (Gwei):', ethers.utils.formatUnits(gasPrice, 'gwei'));

  // --- ФОРМУЄМО ТРАНЗАКЦІЮ БЕЗ HEXLIFY ДЛЯ DATA ---
  const tx = {
    data: bytecode,                    // вже з 0x
    gasLimit: 3000000,                 // число
    chainId: 56,                       // число
    nonce: nonce,                      // число
    gasPrice: gasPrice                 // BigNumber
  };

  console.log('🔹 Підпис транзакції...');
  const signedTx = await wallet.signTransaction(tx);
  console.log('✅ Підписано, довжина:', signedTx.length);
  fs.writeFileSync('./wallet/runtime/signed.tx', signedTx);

  console.log('🔹 Надсилання транзакції...');
  const response = await provider.sendTransaction(signedTx);
  console.log('✅ Хеш:', response.hash);
  fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);

  console.log('⏳ Очікуємо підтвердження (до 2 хвилин)...');
  let receipt = null;
  for (let i = 0; i < 24; i++) {
    receipt = await provider.getTransactionReceipt(response.hash);
    if (receipt) break;
    console.log(`   Спроба ${i+1}/24: ще не підтверджено...`);
    await new Promise(r => setTimeout(r, 5000));
  }

  if (!receipt) {
    console.error('❌ Тайм-аут очікування. Перевірте статус на BSCScan за хешем:', response.hash);
    process.exit(1);
  }

  if (receipt.status === 1) {
    console.log('✅ Адреса контракту:', receipt.contractAddress);
    fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
  } else {
    console.error('❌ Транзакція провалилась (status=0)');
    process.exit(1);
  }
}

main().catch(err => {
  console.error('❌ КРИТИЧНА ПОМИЛКА:', err.message);
  console.error('Стек:', err.stack);
  process.exit(1);
});
