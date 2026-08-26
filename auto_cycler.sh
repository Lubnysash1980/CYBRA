#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/CYBRA"

# ============================================================
# CYBRA AUTO CYCLER — ПОКРАЩЕНИЙ
# Холодний: 0x322f...  |  Гарячий: 0x29fA...
# ============================================================

# ---------- КОНФІГ ----------
COLD="0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F"
HOT="0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F"
LOGO_FILE="assets/logo_cid.txt"
STATE_DIR="runtime/cycler"
mkdir -p "$STATE_DIR"
TRIGGER_FILE="$STATE_DIR/trigger.lock"
LOG="logs/cycler.log"

# ---------- ФУНКЦІЇ ----------
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG"; }
info() { log "[INFO] $1"; }
warn() { log "[WARN] $1"; }
ok() { log "[OK] $1"; }
err() { log "[ERROR] $1"; }

# Перевірка балансу BNB
check_balance() {
    node -e "
    const ethers=require('ethers');
    const provider=new ethers.providers.JsonRpcProvider('https://bsc-dataseed.binance.org/');
    provider.getBalance('$1').then(b=>console.log(ethers.utils.formatEther(b)));
    " 2>/dev/null | tail -1
}

# Перевірка логотипу (CID)
check_logo() {
    [ -f "$LOGO_FILE" ] && cat "$LOGO_FILE" | tr -d '\n\r' || echo ""
}

# Перевірка наявності байткоду
check_bytecode() {
    if [ ! -f contracts/CybraToken.bin ] || [ ! -s contracts/CybraToken.bin ]; then
        return 1
    fi
    return 0
}

# Перевірка відповідності ABI (наявність setLogoURI)
check_abi() {
    if [ ! -f contracts/CybraToken.abi ] || [ ! -s contracts/CybraToken.abi ]; then
        return 1
    fi
    grep -q '"name":"setLogoURI"' contracts/CybraToken.abi 2>/dev/null
}

# ---------- СТАРТ ----------
info "🚀 СТАРТ ЦИКЛІЧНОГО ДЕПЛОЮ CYBRA"
touch "$STATE_DIR/state.txt"

# ----- 1. ПЕРЕВІРКА БАЙТКОДУ ТА ABI -----
info "[1/8] Перевірка байткоду та ABI..."
if ! check_bytecode; then
    err "❌ Байткод відсутній або порожній (contracts/CybraToken.bin)"
    err "   Створіть його або скомпілюйте контракт."
    exit 1
fi
if ! check_abi; then
    warn "⚠️  ABI не містить setLogoURI. Логотип не буде встановлено."
fi
ok "✅ Байткод та ABI присутні."

# ----- 2. ПЕРЕВІРКА ЛОГОТИПУ -----
info "[2/8] Перевірка логотипу..."
LOGO=$(check_logo)
if [ -z "$LOGO" ] || [ "$LOGO" = "QmPlaceholderLogoCID" ]; then
    warn "⚠️  Логотип відсутній або заглушка."
    warn "🛑 ПАУЗА. Додайте реальний CID у $LOGO_FILE"
    touch "$TRIGGER_FILE"
    while [ -f "$TRIGGER_FILE" ]; do
        sleep 10
        NEW_LOGO=$(check_logo)
        if [ -n "$NEW_LOGO" ] && [ "$NEW_LOGO" != "QmPlaceholderLogoCID" ]; then
            ok "✅ Логотип знайдено: $NEW_LOGO"
            rm -f "$TRIGGER_FILE"
            break
        fi
    done
else
    ok "✅ Логотип знайдено: $LOGO"
fi

