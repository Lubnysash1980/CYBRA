#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/CYBRA"

echo "🛠️  АВТОМАТИЧНИЙ ДЕПЛОЙ (Node.js + ethers)"
echo ""

# -------------------- 1. ВСТАНОВЛЕННЯ ЗАЛЕЖНОСТЕЙ --------------------
echo "[1/7] Перевірка та встановлення залежностей..."

if ! command -v node &> /dev/null; then
    echo "❌ Node.js не встановлено. Встановлюємо..."
    pkg install nodejs-lts -y
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -ge 20 ]; then
    echo "⚠️  Виявлено Node.js v$NODE_VERSION. Рекомендується v18 LTS."
    echo "   Встановлюємо ethers@6 (сумісний)..."
    npm install ethers@6 --legacy-peer-deps || { echo "❌ Не вдалося встановити ethers"; exit 1; }
else
    echo "✅ Node.js v$NODE_VERSION (сумісний з ethers v5)"
    npm install ethers@5.7.2 --legacy-peer-deps || { echo "❌ Не вдалося встановити ethers"; exit 1; }
fi

echo "✅ Залежності встановлено."

# -------------------- 2. ПЕРЕВІРКА .env --------------------
echo "[2/7] Перевірка .env..."
if [ ! -f .env ]; then
    echo "❌ Файл .env відсутній."
    echo "   Створіть його з HOT_PRIVATE_KEY=0xваш_ключ"
    exit 1
fi
source .env
if [ -z "${HOT_PRIVATE_KEY:-}" ] || [ "$HOT_PRIVATE_KEY" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "❌ HOT_PRIVATE_KEY не встановлено або використовується заглушка."
    exit 1
fi
echo "✅ .env завантажено."

# -------------------- 3. ВИПРАВЛЕННЯ БАЙТКОДУ --------------------
echo "[3/7] Виправлення байткоду..."
if [ ! -f contracts/CybraToken.bin ] || [ ! -s contracts/CybraToken.bin ]; then
    echo "❌ Файл contracts/CybraToken.bin відсутній або порожній."
    exit 1
fi

# Виправляємо байткод через Node.js
node -e "
const fs = require('fs');
let code = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
if (!code.startsWith('0x')) code = '0x' + code;
let hex = code.slice(2).replace(/[^0-9a-fA-F]/g, '');
if (hex.length % 2 !== 0) { hex = '0' + hex; }
code = '0x' + hex;
fs.writeFileSync('./contracts/CybraToken.bin', code);
console.log('✅ Байткод виправлено, довжина:', code.length);
" || { echo "❌ Помилка виправлення байткоду"; exit 1; }

echo "✅ Байткод готовий."

# -------------------- 4. ЗАПУСК JS-СКРИПТУ --------------------
echo "[4/7] Запуск деплою..."

node -e "
const fs = require('fs');
const ethers = require('ethers');

// Завантаження .env
const env = {};
const lines = fs.readFileSync('.env', 'utf8').split('\n');
for (const line of lines) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#')) continue;
  const [key, ...val] = trimmed.split('=');
  env[key.trim()] = val.join('=').trim();
}

const privateKey = env.HOT_PRIVATE_KEY.startsWith('0x') ? env.HOT_PRIVATE_KEY : '0x' + env.HOT_PRIVATE_KEY;
const rpc = env.BSC_RPC || 'https://bsc-dataseed.binance.org/';

// Визначаємо версію ethers
const isV6 = ethers.version.startsWith('6');

