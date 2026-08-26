const fs = require('fs');
const ethers = require('ethers');

const env = {};
const lines = fs.readFileSync('.env', 'utf8').split('\n');
for (const line of lines) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#')) continue;
  const [key, ...val] = trimmed.split('=');
  env[key.trim()] = val.join('=').trim();
}

let privateKey = env.HOT_PRIVATE_KEY;
if (!privateKey) { console.error('❌ Ключ відсутній'); process.exit(1); }
if (!privateKey.startsWith('0x')) privateKey = '0x' + privateKey;
if (privateKey.length !== 66) privateKey = privateKey.slice(0, 66);

const provider = new ethers.JsonRpcProvider(env.BSC_RPC || 'https://bsc-dataseed.binance.org/');
const wallet = new ethers.Wallet(privateKey, provider);

(async () => {
  let bytecode = fs.readFileSync('./contracts/CybraToken.bin', 'utf8').trim();
  if (!bytecode.startsWith('0x')) bytecode = '0x' + bytecode;

  const nonce = await wallet.getNonce();
  const feeData = await provider.getFeeData();
  let gasPrice = feeData.gasPrice || BigInt(5000000000);
  if (gasPrice < BigInt(5000000000)) gasPrice = BigInt(5000000000);

  const tx = {
    data: bytecode,
    gasLimit: 3000000n,
    chainId: 56,
    nonce: nonce,
    gasPrice: gasPrice
  };

  console.log('🔹 Підпис...');
  const signed = await wallet.signTransaction(tx);
  console.log('✅ Підписано, довжина:', signed.length);
  fs.writeFileSync('./wallet/runtime/signed.tx', signed);

  console.log('🔹 Надсилання...');
  const response = await provider.broadcastTransaction(signed);
  console.log('✅ Хеш:', response.hash);
  fs.writeFileSync('./wallet/runtime/deploy_hash.txt', response.hash);

  console.log('⏳ Очікуємо підтвердження...');
  const receipt = await response.wait();
  console.log('✅ Адреса контракту:', receipt.contractAddress);
  fs.writeFileSync('./wallet/runtime/contract_address.txt', receipt.contractAddress);
})();