# ----- 3. ПЕРЕВІРКА BNB НА ХОЛОДНОМУ -----
info "[3/8] Перевірка BNB на холодному ($COLD)..."
BNB=$(check_balance "$COLD")
info "❄️ BNB на cold: $BNB"
if (( $(echo "$BNB < 0.005" | bc -l) )); then
    warn "⚠️  НЕДОСТАТНЬО BNB ($BNB). Поповніть $COLD мінімум 0.01 BNB."
    warn "🛑 ПАУЗА. Після поповнення видаліть $TRIGGER_FILE"
    touch "$TRIGGER_FILE"
    while [ -f "$TRIGGER_FILE" ]; do
        sleep 10
        NEW_BNB=$(check_balance "$COLD")
        if (( $(echo "$NEW_BNB >= 0.01" | bc -l) )); then
            ok "✅ BNB з'явився. Продовжуємо."
            rm -f "$TRIGGER_FILE"
            break
        fi
    done
fi
ok "✅ BNB достатньо."

# ----- 4. ПЕРЕВІРКА, ЧИ ВЖЕ Є КОНТРАКТ -----
info "[4/8] Перевірка наявності контракту..."
if [ -f "wallet/runtime/contract_address.txt" ] && [ -s "wallet/runtime/contract_address.txt" ]; then
    ADDR=$(cat wallet/runtime/contract_address.txt)
    ok "✅ Контракт уже розгорнуто: $ADDR"
    CONTRACT_ADDR="$ADDR"
    # Переходимо до кроку 7 (переказ та ліквідність)
