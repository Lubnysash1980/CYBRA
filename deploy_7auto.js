const fs = require('fs');
const ethers = require('ethers');

// -------------------- УТИЛІТИ --------------------
function wait(ms) { return new Promise(r => setTimeout(r, ms)); }

function log(msg) { console.log('[LOG]', msg); }

function ok(msg) { console.log('✅', msg); }

function warn(msg) { console.warn('⚠️', msg); }

function error(msg) { console.error('❌', msg); }

// Читання .env вручну
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

// ============================================================
// РІВЕНЬ 1: ПЕРЕВІРКА .env
// ============================================================
async function level1_env() {
  log('=== РІВЕНЬ 1: ПЕРЕВІРКА .env ===');
  let key = env.HOT_PRIVATE_KEY;
  if (!key) {
    error('HOT_PRIVATE_KEY відсутній у .env');
    process.exit(1);
  }
  key = key.trim();
  if (!key.startsWith('0x')) {
    warn('Ключ не починається з 0x. Додаємо автоматично.');
    key = '0x' + key;
  }
  if (key.length !== 66) {
    warn('Довжина ключа не 66 символів. Можливо, зайві пробіли. Виправляємо.');
    key = key.slice(0, 66);
  }
  env.HOT_PRIVATE_KEY = key;
  ok('Ключ коректний, довжина: ' + key.length);
  // Зберігаємо виправлений ключ у файл .env
  // (не обов'язково, але можна)
  return key;
}

// ============================================================
// РІВЕНЬ 2: ПЕРЕВІРКА БАЙТКОДУ
// ============================================================
async function level2_bytecode() {
  log('=== РІВЕНЬ 2: ПЕРЕВІРКА БАЙТКОДУ ===');
  let code = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
  if (!code) {
    error('Файл contracts/CybraToken.bin порожній.');
    process.exit(1);
  }
  if (!code.startsWith('0x')) {
    warn('Байткод не починається з 0x. Додаємо.');
    code = '0x' + code;
    // Перезаписуємо файл для подальших запусків
    fs.writeFileSync('./contracts/CybraToken.bin', code);
  }
  // Перевірка на hex-символи
  const hexPart = code.slice(2);
  if (!/^[0-9a-fA-F]+$/.test(hexPart)) {
    error('Байткод містить недопустимі символи. Перевірте файл.');
    process.exit(1);
  }
  if (code.length < 1000) {
    warn('Байткод занадто короткий (можливо, обрізаний). Довжина: ' + code.length);
  }
  ok('Байткод завантажено, довжина: ' + code.length);
  return code;
}

// ============================================================
// РІВЕНЬ 3: ПІДКЛЮЧЕННЯ ДО RPC ТА ОТРИМАННЯ NONCE/GASPRICE
// ============================================================
async function level3_rpc() {
  log('=== РІВЕНЬ 3: ПІДКЛЮЧЕННЯ ДО RPC ===');
  const rpc = env.BSC_RPC || 'https://bsc-dataseed.binance.org/';
  provider = new ethers.providers.JsonRpcProvider(rpc);
  // Перевірка підключення
  let blockNumber;
  try {
    blockNumber = await provider.getBlockNumber();
  } catch (e) {
    error('Не вдалося підключитися до RPC:', e.message);
    process.exit(1);
  }
  ok('Підключено до RPC, блок: ' + blockNumber);

  // Створюємо гаманець
  wallet = new ethers.Wallet(env.HOT_PRIVATE_KEY, provider);
  ok('Гаманець створено, адреса: ' + wallet.address);

  // Отримуємо nonce
  try {
    nonce = await wallet.getTransactionCount();
  } catch (e) {
    error('Не вдалося отримати nonce:', e.message);
    process.exit(1);
  }
  ok('nonce: ' + nonce);

  // Отримуємо gasPrice
  try {
    gasPrice = await provider.getGasPrice();
  } catch (e) {
    error('Не вдалося отримати gasPrice:', e.message);
    process.exit(1);
  }
  const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
  if (gasPrice.lt(minGasPrice)) {
    warn('gasPrice менше 5 Gwei, встановлюємо 5 Gwei');
    gasPrice = minGasPrice;
  }
  ok('gasPrice: ' + ethers.utils.formatUnits(gasPrice, 'gwei') + ' Gwei');
  return { nonce, gasPrice };
}

// ============================================================
// РІВЕНЬ 4: НОРМАЛІЗАЦІЯ ПОЛІВ ТРАНЗАКЦІЇ
// ============================================================
async function level4_normalize() {
  log('=== РІВЕНЬ 4: НОРМАЛІЗАЦІЯ ПОЛІВ ===');
  // Формуємо транзакцію з гарантованими hex-рядками для всіх полів
  // Оскільки ethers.utils.hexlify приймає різні типи, ми примусово перетворюємо все
  const txData = {
    data: bytecode, // вже hex
    gasLimit: ethers.utils.hexlify(3000000),
    chainId: ethers.utils.hexlify(56),
    nonce: ethers.utils.hexlify(nonce),
    gasPrice: ethers.utils.hexlify(gasPrice)
  };
  // Перевіряємо, що всі поля мають тип string і починаються з 0x
  for (const [key, value] of Object.entries(txData)) {
    if (typeof value !== 'string' || !value.startsWith('0x')) {
      warn('Поле ' + key + ' не є hex-рядком, виправляємо.');
      txData[key] = ethers.utils.hexlify(value);
    }
  }
  tx = txData;
  ok('Транзакція нормалізована.');
  return tx;
}