async function main() {
  // Провайдер і гаманець
  let provider, wallet;
  if (isV6) {
    provider = new ethers.JsonRpcProvider(rpc);
    wallet = new ethers.Wallet(privateKey, provider);
  } else {
    provider = new ethers.providers.JsonRpcProvider(rpc);
    wallet = new ethers.Wallet(privateKey, provider);
  }

  // Байткод
  let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
  if (!bytecode.startsWith('0x')) bytecode = '0x' + bytecode;

  // Отримуємо nonce та gasPrice
  let nonce, gasPrice;
  if (isV6) {
    nonce = await wallet.getNonce();
    const feeData = await provider.getFeeData();
    gasPrice = feeData.gasPrice || BigInt(5000000000);
    if (gasPrice < BigInt(5000000000)) gasPrice = BigInt(5000000000);
  } else {
    nonce = await wallet.getTransactionCount();
    gasPrice = await provider.getGasPrice();
    const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
    if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;
  }

  console.log('✅ nonce:', nonce);
  console.log('✅ gasPrice (Gwei):', isV6 ? Number(gasPrice) / 1e9 : ethers.utils.formatUnits(gasPrice, 'gwei'));

  // Формуємо транзакцію
  let tx;
  if (isV6) {
    tx = {
      data: bytecode,
      gasLimit: 3000000n,
      chainId: 56,
      nonce: nonce,
      gasPrice: gasPrice
    };
  } else {
    tx = {
      data: bytecode,
      gasLimit: ethers.utils.hexlify(3000000),
      chainId: ethers.utils.hexlify(56),
      nonce: ethers.utils.hexlify(nonce),
      gasPrice: ethers.utils.hexlify(gasPrice)
    };
  }

  // Підпис з повторними спробами
  let signedTx = null;
  let attempt = 0;
  const maxAttempts = 7;
  while (attempt < maxAttempts) {
    try {
      signedTx = await wallet.signTransaction(tx);
      console.log('✅ Підписано, довжина:', signedTx.length);
      break;
    } catch (e) {
      attempt++;
      console.error('❌ Спроба', attempt, 'не вдалася:', e.message);
      if (attempt < maxAttempts) {
        // Збільшуємо nonce на 1
        if (isV6) {
          tx.nonce = nonce + attempt;
        } else {
          tx.nonce = ethers.utils.hexlify(nonce + attempt);
        }
        console.log('⏳ nonce збільшено до', tx.nonce);
        await new Promise(r => setTimeout(r, 2000));
      } else {
        console.error('❌ Підпис не вдався після', maxAttempts, 'спроб.');
        process.exit(1);
      }
    }
  }

  // Зберігаємо signed.tx
  fs.writeFileSync('./wallet/runtime/signed.tx', signedTx);
  console.log('💾 signed.tx збережено');

  // Надсилання
  console.log('⏳ Надсилання транзакції...');
  let response;
  if (isV6) {
    response = await provider.broadcastTransaction(signedTx);
  } else {
    response = await provider.sendTransaction(signedTx);
  }
  console.log('✅ Хеш:', response.hash);
  fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);

  // Очікування підтвердження
  console.log('⏳ Очікуємо підтвердження...');
  let receipt = null;
  for (let i = 0; i < 30; i++) {
    if (isV6) {
      receipt = await provider.getTransactionReceipt(response.hash);
    } else {
      receipt = await provider.getTransactionReceipt(response.hash);
    }
    if (receipt) break;
    console.log('   Спроба', i+1, '/30');
    await new Promise(r => setTimeout(r, 5000));
  }
  if (!receipt) { console.error('❌ Тайм-аут'); process.exit(1); }
  if (receipt.status === 1) {
    console.log('✅ Адреса контракту:', receipt.contractAddress);
    fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
  } else {
    console.error('❌ Транзакція провалилась');
    process.exit(1);
  }
}

main().catch(err => {
  console.error('❌ КРИТИЧНА ПОМИЛКА:', err.message);
  console.error(err.stack);
  process.exit(1);
});
" || { echo "❌ Помилка виконання JS-скрипту"; exit 1; }

# -------------------- 5. ФІНАЛЬНИЙ ЗВІТ --------------------
echo ""
echo "============================================================"
echo "🎉 ДЕПЛОЙ УСПІШНО ЗАВЕРШЕНО!"
echo "============================================================"
if [ -f wallet/runtime/contract_address.txt ]; then
    echo "📌 Адреса контракту: $(cat wallet/runtime/contract_address.txt)"
fi
if [ -f wallet/runtime/deploy_hash.txt ]; then
    echo "📌 Хеш транзакції: $(cat wallet/runtime/deploy_hash.txt)"
fi
echo "============================================================"
