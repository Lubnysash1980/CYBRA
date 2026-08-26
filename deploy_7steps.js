const fs = require('fs');
const ethers = require('ethers');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function waitEnter(msg = 'Натисніть Enter для продовження...') {
  return new Promise(resolve => {
    rl.question('\n' + msg + ' ', () => resolve());
  });
}

// Читання .env
function loadEnv() {
  try {
    const env = fs.readFileSync('.env', 'utf8')
      .split('\n')
      .filter(line => line.trim() && !line.startsWith('#'))
      .reduce((acc, line) => {
        const [key, ...val] = line.split('=');
        acc[key.trim()] = val.join('=').trim();
        return acc;
      }, {});
    return env;
  } catch(e) {
    console.error('❌ Не вдалося прочитати .env:', e.message);
    process.exit(1);
  }
}

const env = loadEnv();

// -------------------- ЕТАП 1 --------------------
async function step1_check_env() {
  console.log('\n===== ЕТАП 1: ПЕРЕВІРКА .env =====');
  const key = env.HOT_PRIVATE_KEY;
  if (!key) {
    console.error('❌ HOT_PRIVATE_KEY відсутній у .env');
    process.exit(1);
  }
  if (!key.startsWith('0x')) {
    console.warn('⚠️  Ключ не починається з 0x. Додаємо автоматично.');
    env.HOT_PRIVATE_KEY = '0x' + key;
  }
  console.log('✅ Ключ знайдено, довжина:', env.HOT_PRIVATE_KEY.length);
  console.log('   Перші 10 символів:', env.HOT_PRIVATE_KEY.slice(0, 10) + '...');
  console.log('   RPC:', env.BSC_RPC || 'https://bsc-dataseed.binance.org/');
  await waitEnter();
}

// -------------------- ЕТАП 2 --------------------
async function step2_check_bytecode() {
  console.log('\n===== ЕТАП 2: ПЕРЕВІРКА БАЙТКОДУ =====');
  try {
    let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
    if (!bytecode) throw new Error('Файл порожній');
    console.log('📄 Довжина байткоду:', bytecode.length, 'символів');
    if (bytecode.startsWith('0x')) {
      console.log('✅ Починається з 0x');
    } else {
      console.log('⚠️  Байткод не починається з 0x. Додаємо...');
      bytecode = '0x' + bytecode;
      // Перезаписуємо файл з 0x для наступних кроків
      fs.writeFileSync('./contracts/CybraToken.bin', bytecode);
      console.log('✅ 0x додано та файл оновлено');
    }
    console.log('   Початок:', bytecode.slice(0, 30) + '...');
    console.log('   Кінець:', bytecode.slice(-30));
    // Перевірка на допустимі hex-символи
    const hexPart = bytecode.startsWith('0x') ? bytecode.slice(2) : bytecode;
    if (!/^[0-9a-fA-F]+$/.test(hexPart)) {
      console.error('❌ Байткод містить недопустимі символи (не hex)');
      process.exit(1);
    }
    console.log('✅ Байткод валідний');
    // Зберігаємо для подальших кроків
    global.bytecode = bytecode;
    await waitEnter();
  } catch(e) {
    console.error('❌ Помилка читання байткоду:', e.message);
    process.exit(1);
  }
}

// -------------------- ЕТАП 3 --------------------
async function step3_get_nonce_gas() {
  console.log('\n===== ЕТАП 3: ОТРИМАННЯ NONCE ТА GASPRICE =====');
  try {
    const provider = new ethers.providers.JsonRpcProvider(
      env.BSC_RPC || 'https://bsc-dataseed.binance.org/'
    );
    const wallet = new ethers.Wallet(env.HOT_PRIVATE_KEY, provider);
    console.log('🔹 Запит до мережі BSC...');
    const nonce = await wallet.getTransactionCount();
    console.log('✅ nonce:', nonce);
    let gasPrice = await provider.getGasPrice();
    console.log('✅ gasPrice (Gwei):', ethers.utils.formatUnits(gasPrice, 'gwei'));
    const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
    if (gasPrice.lt(minGasPrice)) {
      console.log('⚠️  gasPrice менше 5 Gwei, встановлюємо 5 Gwei');
      gasPrice = minGasPrice;
    }
    global.provider = provider;
    global.wallet = wallet;
    global.nonce = nonce;
    global.gasPrice = gasPrice;
    await waitEnter();
  } catch(e) {
    console.error('❌ Помилка отримання nonce/gasPrice:', e.message);
    process.exit(1);
  }
}

