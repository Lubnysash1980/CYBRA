import fetch from 'node-fetch';
import crypto from 'crypto';
import fs from 'fs';

const CONFIG = {
    symbol: 'BTCUSDT',
    qty: 0.001,
    longEntry: 63000,
    shortEntry: 64500
};

let API_KEY, API_SECRET;
try {
    const keys = JSON.parse(fs.readFileSync('.cybra_local_secret/exchanges/bybit_live.json', 'utf8'));
    API_KEY = keys.api_key;
    API_SECRET = keys.api_secret;
    console.log("✅ API KEYS LOADED");
} catch(e) {
    console.log("❌ API KEYS NOT FOUND");
    process.exit(1);
}

function signRequest(params) {
    const timestamp = Date.now().toString();
    const queryString = new URLSearchParams(params).toString();
    const signature = crypto.createHmac('sha256', API_SECRET)
        .update(timestamp + API_KEY + '5000' + queryString)
        .digest('hex');
    return { timestamp, signature };
}

async function getPrice() {
    const res = await fetch(`https://api.bybit.com/v5/market/tickers?category=linear&symbol=${CONFIG.symbol}`);
    const data = await res.json();
    return parseFloat(data.result.list[0].lastPrice);
}

async function getBalance() {
    const params = { accountType: 'UNIFIED', coin: 'USDT' };
    const { timestamp, signature } = signRequest(params);
    const res = await fetch(`https://api.bybit.com/v5/account/wallet-balance?${new URLSearchParams(params)}`, {
        headers: {
            'X-BAPI-API-KEY': API_KEY,
            'X-BAPI-TIMESTAMP': timestamp,
            'X-BAPI-SIGN': signature,
            'X-BAPI-RECV-WINDOW': '5000'
        }
    });
    const data = await res.json();
    if (data.retCode === 0 && data.result.list[0]?.coin) {
        const usdt = data.result.list[0].coin.find(c => c.coin === 'USDT');
        return parseFloat(usdt?.walletBalance || 0);
    }
    return 0;
}

async function openOrder(side) {
    const params = {
        category: 'linear',
        symbol: CONFIG.symbol,
        side: side,
        orderType: 'Market',
        qty: CONFIG.qty.toString(),
        timeInForce: 'GTC',
        positionIdx: 0
    };
    const { timestamp, signature } = signRequest(params);
    const res = await fetch('https://api.bybit.com/v5/order/create', {
        method: 'POST',
        headers: {
            'X-BAPI-API-KEY': API_KEY,
            'X-BAPI-TIMESTAMP': timestamp,
            'X-BAPI-SIGN': signature,
            'X-BAPI-RECV-WINDOW': '5000',
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(params)
    });
    const data = await res.json();
    if (data.retCode !== 0) throw new Error(data.retMsg);
    console.log(`✅ ORDER: ${side} ${CONFIG.qty} BTC`);
    return data;
}

async function main() {
    console.log("══════════════════════════════════════");
    console.log("🔴 CYBRA LIVE TRADER (REAL MONEY)");
    console.log("══════════════════════════════════════");
    
    const balance = await getBalance();
    console.log(`💰 Balance: ${balance} USDT`);
    
    if (balance < 10) {
        console.log("⚠️ LOW BALANCE!");
        process.exit(1);
    }
    
    let position = false;
    while (true) {
        try {
            const price = await getPrice();
            console.log(`[${new Date().toLocaleTimeString()}] BTC: $${price}`);
            if (!position && price < CONFIG.longEntry) {
                await openOrder('Buy');
                position = true;
            }
            await new Promise(r => setTimeout(r, 10000));
        } catch(e) {
            console.error("❌", e.message);
        }
    }
}

main().catch(console.error);
