const ethers = require('ethers');
const readline = require('readline');
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
rl.question('Введіть seed phrase (12 або 24 слова): ', (seed) => {
    rl.close();
    try {
        const wallet = ethers.Wallet.fromMnemonic(seed.trim());
        console.log('Адреса:', wallet.address);
        if (wallet.address.toLowerCase() === '0x322f6c2da1d1bbb2a965403b32175a50261caf3f'.toLowerCase()) {
            console.log('🎉 Це ваш холодний гаманець!');
        }
    } catch (e) { console.error('❌ Невірна seed-фраза'); }
});
