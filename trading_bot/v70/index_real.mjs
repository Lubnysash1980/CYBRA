import fs from 'fs';
import fetch from 'node-fetch';
import crypto from 'crypto';

const secrets = JSON.parse(fs.readFileSync('.cybra_local_secret/exchanges/bybit_live.json', 'utf8'));

const API_KEY = secrets.api_key;
const API_SECRET = secrets.api_secret;
const SYMBOL = 'BTCUSDT';
const QUANTITY = 0.001;
const LONG_ENTRY = 63000;

function signRequest(params) {
    const timestamp = Date.now().toString();
    const queryString = new URLSearchParams(params).toString();
    const signature = crypto.createHmac('sha256', API_SECRET)
        .update(timestamp + API_KEY + '5000' + queryString)
        .digest('hex');
    return { timestamp, signature, queryString };
}

async function getPrice() {
    const res = await fetch(`https://api.bybit.com/v5/market/tickers?category=linear&symbol=${SYMBOL}`);
    const data = await res.json();
    return parseFloat(data.result.list[0].lastPrice);
}

async function getBalance() {
    const params = { accountType: 'UNIFIED', coin: 'USDT' };
    const { timestamp, signature } = signRequest(params);
    
    const response = await fetch(`https://api.bybit.com/v5/account/wallet-balance?${new URLSearchParams(params)}`, {
        headers: {
            'X-BAPI-API-KEY': API_KEY,
            'X-BAPI-TIMESTAMP': timestamp,
            'X-BAPI-SIGN': signature,
            'X-BAPI-RECV-WINDOW': '5000'
        }
    });
    const data = await response.json();
    if (data.retCode === 0 && data.result.list[0]?.coin[0]) {
        return parseFloat(data.result.list[0].coin[0].walletBalance);
    }
    return 0;
}

async function placeOrder(side) {
    const params = {
        category: 'linear',
        symbol: SYMBOL,
        side: side,
        orderType: 'Market',
        qty: QUANTITY.toString(),
        timeInForce: 'GTC',
        positionIdx: 0  // 0 = one-way mode
    };
    
    const { timestamp, signature } = signRequest(params);
    
    const response = await fetch('https://api.bybit.com/v5/order/create', {
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
    
    const data = await response.json();
    if (data.retCode !== 0) throw new Error(data.retMsg);
    return data;
}

async function main() {
    console.log("══════════════════════════════════════");
    console.log("🔴 REAL TRADING (Bybit Futures UTA)");
    console.log("══════════════════════════════════════");
    
    const balance = await getBalance();
    console.log(`💰 Balance: ${balance} USDT`);
    
    if (balance < 10) {
        console.log("⚠️ Low balance!");
    } else {
        console.log("✅ Balance OK, ready to trade");
    }
    console.log("");
    
    while (true) {
        try {
            const price = await getPrice();
            console.log(`[${new Date().toLocaleTimeString()}] BTC: $${price}`);
            
            if (price < LONG_ENTRY) {
                console.log(`📡 LONG SIGNAL at $${price}`);
                console.log("🔵 PLACING ORDER...");
                const result = await placeOrder('Buy');
                console.log(`✅ ORDER EXECUTED! Order ID: ${result.result.orderId}`);
                break;  // Зупиняємось після першого ордера
            }
            
            await new Promise(r => setTimeout(r, 10000));
        } catch(e) {
            console.error("❌", e.message);
            await new Promise(r => setTimeout(r, 5000));
        }
    }
}

main().catch(console.error);
