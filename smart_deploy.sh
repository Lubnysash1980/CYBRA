#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/CYBRA"

LOG="logs/smart_deploy.log"
mkdir -p logs

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG"; }
error() { log "❌ ПОМИЛКА: $1"; exit 1; }
info() { log "ℹ️  $1"; }
ok() { log "✅ $1"; }

# ============================================================
# 1. ВИДАЛЕННЯ СТАРИХ ДАНИХ
# ============================================================
info "Очищення старих артефактів..."
rm -f wallet/runtime/signed.tx \
      wallet/runtime/contract_address.txt \
      wallet/runtime/deploy_hash.txt \
      wallet/runtime/pending_deploy.tx.json \
      wallet/runtime/signed_transfer.tx \
      wallet/runtime/pending_transfer.tx

ok "Старі файли видалено."

# ============================================================
# 2. ПЕРЕВІРКА ЗАЛЕЖНОСТЕЙ
# ============================================================
info "Перевірка залежностей..."

command -v node >/dev/null 2>&1 || error "Node.js не встановлено"
command -v npm >/dev/null 2>&1 || error "npm не встановлено"
command -v bc >/dev/null 2>&1 || error "bc не встановлено (pkg install bc)"

node -e "require('ethers')" 2>/dev/null || {
    info "Встановлюємо ethers..."
    npm install ethers@5.7.2 --legacy-peer-deps || error "Не вдалося встановити ethers"
}
ok "Залежності в порядку."

# ============================================================
# 3. ПЕРЕВІРКА БАЙТКОДУ ТА ABI
# ============================================================
info "Перевірка байткоду та ABI..."

if [ ! -f contracts/CybraToken.bin ] || [ ! -s contracts/CybraToken.bin ]; then
    error "Файл contracts/CybraToken.bin відсутній або порожній"
fi
if [ ! -f contracts/CybraToken.abi ] || [ ! -s contracts/CybraToken.abi ]; then
    error "Файл contracts/CybraToken.abi відсутній або порожній"
fi

# Перевірка, чи байткод починається правильно
BYTECODE_START=$(head -c 10 contracts/CybraToken.bin)
if [[ "$BYTECODE_START" != "0x60806040"* ]]; then
    error "Неправильний байткод (має починатися з 0x60806040). Можливо, файл пошкоджено."
fi
ok "Байткод та ABI валідні."

# ============================================================
# 4. ПЕРЕВІРКА ЛОГОТИПУ
# ============================================================
info "Перевірка логотипу..."
if [ ! -f assets/logo_cid.txt ] || [ ! -s assets/logo_cid.txt ]; then
    warn "Логотип відсутній. Створюємо заглушку..."
    mkdir -p assets
    echo "QmPlaceholderLogoCID" > assets/logo_cid.txt
else
    LOGO_CID=$(cat assets/logo_cid.txt | tr -d '\r\n')
    if [ "$LOGO_CID" = "QmPlaceholderLogoCID" ]; then
        warn "Логотип — заглушка. Замініть на реальний CID пізніше."
    else
        ok "Логотип знайдено: $LOGO_CID"
    fi
fi

# ============================================================
# 5. ПЕРЕВІРКА .env ТА HOT_PRIVATE_KEY
# ============================================================
info "Перевірка конфігурації .env..."
if [ ! -f .env ]; then
    error "Файл .env відсутній. Створіть його з HOT_PRIVATE_KEY."
fi

