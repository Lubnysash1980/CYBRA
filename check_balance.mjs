import crypto from 'crypto';
import fetch from 'node-fetch';
import fs from 'fs';

const keys = JSON.parse(fs.readFileSync('.cybra_local_secret/exchanges/bybit_live.json', 'utf8'));
const API_KEY = keys.api_key;
const API_SECRET = keys.api_secret;

function sign(params) {
    const ts = Date.now().toString();
    const qs = new URLSearchParams(params).toString();
    const sig = crypto.createHmac('sha256', API_SECRET).update(ts + API_KEY + '5000' + qs).digest('hex');
    return { ts, sig };
}

async function checkBalance(accountType) {
    const params = { accountType: accountType, coin: 'USDT' };
    const { ts, sig } = sign(params);
    const url = `https://api.bybit.com/v5/account/wallet-balance?${new URLSearchParams(params)}`;
    const res = await fetch(url, {
        headers: {
            'X-BAPI-API-KEY': API_KEY,
            'X-BAPI-TIMESTAMP': ts,
            'X-BAPI-SIGN': sig,
            'X-BAPI-RECV-WINDOW': '5000'
        }
    });
    const data = await res.json();
    if (data.retCode === 0 && data.result.list[0]?.coin) {
        const usdt = data.result.list[0].coin.find(c => c.coin === 'USDT');
        console.log(`   ${accountType}: ${usdt?.walletBalance || 0} USDT`);
        return parseFloat(usdt?.walletBalance || 0);
    }
    console.log(`   ${accountType}: помилка або 0`);
    return 0;
}

console.log("🔍 ПЕРЕВІРКА ВСІХ ТИПІВ РАХУНКІВ:");
console.log("══════════════════════════════════════");

await checkBalance("UNIFIED");
await checkBalance("DERIVATIVES");
await checkBalance("SPOT");
await checkBalance("FUND");

console.log("");
console.log("💡 Якщо всі 0 — кошти в іншій монеті або не на ф'ючерсах");