// ============================================================
// РІВЕНЬ 5: ПЕРЕВІРКА МОЖЛИВОСТІ HEXLIFY ДЛЯ КОЖНОГО ПОЛЯ
// ============================================================
async function level5_hexlify_check() {
  log('=== РІВЕНЬ 5: ПЕРЕВІРКА HEXLIFY ===');
  let allOk = true;
  for (const [key, value] of Object.entries(tx)) {
    try {
      const hexed = ethers.utils.hexlify(value);
      if (hexed !== value) {
        // якщо hexlify повернув інший рядок, можливо, треба оновити
        warn('Поле ' + key + ' змінено при hexlify. Оновлюємо.');
        tx[key] = hexed;
      }
      ok('Поле ' + key + ' пройшло hexlify.');
    } catch (e) {
      error('Поле ' + key + ' не проходить hexlify: ' + e.message);
      // Спроба виправити: якщо це число або BigNumber, перетворимо в hex
      try {
        const fixed = ethers.utils.hexlify(value);
        tx[key] = fixed;
        ok('Поле ' + key + ' виправлено.');
      } catch (e2) {
        error('Не вдалося виправити поле ' + key);
        allOk = false;
      }
    }
  }
  if (!allOk) {
    error('Деякі поля не вдалося виправити. Перевірте вручну.');
    process.exit(1);
  }
  ok('Всі поля валідні для hexlify.');
  return tx;
}

// ============================================================
// РІВЕНЬ 6: ПІДПИС З ПОВТОРНИМИ СПРОБАМИ
// ============================================================
async function level6_sign() {
  log('=== РІВЕНЬ 6: ПІДПИС ТРАНЗАКЦІЇ ===');
  let attempt = 0;
  const maxAttempts = 3;
  while (attempt < maxAttempts) {
    try {
      signedTx = await wallet.signTransaction(tx);
      ok('Підписано, довжина: ' + signedTx.length);
      fs.writeFileSync('./wallet/runtime/signed.tx', signedTx);
      return signedTx;
    } catch (e) {
      attempt++;
      error('Спроба підпису ' + attempt + ' не вдалася: ' + e.message);
      if (attempt < maxAttempts) {
        warn('Спробуємо збільшити nonce на 1...');
        // Можливо, nonce вже використаний, тому збільшуємо
        const newNonce = nonce + attempt;
        tx.nonce = ethers.utils.hexlify(newNonce);
        warn('nonce встановлено в ' + newNonce);
        await wait(1000);
      } else {
        error('Підпис не вдався після ' + maxAttempts + ' спроб.');
        process.exit(1);
      }
    }
  }
}

// ============================================================
// РІВЕНЬ 7: НАДСИЛАННЯ ТА ПІДТВЕРДЖЕННЯ
// ============================================================
async function level7_send() {
  log('=== РІВЕНЬ 7: НАДСИЛАННЯ ТА ПІДТВЕРДЖЕННЯ ===');
  try {
    const response = await provider.sendTransaction(signedTx);
    ok('Хеш: ' + response.hash);
    fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);

    log('Очікуємо підтвердження (до 2 хвилин)...');
    let receipt = null;
    for (let i = 0; i < 24; i++) {
      receipt = await provider.getTransactionReceipt(response.hash);
      if (receipt) break;
      log('Спроба ' + (i+1) + '/24: ще не підтверджено...');
      await wait(5000);
    }
    if (!receipt) {
      error('Тайм-аут. Перевірте статус на BSCScan за хешем: ' + response.hash);
      process.exit(1);
    }
    if (receipt.status === 1) {
      ok('Адреса контракту: ' + receipt.contractAddress);
      fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
    } else {
      error('Транзакція провалилась (status=0)');
      process.exit(1);
    }
  } catch (e) {
    error('Помилка надсилання: ' + e.message);
    process.exit(1);
  }
}

// ============================================================
// ГОЛОВНА ФУНКЦІЯ
// ============================================================
async function main() {
  console.log('🛠️  АВТОМАТИЧНИЙ ДЕПЛОЙ З 7 РІВНЯМИ ПЕРЕВІРКИ');
  try {
    await level1_env();
    bytecode = await level2_bytecode();
    await level3_rpc();
    await level4_normalize();
    await level5_hexlify_check();
    await level6_sign();
    await level7_send();
    console.log('🎉 ДЕПЛОЙ УСПІШНО ЗАВЕРШЕНО!');
  } catch (e) {
    console.error('❌ КРИТИЧНА ПОМИЛКА:', e.message);
    console.error(e.stack);
    process.exit(1);
  }
}

main();
