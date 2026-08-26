const fs = require('fs');
const ethers = require('ethers');
const provider = new ethers.providers.JsonRpcProvider(process.env.BSC_RPC || 'https://bsc-dataseed.binance.org/');
const wallet = new ethers.Wallet(process.env.HOT_PRIVATE_KEY, provider);

const bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
const clean = bytecode.startsWith('0x') ? bytecode : '0x' + bytecode;

async function buildTx() {
    const nonce = await wallet.getTransactionCount();
    const gasPrice = await provider.getGasPrice();
    const tx = {
        data: clean,
        gasLimit: 2000000,
        chainId: 56,
        nonce: nonce,
        gasPrice: gasPrice
    };
    fs.writeFileSync('./wallet/runtime/pending_deploy.tx', JSON.stringify(tx, null, 2));
    console.log('✅ pending_deploy.tx створено (nonce=' + nonce + ', gasPrice=' + ethers.utils.formatUnits(gasPrice, 'gwei') + ' Gwei)');
}
buildTx().catch(e => { console.error(e); process.exit(1); });
