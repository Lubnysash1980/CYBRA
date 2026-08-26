const fs = require('fs');
const ethers = require('ethers');

function wait(ms) { return new Promise(r => setTimeout(r, ms)); }
function log(msg) { console.log('[LOG]', msg); }
function ok(msg) { console.log('✅', msg); }
function warn(msg) { console.warn('⚠️', msg); }
function error(msg) { console.error('❌', msg); }

// Завантаження .env
function loadEnv() {
  try {
    const env = {};
    const lines = fs.readFileSync('.env', 'utf8').split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const [key, ...val] = trimmed.split('=');
      env[key.trim()] = val.join('=').trim();
    }
    return env;
  } catch (e) {
    error('Не вдалося прочитати .env:', e.message);
    process.exit(1);
  }
}

const env = loadEnv();
let provider, wallet, bytecode, nonce, gasPrice, tx, signedTx;

// Рівень 1: перевірка ключа
async function level1_env() {
  log('=== РІВЕНЬ 1: ПЕРЕВІРКА .env ===');
  let key = env.HOT_PRIVATE_KEY;
  if (!key) { error('HOT_PRIVATE_KEY відсутній'); process.exit(1); }
  key = key.trim();
  if (!key.startsWith('0x')) key = '0x' + key;
  if (key.length !== 66) key = key.slice(0, 66);
  env.HOT_PRIVATE_KEY = key;
  ok('Ключ коректний, довжина: ' + key.length);
  return key;
}

// Рівень 2: очищення та виправлення довжини байткоду
async function level2_bytecode() {
  log('=== РІВЕНЬ 2: ОЧИЩЕННЯ БАЙТКОДУ ===');
  let code = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
  if (!code) { error('Файл contracts/CybraToken.bin порожній.'); process.exit(1); }
  if (!code.startsWith('0x')) code = '0x' + code;
  // Видаляємо всі не-hex символи після 0x
  let hexPart = code.slice(2).replace(/[^0-9a-fA-F]/g, '');
  // Якщо довжина непарна, додаємо провідний нуль
  if (hexPart.length % 2 !== 0) {
    warn('Довжина байткоду непарна (' + hexPart.length + '). Додаємо провідний нуль.');
    hexPart = '0' + hexPart;
  }
  code = '0x' + hexPart;
  fs.writeFileSync('./contracts/CybraToken.bin', code);
  ok('Байткод завантажено, довжина: ' + code.length + ' (парна)');
  return code;
}

// Рівень 3: RPC
async function level3_rpc() {
  log('=== РІВЕНЬ 3: ПІДКЛЮЧЕННЯ ДО RPC ===');
  const rpc = env.BSC_RPC || 'https://bsc-dataseed.binance.org/';
  provider = new ethers.providers.JsonRpcProvider(rpc);
  try { await provider.getBlockNumber(); } catch (e) {
    error('Не вдалося підключитися до RPC:', e.message);
    process.exit(1);
  }
  wallet = new ethers.Wallet(env.HOT_PRIVATE_KEY, provider);
  ok('Гаманець створено, адреса: ' + wallet.address);
  nonce = await wallet.getTransactionCount();
  ok('nonce: ' + nonce);
  gasPrice = await provider.getGasPrice();
  const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
  if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;
  ok('gasPrice: ' + ethers.utils.formatUnits(gasPrice, 'gwei') + ' Gwei');
}

// Рівень 4: формування транзакції
async function level4_build_tx() {
  log('=== РІВЕНЬ 4: ФОРМУВАННЯ ТРАНЗАКЦІЇ ===');
  tx = {
    data: bytecode,
    gasLimit: ethers.utils.hexlify(3000000),
    chainId: ethers.utils.hexlify(56),
    nonce: ethers.utils.hexlify(nonce),
    gasPrice: ethers.utils.hexlify(gasPrice)
  };
  for (const [k, v] of Object.entries(tx)) {
    log('  ' + k + ' => ' + typeof v + ' (' + (typeof v === 'string' ? v.slice(0, 20) + '...' : v) + ')');
  }
  ok('Транзакція сформована.');
}

// Рівень 5: багаторазова спроба підпису (до 7 разів)
async function level5_sign() {
  log('=== РІВЕНЬ 5: ПІДПИС (до 7 спроб) ===');
  let attempt = 0;
  const maxAttempts = 7;
  while (attempt < maxAttempts) {
    try {
      signedTx = await wallet.signTransaction(tx);
      ok('Підписано, довжина: ' + signedTx.length);
      fs.writeFileSync('./wallet/runtime/signed.tx', signedTx);
      return;
    } catch (e) {
      attempt++;
      error('Спроба ' + attempt + ' не вдалася: ' + e.message);
      if (attempt < maxAttempts) {
        // Спроба підписати без провайдера
        try {
          const walletOnly = new ethers.Wallet(env.HOT_PRIVATE_KEY);
          signedTx = await walletOnly.signTransaction(tx);
          ok('Підписано (без провайдера), довжина: ' + signedTx.length);
          fs.writeFileSync('./wallet/runtime/signed.tx', signedTx);
          return;
        } catch (e2) {
          warn('Підпис без провайдера також не вдався: ' + e2.message);
        }
        // Збільшуємо nonce на 1 і пробуємо знову
        const newNonce = nonce + attempt;
        tx.nonce = ethers.utils.hexlify(newNonce);
        warn('nonce збільшено до ' + newNonce);
        await wait(2000);
      } else {
        error('Підпис не вдався після ' + maxAttempts + ' спроб.');
        process.exit(1);
      }
    }
  }
}

// Рівень 6: надсилання
async function level6_send() {
  log('=== РІВЕНЬ 6: НАДСИЛАННЯ ===');
  try {
    const response = await provider.sendTransaction(signedTx);
    ok('Хеш: ' + response.hash);
    fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);
    log('Очікуємо підтвердження...');
    let receipt = null;
    for (let i = 0; i < 30; i++) {
      receipt = await provider.getTransactionReceipt(response.hash);
      if (receipt) break;
      log('Спроба ' + (i+1) + '/30');
      await wait(5000);
    }
    if (!receipt) { error('Тайм-аут'); process.exit(1); }
    if (receipt.status === 1) {
      ok('Адреса контракту: ' + receipt.contractAddress);
      fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
    } else {
      error('Транзакція провалилась');
      process.exit(1);
    }
  } catch (e) {
    error('Помилка надсилання: ' + e.message);
    process.exit(1);
  }
}

async function main() {
  console.log('🛠️  ФІНАЛЬНИЙ ДЕПЛОЙ (7 СПРОБ, ВИПРАВЛЕННЯ ДОВЖИНИ)');
  try {
    await level1_env();
    bytecode = await level2_bytecode();
    await level3_rpc();
    await level4_build_tx();
    await level5_sign();
    await level6_send();
    console.log('🎉 ДЕПЛОЙ УСПІШНО ЗАВЕРШЕНО!');
  } catch (e) {
    console.error('❌ КРИТИЧНА ПОМИЛКА:', e.message);
    console.error(e.stack);
    process.exit(1);
  }
}

main();