source .env 2>/dev/null || error "Не вдалося завантажити .env"
if [ -z "${HOT_PRIVATE_KEY:-}" ] || [ "$HOT_PRIVATE_KEY" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    error "HOT_PRIVATE_KEY не встановлено або використовується заглушка. Додайте реальний ключ у .env"
fi
ok "HOT_PRIVATE_KEY присутній."

# ============================================================
# 6. ПЕРЕВІРКА БАЛАНСУ BNB НА ГАРЯЧОМУ
# ============================================================
HOT_ADDR="${HOT_ADDRESS:-0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F}"
info "Перевірка BNB на гарячому ($HOT_ADDR)..."

BNB_BALANCE=$(node -e "
const ethers=require('ethers');
const provider=new ethers.providers.JsonRpcProvider(process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/');
provider.getBalance('$HOT_ADDR').then(b=>console.log(ethers.utils.formatEther(b)));
" 2>/dev/null | tail -1)

if [ -z "$BNB_BALANCE" ] || (( $(echo "$BNB_BALANCE < 0.005" | bc -l) )); then
    error "На гарячому гаманці недостатньо BNB ($BNB_BALANCE). Поповніть мінімум 0.005 BNB."
fi
ok "BNB достатньо: $BNB_BALANCE"

# ============================================================
# 7. СТВОРЕННЯ СВІЖОГО pending_deploy.tx
# ============================================================
info "Створення транзакції деплою..."

if [ ! -f create_tx.js ] || [ ! -s create_tx.js ]; then
    cat > create_tx.js <<'EOC'
const fs = require('fs');
const ethers = require('ethers');
const bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
const clean = bytecode.startsWith('0x') ? bytecode : '0x' + bytecode;
const tx = { data: clean, gasLimit: 2000000, chainId: 56 };
fs.writeFileSync('./wallet/runtime/pending_deploy.tx', JSON.stringify(tx, null, 2));
console.log('✅ pending_deploy.tx створено');
EOC
fi

node create_tx.js || error "Не вдалося створити pending_deploy.tx"
if [ ! -s wallet/runtime/pending_deploy.tx ]; then
    error "pending_deploy.tx порожній або не створено"
fi

# Перевірка JSON
node -e "JSON.parse(require('fs').readFileSync('./wallet/runtime/pending_deploy.tx','utf8'))" || error "pending_deploy.tx містить некоректний JSON"
ok "pending_deploy.tx створено та валідний."

# ============================================================
# 8. ПІДПИС ГАРЯЧИМ КЛЮЧЕМ
# ============================================================
info "Підпис транзакції гарячим гаманцем..."

node -e "
const fs=require('fs');
const ethers=require('ethers');
require('dotenv').config();
const txData=JSON.parse(fs.readFileSync('./wallet/runtime/pending_deploy.tx','utf8'));
const wallet=new ethers.Wallet(process.env.HOT_PRIVATE_KEY);
wallet.signTransaction(txData).then(signed=>{
    fs.writeFileSync('./wallet/runtime/signed.tx', signed);
    console.log('✅ signed.tx створено (довжина: '+signed.length+' символів)');
}).catch(e=>{
    console.error('Помилка підпису:', e.message);
    process.exit(1);
});
" || error "Не вдалося підписати транзакцію"

if [ ! -s wallet/runtime/signed.tx ]; then
    error "signed.tx порожній або не створено"
fi

# Перевірка довжини (має бути > 200)
SIGNED_LEN=$(wc -c < wallet/runtime/signed.tx)
if [ "$SIGNED_LEN" -lt 200 ]; then
    error "signed.tx занадто короткий ($SIGNED_LEN символів). Підпис некоректний."
fi
ok "signed.tx створено (довжина: $SIGNED_LEN символів)"

# ============================================================
# 9. НАДСИЛАННЯ ТРАНЗАКЦІЇ
# ============================================================
info "Надсилання транзакції деплою..."

node -e "
const fs=require('fs');
const ethers=require('ethers');
require('dotenv').config();
const signed=fs.readFileSync('./wallet/runtime/signed.tx','utf8').trim();
const provider=new ethers.providers.JsonRpcProvider(process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/');
provider.sendTransaction(signed).then(tx=>{
    console.log('✅ Хеш:', tx.hash);
    fs.writeFileSync('./wallet/runtime/deploy_hash.txt', tx.hash);
    return tx.wait();
}).then(receipt=>{
    console.log('✅ Адреса контракту:', receipt.contractAddress);
    fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
}).catch(e=>{
    console.error('❌ Помилка надсилання:', e.message);
    process.exit(1);
});
" || error "Транзакція не надіслана"

if [ ! -s wallet/runtime/contract_address.txt ]; then
    error "Адреса контракту не отримана. Можливо, транзакція не підтверджена."
fi

CONTRACT_ADDR=$(cat wallet/runtime/contract_address.txt)
ok "Контракт розгорнуто за адресою: $CONTRACT_ADDR"

# ============================================================
# 10. ВСТАНОВЛЕННЯ ЛОГОТИПУ (якщо є реальний CID)
# ============================================================
LOGO_CID=$(cat assets/logo_cid.txt | tr -d '\r\n')
if [ -n "$LOGO_CID" ] && [ "$LOGO_CID" != "QmPlaceholderLogoCID" ]; then
    info "Встановлення логотипу..."
    node -e "
    const fs=require('fs');
    const ethers=require('ethers');
    require('dotenv').config();
    const provider=new ethers.providers.JsonRpcProvider(process.env.BSC_RPC);
    const wallet=new ethers.Wallet(process.env.HOT_PRIVATE_KEY, provider);
    const abi=JSON.parse(fs.readFileSync('./contracts/CybraToken.abi','utf8'));
    const contract=new ethers.Contract('$CONTRACT_ADDR', abi, wallet);
    contract.setLogoURI('ipfs://$LOGO_CID').then(tx=>tx.wait()).then(()=>console.log('✅ Логотип встановлено'));
    " || warn "Не вдалося встановити логотип (можливо, контракт не має setLogoURI)"
else
    info "Логотип не встановлено (заглушка або відсутній CID)"
fi

# ============================================================
# 11. ФІНАЛЬНИЙ ЗВІТ
# ============================================================
log ""
log "============================================================"
log "🎉 ДЕПЛОЙ УСПІШНО ЗАВЕРШЕНО!"
log "============================================================"
log "📌 Адреса контракту: $CONTRACT_ADDR"
log "📌 Хеш транзакції: $(cat wallet/runtime/deploy_hash.txt)"
log "📌 Гарячий гаманець: $HOT_ADDR"
log ""
log "📋 ПОДАЛЬШІ КРОКИ:"
log "1. Додайте токен у MetaMask за адресою:"
log "   $CONTRACT_ADDR"
log "2. Перевірте пул на PancakeSwap:"
log "   https://pancakeswap.finance/info/tokens/$CONTRACT_ADDR"
log "3. Якщо ви хочете переказати токени на холодний гаманець, виконайте:"
log "   node transfer_to_cold.js (потрібно створити)"
log "4. Подайте заявку на BscScan, CoinGecko, CoinMarketCap."
log "============================================================"
