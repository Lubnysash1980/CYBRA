#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA SAFE DEPLOY — для слабких пристроїв та нестабільного інтернету
# ============================================================
set -euo pipefail
cd "$HOME/CYBRA"

LOG="logs/deploy_safe.log"
mkdir -p logs

log()   { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG"; }
error() { log "❌ ПОМИЛКА: $1"; exit 1; }
info()  { log "ℹ️  $1"; }
ok()    { log "✅ $1"; }
warn()  { log "⚠️  $1"; }

# ============================================================
# КОНФІГ
# ============================================================
MAX_RETRIES=5
RETRY_DELAY=8
TX_WAIT_POLL_INTERVAL=6

# ============================================================
# ПЕРЕВІРКА ЗАЛЕЖНОСТЕЙ
# ============================================================
info "Перевірка залежностей..."
command -v node >/dev/null 2>&1 || error "Node.js не встановлено"
node -e "require('ethers')" 2>/dev/null || {
    info "Встановлюємо ethers..."
    npm install ethers@5.7.2 --legacy-peer-deps || error "Не вдалося встановити ethers"
}
ok "Залежності в порядку."

# ============================================================
# ЗАВАНТАЖЕННЯ .env
# ============================================================
[ -f .env ] || error "Файл .env відсутній"
set -a; source .env; set +a
[ -n "${HOT_PRIVATE_KEY:-}" ] && [ "$HOT_PRIVATE_KEY" != "0x000...000" ] || error "HOT_PRIVATE_KEY не встановлено"

# ============================================================
# СТВОРЕННЯ pending_deploy.tx З RETRY ТА ПРАВИЛЬНИМ gasPrice
# ============================================================
info "Створення транзакції деплою..."

node -e "
const fs = require('fs');
const ethers = require('ethers');

const rpcList = [
    process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/',
    process.env.BSC_RPC2 || 'https://bsc-dataseed1.binance.org/'
];
const maxRetries = ${MAX_RETRIES};
const delay = ms => new Promise(r => setTimeout(r, ms));

async function getProvider() {
    for (const url of rpcList) {
        try {
            const provider = new ethers.providers.JsonRpcProvider(url);
            await provider.getBlockNumber();
            return provider;
        } catch { continue; }
    }
    throw new Error('Всі RPC недоступні');
}

async function withRetry(fn) {
    let lastErr;
    for (let i = 1; i <= maxRetries; i++) {
        try { return await fn(); } catch (err) {
            lastErr = err;
            console.warn(\`⚠️ Спроба \${i} не вдалася: \${err.message}\`);
            if (i < maxRetries) {
                const wait = ${RETRY_DELAY} * i;
                console.log(\`⏳ Пауза \${wait}с...\`);
                await delay(wait * 1000);
            }
        }
    }
    throw new Error(\`Помилка після \${maxRetries} спроб: \${lastErr?.message}\`);
}

(async () => {
    try {
        const provider = await getProvider();
        const wallet = new ethers.Wallet(process.env.HOT_PRIVATE_KEY, provider);

        let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
        if (!bytecode.startsWith('0x')) bytecode = '0x' + bytecode;

        const nonce = await withRetry(() => wallet.getTransactionCount());
        let gasPrice = await withRetry(() => provider.getGasPrice());

        // Мінімальна ціна 5 Gwei
        const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
        if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;

        const tx = {
            data: bytecode,
            gasLimit: 3000000,
            chainId: 56,
            nonce: nonce,
            gasPrice: gasPrice.toHexString()   // <--- ПРАВИЛЬНО: hex-рядок
        };

        fs.writeFileSync('./wallet/runtime/pending_deploy.tx', JSON.stringify(tx, null, 2));
        console.log('✅ pending_deploy.tx створено (nonce=' + nonce + ', gasPrice=' + ethers.utils.formatUnits(gasPrice, 'gwei') + ' Gwei)');
    } catch (err) {
        console.error('❌ Критична помилка:', err.message);
        process.exit(1);
    }
})();
" || error "Не вдалося створити pending_deploy.tx"

# Перевірка JSON
node -e "const tx=JSON.parse(require('fs').readFileSync('./wallet/runtime/pending_deploy.tx','utf8')); ['data','gasLimit','chainId','nonce','gasPrice'].forEach(f=>{if(!(f in tx)) throw new Error('Немає '+f);}); console.log('✅ pending_deploy.tx валідний');" || error "pending_deploy.tx некоректний"
ok "pending_deploy.tx створено та валідний."

# ============================================================
# ПІДПИС ТРАНЗАКЦІЇ
# ============================================================
info "Підпис транзакції..."
node -e "
const fs=require('fs');
const ethers=require('ethers');
const txData=JSON.parse(fs.readFileSync('./wallet/runtime/pending_deploy.tx','utf8'));
const wallet=new ethers.Wallet(process.env.HOT_PRIVATE_KEY);
wallet.signTransaction(txData).then(signed=>{
    fs.writeFileSync('./wallet/runtime/signed.tx', signed);
    console.log('✅ signed.tx створено');
});
" || error "Підпис не вдався"
[ -s wallet/runtime/signed.tx ] || error "signed.tx порожній"
ok "Підпис виконано."

# ============================================================
# НАДСИЛАННЯ ТРАНЗАКЦІЇ З RETRY
# ============================================================
info "Надсилання транзакції..."

node -e "
const fs = require('fs');
const ethers = require('ethers');

const rpcList = [
    process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/',
    process.env.BSC_RPC2 || 'https://bsc-dataseed1.binance.org/'
];
const maxRetries = ${MAX_RETRIES};
const retryDelay = ${RETRY_DELAY};
const pollInterval = ${TX_WAIT_POLL_INTERVAL};

async function getProvider() {
    for (const url of rpcList) {
        try {
            const provider = new ethers.providers.JsonRpcProvider(url);
            await provider.getBlockNumber();
            return provider;
        } catch { continue; }
    }
    throw new Error('Всі RPC недоступні');
}

function delay(ms) { return new Promise(r => setTimeout(r, ms)); }

async function withRetry(fn) {
    let lastErr;
    for (let i = 1; i <= maxRetries; i++) {
        try { return await fn(); } catch (err) {
            lastErr = err;
            console.warn(\`⚠️ Спроба \${i} не вдалася: \${err.message}\`);
            if (i < maxRetries) {
                const wait = retryDelay * i;
                console.log(\`⏳ Пауза \${wait}с...\`);
                await delay(wait * 1000);
            }
        }
    }
    throw new Error(\`Помилка після \${maxRetries} спроб: \${lastErr?.message}\`);
}

(async () => {
    try {
        const signed = fs.readFileSync('./wallet/runtime/signed.tx','utf8').trim();
        const provider = await getProvider();

        const tx = await withRetry(() => provider.sendTransaction(signed));
        console.log('✅ Хеш:', tx.hash);
        fs.writeFileSync('./wallet/runtime/deploy_hash.txt', tx.hash);

        console.log('⏳ Очікуємо підтвердження...');
        let receipt = null;
        for (let attempt = 1; attempt <= 20; attempt++) {
            receipt = await provider.getTransactionReceipt(tx.hash);
            if (receipt) break;
            console.log(\`⏳ Спроба \${attempt}: ще не підтверджено...\`);
            await delay(pollInterval * 1000);
        }
        if (!receipt) throw new Error('Тайм-аут очікування підтвердження');

        if (receipt.status === 1) {
            console.log('✅ Адреса контракту:', receipt.contractAddress);
            fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
        } else {
            throw new Error('Транзакція провалилась (status=0)');
        }
    } catch (err) {
        console.error('❌ Помилка:', err.message);
        process.exit(1);
    }
})();
" || error "Транзакція не надіслана або не підтверджена"

[ -s wallet/runtime/contract_address.txt ] || error "Адреса контракту не отримана"
CONTRACT_ADDR=$(cat wallet/runtime/contract_address.txt)
ok "Контракт розгорнуто за адресою: $CONTRACT_ADDR"

# ============================================================
# ФІНАЛЬНИЙ ЗВІТ
# ============================================================
log ""
log "============================================================"
log "🎉 ДЕПЛОЙ УСПІШНО ЗАВЕРШЕНО!"
log "============================================================"
log "📌 Адреса контракту: $CONTRACT_ADDR"
log "📌 Хеш транзакції: $(cat wallet/runtime/deploy_hash.txt)"
log "============================================================"