else
    # ----- 5. СТВОРЕННЯ ТРАНЗАКЦІЇ ДЕПЛОЮ -----
    info "[5/8] Створення транзакції деплою..."
    if [ ! -f "wallet/runtime/pending_deploy.tx" ] || [ ! -s "wallet/runtime/pending_deploy.tx" ]; then
        info "📝 Створюємо pending_deploy.tx..."
        node create_tx.js 2>/dev/null || {
            info "📝 Створюємо create_tx.js..."
            cat > create_tx.js <<'EOC'
const fs = require('fs');
const ethers = require('ethers');
const bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
const clean = bytecode.startsWith('0x') ? bytecode : '0x' + bytecode;
const tx = { data: clean, gasLimit: 2000000, chainId: 56 };
fs.writeFileSync('./wallet/runtime/pending_deploy.tx', JSON.stringify(tx, null, 2));
console.log('✅ pending_deploy.tx створено');
EOC
            node create_tx.js
        }
    fi
    ok "✅ pending_deploy.tx створено."

    # Відображення очікуваної суми газу
    GAS_LIMIT=$(node -e "const fs=require('fs'); const tx=JSON.parse(fs.readFileSync('./wallet/runtime/pending_deploy.tx','utf8')); console.log(tx.gasLimit);")
    GAS_PRICE_GWEI=$(node -e "const fs=require('fs'); const tx=JSON.parse(fs.readFileSync('./wallet/runtime/pending_deploy.tx','utf8')); console.log(tx.gasPrice ? ethers.utils.formatUnits(tx.gasPrice, 'gwei') : '5');")
    info "⛽️ Ліміт газу: $GAS_LIMIT, ціна газу: ${GAS_PRICE_GWEI} Gwei"
    info "💸 Очікувана сума газу: ~0.003–0.005 BNB"

    # Експорт JSON для підпису
    node -e "
    const fs=require('fs');
    const tx=JSON.parse(fs.readFileSync('./wallet/runtime/pending_deploy.tx','utf8'));
    fs.writeFileSync('./wallet/runtime/pending_deploy.tx.json', JSON.stringify(tx, null, 2));
    console.log('✅ pending_deploy.tx.json створено');
    "

    # ----- 6. ОЧІКУВАННЯ ПІДПИСУ -----
    info "[6/8] Очікування холодного підпису..."
    if [ ! -f "wallet/runtime/signed.tx" ] || [ ! -s "wallet/runtime/signed.tx" ]; then
        warn "✍️  Потрібен підпис. Збережіть signed.tx у wallet/runtime/"
        warn "🛑 ПАУЗА. Очікую на wallet/runtime/signed.tx"
        touch "$TRIGGER_FILE"
        while [ -f "$TRIGGER_FILE" ]; do
            sleep 10
            if [ -f "wallet/runtime/signed.tx" ] && [ -s "wallet/runtime/signed.tx" ]; then
                ok "✅ signed.tx знайдено."
                rm -f "$TRIGGER_FILE"
                break
            fi
        done
    fi

    # ----- 7. НАДСИЛАННЯ ДЕПЛОЮ -----
    info "[7/8] Надсилання транзакції деплою..."
    node -e "
    const fs=require('fs');
    const ethers=require('ethers');
    const signed=fs.readFileSync('./wallet/runtime/signed.tx','utf8').trim();
    const provider=new ethers.providers.JsonRpcProvider('https://bsc-dataseed.binance.org/');
    provider.sendTransaction(signed).then(tx=>{
        console.log('✅ Хеш:', tx.hash);
        fs.writeFileSync('./wallet/runtime/deploy_hash.txt', tx.hash);
        return tx.wait();
    }).then(receipt=>{
        console.log('✅ Адреса:', receipt.contractAddress);
        fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
    }).catch(e=>{
        console.error('❌ Помилка:', e.message);
        process.exit(1);
    });
    "

    if [ ! -f "wallet/runtime/contract_address.txt" ]; then
        err "❌ Деплой не вдався. Перевірте логи."
        err "🛑 ПАУЗА. Виправте помилку та продовжте."
        touch "$TRIGGER_FILE"
        while [ -f "$TRIGGER_FILE" ]; do sleep 10; done
        exit 1
    fi

    CONTRACT_ADDR=$(cat wallet/runtime/contract_address.txt)
    ok "✅ Контракт розгорнуто: $CONTRACT_ADDR"

    # ----- 8. ВСТАНОВЛЕННЯ ЛОГОТИПУ (підпис холодним) -----
    LOGO_CID=$(check_logo)
    if [ -n "$LOGO_CID" ] && [ "$LOGO_CID" != "QmPlaceholderLogoCID" ]; then
        info "[8/8] Встановлення логотипу (підпис холодним)..."
        node -e "
        const fs=require('fs');
        const ethers=require('ethers');
        const contractAddr = fs.readFileSync('./wallet/runtime/contract_address.txt','utf8').trim();
        const abi = JSON.parse(fs.readFileSync('./contracts/CybraToken.abi','utf8'));
        const iface = new ethers.utils.Interface(abi);
        const data = iface.encodeFunctionData('setLogoURI', ['ipfs://$LOGO_CID']);
        const tx = {
            to: contractAddr,
            data: data,
            gasLimit: 100000,
            chainId: 56,
            gasPrice: ethers.utils.parseUnits('5', 'gwei')
        };
        fs.writeFileSync('./wallet/runtime/pending_logo.tx', JSON.stringify(tx, null, 2));
        console.log('✅ pending_logo.tx створено');
        "
        warn "✍️  Підпишіть pending_logo.tx холодним і збережіть як wallet/runtime/signed_logo.tx"
        warn "🛑 ПАУЗА. Очікую на signed_logo.tx"
        touch "$TRIGGER_FILE"
        while [ -f "$TRIGGER_FILE" ]; do
            sleep 10
            if [ -f "wallet/runtime/signed_logo.tx" ] && [ -s "wallet/runtime/signed_logo.tx" ]; then
                ok "✅ signed_logo.tx знайдено. Надсилаємо..."
                rm -f "$TRIGGER_FILE"
                break
            fi
        done
        node -e "
        const fs=require('fs');
        const ethers=require('ethers');
        const signed=fs.readFileSync('./wallet/runtime/signed_logo.tx','utf8').trim();
        const provider=new ethers.providers.JsonRpcProvider('https://bsc-dataseed.binance.org/');
        provider.sendTransaction(signed).then(tx=>tx.wait()).then(()=>console.log('✅ Логотип встановлено'));
        "
    fi
fi

# ============================================================
# ПЕРЕКАЗ 1000 CYBRA НА ГАРЯЧИЙ ТА ДОДАВАННЯ ЛІКВІДНОСТІ
# ============================================================

CONTRACT_ADDR=$(cat wallet/runtime/contract_address.txt)