// -------------------- ЕТАП 4 --------------------
async function step4_create_tx() {
  console.log('\n===== ЕТАП 4: СТВОРЕННЯ НЕПІДПИСАНОЇ ТРАНЗАКЦІЇ =====');
  const tx = {
    data: global.bytecode,
    gasLimit: 3000000,
    chainId: 56,
    nonce: global.nonce,
    gasPrice: global.gasPrice
  };
  console.log('📦 Об\'єкт транзакції (без підпису):');
  console.log('   data (початок):', tx.data.slice(0, 40) + '...');
  console.log('   gasLimit:', tx.gasLimit);
  console.log('   chainId:', tx.chainId);
  console.log('   nonce:', tx.nonce);
  console.log('   gasPrice (Gwei):', ethers.utils.formatUnits(tx.gasPrice, 'gwei'));
  global.tx = tx;
  await waitEnter('Перевірте дані. Натисніть Enter для продовження або Ctrl+C для виходу...');
}

// -------------------- ЕТАП 5 --------------------
async function step5_validate_fields() {
  console.log('\n===== ЕТАП 5: ВАЛІДАЦІЯ КОЖНОГО ПОЛЯ (hexlify) =====');
  const fields = ['data', 'gasLimit', 'chainId', 'nonce', 'gasPrice'];
  let allOk = true;
  for (const key of fields) {
    try {
      const value = global.tx[key];
      const hexed = ethers.utils.hexlify(value);
      console.log(`✅ ${key}: hexlify OK -> ${typeof hexed === 'string' ? hexed.slice(0, 20) + '...' : hexed}`);
    } catch(e) {
      console.error(`❌ ${key}: hexlify FAILED - ${e.message}`);
      console.log(`   Значення: ${global.tx[key]} (тип: ${typeof global.tx[key]})`);
      allOk = false;
    }
  }
  if (!allOk) {
    console.error('\n⚠️  Деякі поля не пройшли hexlify. Спробуйте вручну виправити значення.');
    console.log('Ви можете відредагувати об\'єкт tx у цьому скрипті або змінити .env');
    await waitEnter('Після виправлень натисніть Enter для повторної перевірки...');
    // Повторна перевірка
    await step5_validate_fields();
  } else {
    console.log('✅ Всі поля валідні.');
    await waitEnter();
  }
}

// -------------------- ЕТАП 6 --------------------
async function step6_sign() {
  console.log('\n===== ЕТАП 6: ПІДПИС ТРАНЗАКЦІЇ =====');
  try {
    const signed = await global.wallet.signTransaction(global.tx);
    console.log('✅ Підписано, довжина:', signed.length);
    fs.writeFileSync('./wallet/runtime/signed.tx', signed);
    console.log('💾 signed.tx збережено у wallet/runtime/');
    global.signed = signed;
    await waitEnter();
  } catch(e) {
    console.error('❌ ПОМИЛКА ПІДПИСУ:', e.message);
    console.log('Стек:', e.stack);
    console.log('\nМожливі причини:');
    console.log('  - Неправильний приватний ключ');
    console.log('  - Некоректний nonce (спробуйте збільшити на 1)');
    console.log('  - Некоректний gasPrice (має бути hex-рядок)');
    console.log('  - Проблеми з байткодом (перевірте довжину)');
    await waitEnter('Натисніть Enter, щоб спробувати знову або вийдіть Ctrl+C...');
    // Повторна спроба підпису
    await step6_sign();
  }
}

// -------------------- ЕТАП 7 --------------------
async function step7_send() {
  console.log('\n===== ЕТАП 7: НАДСИЛАННЯ ТА ПІДТВЕРДЖЕННЯ =====');
  try {
    const response = await global.provider.sendTransaction(global.signed);
    console.log('✅ Хеш:', response.hash);
    fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);
    console.log('⏳ Очікуємо підтвердження (до 2 хвилин)...');
    let receipt = null;
    for (let i = 0; i < 24; i++) {
      receipt = await global.provider.getTransactionReceipt(response.hash);
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
    console.log('\n🎉 ДЕПЛОЙ УСПІШНО ЗАВЕРШЕНО!');
    rl.close();
  } catch(e) {
    console.error('❌ ПОМИЛКА НАДСИЛАННЯ:', e.message);
    await waitEnter('Натисніть Enter для повторної спроби або Ctrl+C для виходу...');
    await step7_send();
  }
}

// Запуск
(async () => {
  console.log('🛠️  СКРИПТ 7-РІВНЕВОГО ДЕПЛОЮ');
  console.log('Кожен етап зупиняється для перевірки. Натискайте Enter для продовження.\n');
  await step1_check_env();
  await step2_check_bytecode();
  await step3_get_nonce_gas();
  await step4_create_tx();
  await step5_validate_fields();
  await step6_sign();
  await step7_send();
})();
