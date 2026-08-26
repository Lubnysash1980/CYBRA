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

  const tx = {
    data: bytecode,
    gasLimit: 3000000,
    chainId: 56,
    nonce: nonce,
    gasPrice: gasPrice  // передаємо BigNumber без змін
  };

  console.log('🔹 Підпис транзакції...');
  const signedTx = await wallet.signTransaction(tx);
  console.log('✅ Підписано, довжина:', signedTx.length);
  fs.writeFileSync('./wallet/runtime/signed.tx', signedTx);

  console.log('🔹 Надсилання транзакції...');
  const response = await provider.sendTransaction(signedTx);
  console.log('✅ Хеш:', response.hash);
  fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);

  console.log('⏳ Очікування підтвердження...');
  const receipt = await response.wait();
  console.log('✅ Адреса контракту:', receipt.contractAddress);
  fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
}

main().catch(err => {
  console.error('❌ ПОМИЛКА:', err.message);
  console.error('Стек:', err.stack);
  process.exit(1);
});
