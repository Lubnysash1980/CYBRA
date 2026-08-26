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
  // Байткод
  let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
  if (!bytecode.startsWith('0x')) bytecode = '0x' + bytecode;

  // nonce та gasPrice
  const nonce = await wallet.getTransactionCount();
  let gasPrice = await provider.getGasPrice();
  const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
  if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;

  // Транзакція з явними hex-рядками
  const tx = {
    data: bytecode,
    gasLimit: '0x' + 3000000.toString(16),
    chainId: '0x' + 56..toString(16),
    nonce: '0x' + nonce.toString(16),
    gasPrice: '0x' + gasPrice.toHexString().slice(2) // прибираємо 0x і додаємо знову
  };

  console.log('✅ Непідписана транзакція створена');
  console.log('   nonce:', tx.nonce);
  console.log('   gasPrice:', tx.gasPrice);

  // Підпис
  const signed = await wallet.signTransaction(tx);
  fs.writeFileSync('./wallet/runtime/signed.tx', signed);
  console.log('✅ signed.tx збережено, довжина:', signed.length);
}

main().catch(err => {
  console.error('❌ ПОМИЛКА:', err.message);
  console.error('Стек:', err.stack);
  process.exit(1);
});