# ----- A. ПЕРЕКАЗ 1000 CYBRA НА ГАРЯЧИЙ -----
info "[A] Переказ 1000 CYBRA на гарячий ($HOT)..."
if [ ! -f "wallet/make_transfer_tx.js" ]; then
    cat > wallet/make_transfer_tx.js <<'EOC'
const fs = require('fs');
const ethers = require('ethers');
const contractAddr = fs.readFileSync('./wallet/runtime/contract_address.txt', 'utf8').trim();
const abi = JSON.parse(fs.readFileSync('./contracts/CybraToken.abi', 'utf8'));
const iface = new ethers.utils.Interface(abi);
const hotAddr = '0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F';
const amount = ethers.utils.parseUnits('1000', 18);
const data = iface.encodeFunctionData('transfer', [hotAddr, amount]);
const tx = { to: contractAddr, data: data, gasLimit: 100000, chainId: 56, gasPrice: ethers.utils.parseUnits('5', 'gwei') };
fs.writeFileSync('./wallet/runtime/pending_transfer.tx', JSON.stringify(tx, null, 2));
console.log('✅ pending_transfer.tx створено');
EOC
fi
node wallet/make_transfer_tx.js

# Відображення очікуваної суми переказу
info "💸 Очікувана сума газу для переказу: ~0.0005–0.001 BNB"

warn "✍️  Підпишіть pending_transfer.tx холодним і збережіть як wallet/runtime/signed_transfer.tx"
warn "🛑 ПАУЗА. Очікую на signed_transfer.tx"
touch "$TRIGGER_FILE"
while [ -f "$TRIGGER_FILE" ]; do
    sleep 10
    if [ -f "wallet/runtime/signed_transfer.tx" ] && [ -s "wallet/runtime/signed_transfer.tx" ]; then
        ok "✅ signed_transfer.tx знайдено. Надсилаємо переказ..."
        rm -f "$TRIGGER_FILE"
        break
    fi
done

node -e "
const fs=require('fs');
const ethers=require('ethers');
const signed=fs.readFileSync('./wallet/runtime/signed_transfer.tx','utf8').trim();
const provider=new ethers.providers.JsonRpcProvider('https://bsc-dataseed.binance.org/');
provider.sendTransaction(signed).then(tx=>{
    console.log('✅ Переказ надіслано! Хеш:', tx.hash);
    return tx.wait();
}).then(()=>console.log('✅ Переказ підтверджено')).catch(e=>console.error('❌ Помилка:', e.message));
"

# ----- B. ДОДАВАННЯ ЛІКВІДНОСТІ (1000 CYBRA + 0.016 BNB) -----
info "[B] Додавання ліквідності на PancakeSwap (1000 CYBRA + 0.016 BNB ≈ $5)..."
TOKEN_AMOUNT="1000000000000000000000"   # 1000 * 10^18
BNB_AMOUNT="16000000000000000"          # 0.016 BNB

# Створення транзакцій approve + addLiquidityETH
node -e "
const fs=require('fs');
const ethers=require('ethers');
const contractAddr = '$CONTRACT_ADDR';
const routerAddr = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
const abiToken = JSON.parse(fs.readFileSync('./contracts/CybraToken.abi','utf8'));
const ifaceToken = new ethers.utils.Interface(abiToken);
const approveData = ifaceToken.encodeFunctionData('approve', [routerAddr, '$TOKEN_AMOUNT']);
const approveTx = {
    to: contractAddr,
    data: approveData,
    gasLimit: 100000,
    chainId: 56,
    gasPrice: ethers.utils.parseUnits('5', 'gwei')
};
fs.writeFileSync('./wallet/runtime/pending_approve.tx', JSON.stringify(approveTx, null, 2));

