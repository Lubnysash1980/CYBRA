const fs = require('fs');
const ethers = require('ethers');
const readline = require('readline');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

rl.question('Введіть seed phrase (12 або 24 слова, через пробіл): ', (mnemonic) => {
    rl.close();
    try {
        const wallet = ethers.Wallet.fromMnemonic(mnemonic.trim());
        console.log('✅ Адреса гаманця:', wallet.address);
        console.log('   Очікувана адреса: 0x322f6c2da1d1bbb2a965403b32175a50261caf3f');

        const txPath = './wallet/runtime/pending_deploy.tx';
        if (!fs.existsSync(txPath)) {
            console.error('❌ pending_deploy.tx не знайдено');
            process.exit(1);
        }

        const txData = JSON.parse(fs.readFileSync(txPath, 'utf8'));
        wallet.signTransaction(txData).then(signed => {
            fs.writeFileSync('./wallet/runtime/signed.tx', signed);
            console.log('✅ signed.tx створено! Довжина:', signed.length, 'символів');
            console.log('   Перевірте: wc -c wallet/runtime/signed.tx');
            console.log('   Тепер запустіть: ./auto_cycler.sh');
        }).catch(e => console.error('❌ Помилка підпису:', e.message));
    } catch (e) {
        console.error('❌ Помилка відновлення гаманця:', e.message);
    }
});
