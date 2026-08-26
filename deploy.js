const fs = require('fs');
const ethers = require('ethers');

// Завантаження .env вручну (без dotenv)
const env = fs.readFileSync('.env', 'utf8')
  .split('\n')
  .filter(line => line.trim() && !line.startsWith('#'))
  .reduce((acc, line) => {
    const [key, ...val] = line.split('=');
    acc[key.trim()] = val.join('=').trim();
    return acc;
  }, {});

const provider = new ethers.providers.JsonRpcProvider(env.BSC_RPC || 'https://bsc-dataseed.binance.org/');
const wallet = new ethers.Wallet(env.HOT_PRIVATE_KEY, provider);

async function main() {
  let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
  if (!bytecode.startsWith('0x')) bytecode = '0x' + bytecode;

  const nonce = await wallet.getTransactionCount();
  let gasPrice = await provider.getGasPrice();
  const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
  if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;

  const tx = {
    data: bytecode,
    gasLimit: 3000000,
    chainId: 56,
    nonce,
    gasPrice: gasPrice.toHexString()   // однозначно hex-рядок
  };

  console.log('Nonce:', nonce);
  console.log('Gas price (Gwei):', ethers.utils.formatUnits(gasPrice, 'gwei'));

  const signed = await wallet.signTransaction(tx);
  fs.writeFileSync('./wallet/runtime/signed.tx', signed);
  console.log('✅ signed.tx збережено, довжина:', signed.length);

  const response = await provider.sendTransaction(signed);
  console.log('✅ Хеш:', response.hash);
  fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);

  console.log('⏳ Очікуємо підтвердження...');
  const receipt = await response.wait();
  console.log('✅ Адреса контракту:', receipt.contractAddress);
  fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
}

main().catch(err => {
  console.error('❌ ПОМИЛКА:', err.message);
  console.error(err.stack);
  process.exit(1);
});