const routerAbi = ['function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity)'];
const ifaceRouter = new ethers.utils.Interface(routerAbi);
const deadline = Math.floor(Date.now() / 1000) + 60 * 20;
const liquidityData = ifaceRouter.encodeFunctionData('addLiquidityETH', [contractAddr, '$TOKEN_AMOUNT', 0, 0, '$HOT', deadline]);
const liquidityTx = {
    to: routerAddr,
    data: liquidityData,
    value: '$BNB_AMOUNT',
    gasLimit: 300000,
    chainId: 56,
    gasPrice: ethers.utils.parseUnits('5', 'gwei')
};
fs.writeFileSync('./wallet/runtime/pending_liquidity.tx', JSON.stringify(liquidityTx, null, 2));
console.log('✅ pending_approve.tx та pending_liquidity.tx створено');
"

info "💸 Очікувана сума газу для approve: ~0.0005 BNB"
info "💸 Очікувана сума газу для addLiquidity: ~0.002 BNB"
info "🔒 Очікувана сума BNB для блокування в пулі: 0.016 BNB"

warn "✍️  Підпишіть pending_approve.tx холодним і збережіть як wallet/runtime/signed_approve.tx"
touch "$TRIGGER_FILE"
while [ -f "$TRIGGER_FILE" ]; do
    sleep 10
    if [ -f "wallet/runtime/signed_approve.tx" ] && [ -s "wallet/runtime/signed_approve.tx" ]; then
        ok "✅ signed_approve.tx знайдено. Надсилаємо approve..."
        rm -f "$TRIGGER_FILE"
        break
    fi
done
node -e "
const fs=require('fs');
const ethers=require('ethers');
const signed=fs.readFileSync('./wallet/runtime/signed_approve.tx','utf8').trim();
const provider=new ethers.providers.JsonRpcProvider('https://bsc-dataseed.binance.org/');
provider.sendTransaction(signed).then(tx=>tx.wait()).then(()=>console.log('✅ Approve підтверджено')).catch(e=>console.error('❌ Помилка:', e.message));
"

warn "✍️  Підпишіть pending_liquidity.tx холодним і збережіть як wallet/runtime/signed_liquidity.tx"
touch "$TRIGGER_FILE"
while [ -f "$TRIGGER_FILE" ]; do
    sleep 10
    if [ -f "wallet/runtime/signed_liquidity.tx" ] && [ -s "wallet/runtime/signed_liquidity.tx" ]; then
        ok "✅ signed_liquidity.tx знайдено. Надсилаємо додавання ліквідності..."
        rm -f "$TRIGGER_FILE"
        break
    fi
done
node -e "
const fs=require('fs');
const ethers=require('ethers');
const signed=fs.readFileSync('./wallet/runtime/signed_liquidity.tx','utf8').trim();
const provider=new ethers.providers.JsonRpcProvider('https://bsc-dataseed.binance.org/');
provider.sendTransaction(signed).then(tx=>{
    console.log('✅ Ліквідність додано! Хеш:', tx.hash);
    return tx.wait();
}).then(()=>console.log('✅ Підтверджено')).catch(e=>console.error('❌ Помилка:', e.message));
"

# ============================================================
# ФІНАЛЬНИЙ ЗВІТ
# ============================================================
log ""
log "============================================================"
log "🎉 ВСЕ ЗАВЕРШЕНО!"
log "============================================================"
log "📌 Адреса контракту: $CONTRACT_ADDR"
log "📌 Хеш деплою: $(cat wallet/runtime/deploy_hash.txt 2>/dev/null || echo 'немає')"
log "📌 Ліквідність: 1000 CYBRA + 0.016 BNB (~$5)"
log ""
log "📋 ПОДАЛЬШІ КРОКИ:"
log "1. Додайте токен у холодний гаманець (Ledger) за адресою:"
log "   $CONTRACT_ADDR"
log "2. Перевірте пул на PancakeSwap:"
log "   https://pancakeswap.finance/info/tokens/$CONTRACT_ADDR"
log "3. Торгуйте через Jupiter (автоматично підхопить адресу)."
log "4. Заявіть токен на:"
log "   - BscScan: https://bscscan.com/token/$CONTRACT_ADDR"
log "   - CoinGecko: https://www.coingecko.com/account/submit-token"
log "   - CoinMarketCap: https://coinmarketcap.com/request-form/"
log "============================================================"
log "🏁 Скрипт завершено."
