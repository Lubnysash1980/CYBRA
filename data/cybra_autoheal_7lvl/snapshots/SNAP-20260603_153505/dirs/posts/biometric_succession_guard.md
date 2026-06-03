# CYBRA Biometric Succession Guard

Status: **active**  
Mode: **hold_until_notary_and_legal_verification**

External visible token:
`730a378b87c31052703ff0e865e90ab0eaa87ea38d219419`

External visible SHA256:
`e591e95a7bf52aba00f5027e0ad23c98084107ae85046f809d3114116254e87f`

Internal parliament seal SHA256 only:
`7717ad6fbec514cf59c4be966acec3ac9f5f609f3e72b00dbd7b05f0ea8933f7`

Internal key revealed:
`false`

Parliament internal seal:
`1377b2aa8f9a4506ac71d04ca26149ba74c5085c05500df05759f16a119b401b`

Double SHA:
`f02d926e0b71bfa6b1fe9ff345e9aa6ec4060ab8871215cb28f75cc4d6da0c46`

## Головне правило

CYBRA не визначає дітей автоматично по біометрії і не передає платформу без юридичного підтвердження.

## Дозволена схема

- законні діти / законні спадкоємці;
- нотаріальна перевірка;
- документи;
- згода законних представників, якщо дитина неповнолітня;
- encrypted local vault;
- hashes / attestations замість сирих біометричних даних;
- режим `sealed_hold_until_notary_verification`.

## Заборонено

- сирі фото обличчя в GitHub;
- відбитки пальців у GitHub;
- DNA/raw genetic data у GitHub;
- публічні дані дітей;
- автоматична передача без нотаріального/правового підтвердження;
- private keys у GitHub.

## Після смерті власника

Платформа не передається автоматично. Вона переходить у режим:

`sealed_hold_until_notary_verification`

Після офіційного підтвердження спадкоємців — Кіберапарламент може відкрити режим спадкового управління за принципами еволюції.
