const fs = require('fs');
const ethers = require('ethers');

// Читання .env
const env = fs.readFileSync('.env', 'utf8')
  .split('\n')
  .filter(line => line.trim() && !line.startsWith('#'))
  .reduce((acc, line) => {
    const [key, ...val] = line.split('=');
    acc[key.trim()] = val.join('=').trim();
    return acc;
  }, {});

const privateKey = env.HOT_PRIVATE_KEY.startsWith('0x') ? env.HOT_PRIVATE_KEY : '0x' + env.HOT_PRIVATE_KEY;
const provider = new ethers.providers.JsonRpcProvider(env.BSC_RPC || 'https://bsc-dataseed.binance.org/');
const wallet = new ethers.Wallet(privateKey, provider);

async function main() {
  // Байткод
  let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
  if (!bytecode.startsWith('0x')) bytecode = '0x' + bytecode;

  // Отримуємо nonce та gasPrice
  const nonce = await wallet.getTransactionCount();
  let gasPrice = await provider.getGasPrice();
  const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
  if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;

  // Перетворюємо ВСЕ в hex-рядки
  const tx = {
    data: bytecode,                                            // вже hex
    gasLimit: ethers.utils.hexlify(3000000),                  // '0x2dc6c0'
    chainId: ethers.utils.hexlify(56),                        // '0x38'
    nonce: ethers.utils.hexlify(nonce),                       // '0x...'
    gasPrice: ethers.utils.hexlify(gasPrice)                  // '0x...'
  };

  console.log('🔹 Транзакція (hex-рядки):');
  console.log('   nonce:', tx.nonce);
  console.log('   gasPrice:', tx.gasPrice);
  console.log('   gasLimit:', tx.gasLimit);
  console.log('   chainId:', tx.chainId);
  console.log('   data (початок):', tx.data.slice(0, 30) + '...');

  // Підпис
  console.log('🔹 Підпис...');
  const signedTx = await wallet.signTransaction(tx);
  console.log('✅ Підписано, довжина:', signedTx.length);
  fs.writeFileSync('./wallet/runtime/signed.tx', signedTx);

  // Надсилання
  console.log('🔹 Надсилання...');
  const response = await provider.sendTransaction(signedTx);
  console.log('✅ Хеш:', response.hash);
  fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);

  // Очікування
  console.log('⏳ Очікуємо підтвердження...');
  let receipt = null;
  for (let i = 0; i < 24; i++) {
    receipt = await provider.getTransactionReceipt(response.hash);
    if (receipt) break;
    console.log(`   Спроба ${i+1}/24: ще не підтверджено...`);
    await new Promise(r => setTimeout(r, 5000));
  }

  if (!receipt) {
    console.error('❌ Тайм-аут. Перевірте хеш:', response.hash);
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
