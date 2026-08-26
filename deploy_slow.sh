#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/CYBRA"

LOG="logs/deploy_slow.log"
mkdir -p logs

log()   { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG"; }
error() { log "❌ ПОМИЛКА: $1"; exit 1; }
info()  { log "ℹ️  $1"; }
ok()    { log "✅ $1"; }

# ============================================================
# ЗАВАНТАЖЕННЯ .env
# ============================================================
[ -f .env ] || error "Файл .env відсутній"
set -a; source .env; set +a
[ -n "${HOT_PRIVATE_KEY:-}" ] && [ "$HOT_PRIVATE_KEY" != "0x000...000" ] || error "HOT_PRIVATE_KEY не встановлено"

# ============================================================
# СТВОРЕННЯ pending_deploy.tx З RETRY ТА ЗАТРИМКАМИ
# ============================================================
info "Створення транзакції (з уповільненням для Android)..."

node -e "
const fs = require('fs');
const ethers = require('ethers');

const delay = ms => new Promise(r => setTimeout(r, ms));
const rpcList = [
    process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/',
    process.env.BSC_RPC2 || 'https://bsc-dataseed1.binance.org/'
];

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

async function withRetry(fn, label, maxRetries = 5) {
    let lastErr;
    for (let i = 1; i <= maxRetries; i++) {
        try {
            return await fn();
        } catch (err) {
            lastErr = err;
            console.warn(\`⚠️ \${label}: спроба \${i} не вдалася: \${err.message}\`);
            if (i < maxRetries) {
                const wait = 3000 * i;
                console.log(\`⏳ Пауза \${wait}мс...\`);
                await delay(wait);
            }
        }
    }
    throw new Error(\`\${label}: не вдалося після \${maxRetries} спроб: \${lastErr?.message}\`);
}

(async () => {
    try {
        const provider = await getProvider();
        const wallet = new ethers.Wallet(process.env.HOT_PRIVATE_KEY, provider);

        const nonce = await withRetry(() => wallet.getTransactionCount(), 'nonce');
        console.log(\`✅ nonce отримано: \${nonce}\`);

        let gasPrice = await withRetry(() => provider.getGasPrice(), 'gasPrice');
        const minGasPrice = ethers.utils.parseUnits('5', 'gwei');
        if (gasPrice.lt(minGasPrice)) gasPrice = minGasPrice;
        console.log(\`✅ gasPrice: \${ethers.utils.formatUnits(gasPrice, 'gwei')} Gwei\`);

        let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
        if (!bytecode.startsWith('0x')) bytecode = '0x' + bytecode;

        const tx = {
            data: bytecode,
            gasLimit: 3000000,
            chainId: 56,
            nonce: nonce,
            gasPrice: gasPrice.toHexString()
        };

        fs.writeFileSync('./wallet/runtime/pending_deploy.tx', JSON.stringify(tx, null, 2));
        console.log('✅ pending_deploy.tx записано');
        await delay(1500);
        JSON.parse(fs.readFileSync('./wallet/runtime/pending_deploy.tx', 'utf8'));
        console.log('✅ pending_deploy.tx пройшов перевірку');
    } catch (err) {
        console.error('❌ Критична помилка:', err.message);
        process.exit(1);
    }
})();
" || error "Не вдалося створити pending_deploy.tx"

ok "pending_deploy.tx створено та валідний."

# ============================================================
# ПІДПИС
# ============================================================
info "Підпис транзакції..."
sleep 2
node -e "
const fs=require('fs');
const ethers=require('ethers');
setTimeout(() => {
    try {
        const txData = JSON.parse(fs.readFileSync('./wallet/runtime/pending_deploy.tx','utf8'));
        const wallet = new ethers.Wallet(process.env.HOT_PRIVATE_KEY);
        wallet.signTransaction(txData).then(signed => {
            fs.writeFileSync('./wallet/runtime/signed.tx', signed);
            console.log('✅ signed.tx створено');
        }).catch(err => { console.error('❌ Помилка підпису:', err.message); process.exit(1); });
    } catch(err) { console.error('❌ Помилка читання:', err.message); process.exit(1); }
}, 1000);
" || error "Підпис не вдався"

sleep 2
[ -s wallet/runtime/signed.tx ] || error "signed.tx порожній"
ok "Підпис виконано."

# ============================================================
# НАДСИЛАННЯ
# ============================================================
info "Надсилання транзакції..."
node -e "
const fs = require('fs');
const ethers = require('ethers');

const delay = ms => new Promise(r => setTimeout(r, ms));
const rpcList = [
    process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/',
    process.env.BSC_RPC2 || 'https://bsc-dataseed1.binance.org/'
];

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

async function withRetry(fn, maxRetries = 5) {
    let lastErr;
    for (let i = 1; i <= maxRetries; i++) {
        try { return await fn(); } catch (err) {
            lastErr = err;
            console.warn(\`⚠️ Спроба \${i} не вдалася: \${err.message}\`);
            if (i < maxRetries) {
                const wait = 3000 * i;
                await delay(wait);
            }
        }
    }
    throw new Error(\`Помилка після \${maxRetries} спроб: \${lastErr?.message}\`);
}

(async () => {
    try {
        await delay(1000);
        const signed = fs.readFileSync('./wallet/runtime/signed.tx','utf8').trim();
        const provider = await getProvider();
        const tx = await withRetry(() => provider.sendTransaction(signed));
        console.log('✅ Хеш:', tx.hash);
        fs.writeFileSync('./wallet/runtime/deploy_hash.txt', tx.hash);

        console.log('⏳ Очікуємо підтвердження...');
        let receipt = null;
        for (let attempt = 1; attempt <= 30; attempt++) {
            receipt = await provider.getTransactionReceipt(tx.hash);
            if (receipt) break;
            console.log(\`⏳ Спроба \${attempt}: ще не підтверджено...\`);
            await delay(5000);
        }
        if (!receipt) throw new Error('Тайм-аут');
        if (receipt.status === 1) {
            console.log('✅ Адреса контракту:', receipt.contractAddress);
            fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
        } else throw new Error('Транзакція провалилась (status=0)');
    } catch (err) {
        console.error('❌ Помилка:', err.message);
        process.exit(1);
    }
})();
" || error "Транзакція не надіслана"

[ -s wallet/runtime/contract_address.txt ] || error "Адреса контракту не отримана"
CONTRACT_ADDR=$(cat wallet/runtime/contract_address.txt)
ok "Контракт розгорнуто за адресою: $CONTRACT_ADDR"

# ============================================================
# ФІНАЛ
# ============================================================
log ""
log "============================================================"
log "🎉 ДЕПЛОЙ УСПІШНО ЗАВЕРШЕНО!"
log "============================================================"
log "📌 Адреса контракту: $CONTRACT_ADDR"
log "📌 Хеш транзакції: $(cat wallet/runtime/deploy_hash.txt)"
log "============================================================"
