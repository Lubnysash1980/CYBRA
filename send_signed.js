const fs = require('fs');
const ethers = require('ethers');

// Читання .env для RPC
const env = fs.readFileSync('.env', 'utf8')
  .split('\n')
  .filter(line => line.trim() && !line.startsWith('#'))
  .reduce((acc, line) => {
    const [key, ...val] = line.split('=');
    acc[key.trim()] = val.join('=').trim();
    return acc;
  }, {});

const provider = new ethers.providers.JsonRpcProvider(
  env.BSC_RPC || 'https://bsc-dataseed.binance.org/'
);

async function main() {
  const signed = fs.readFileSync('./wallet/runtime/signed.tx', 'utf8').trim();
  if (!signed || signed.length < 200) {
    throw new Error('signed.tx порожній або занадто короткий');
  }

  console.log('🔹 Надсилання транзакції...');
  const response = await provider.sendTransaction(signed);
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
    console.error('❌ Тайм-аут. Перевірте статус на BSCScan за хешем:', response.hash);
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
  console.error('❌ ПОМИЛКА:', err.message);
  process.exit(1);
});
