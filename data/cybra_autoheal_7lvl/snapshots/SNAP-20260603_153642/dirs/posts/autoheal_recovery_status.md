# CYBRA AutoHeal Recovery Capsule

Status: packed

Capsule ID:
`CYBRA_RECOVERY_20260602_144711`

Archive:
`/data/data/com.termux/files/home/CYBRA/recovery_packs/CYBRA_RECOVERY_20260602_144711.tar.gz`

Manifest:
`/data/data/com.termux/files/home/CYBRA/recovery_packs/CYBRA_RECOVERY_20260602_144711.tar.gz.manifest.json`

Archive SHA256:
`453d50ed7e6e3368542ba0306dddeceb40c8d589b3c6c47912de0277a7d1a2ca`

Root Double SHA:
`be90b80973188f167cd82b59e4683c142ea06837e364d4c41ee9b1c3ada1aed4`

Files packed:
57963

## Meaning

Архів `.tar.gz` містить файли CYBRA.

Root Double SHA — це контрольна печатка.  
Сам hash не містить файли.  
Для відновлення потрібні архів і manifest.

## Restore commands

Verify:

    bash cybra_autoheal_recovery_pack.sh verify /data/data/com.termux/files/home/CYBRA/recovery_packs/CYBRA_RECOVERY_20260602_144711.tar.gz

Unpack:

    bash cybra_autoheal_recovery_pack.sh unpack /data/data/com.termux/files/home/CYBRA/recovery_packs/CYBRA_RECOVERY_20260602_144711.tar.gz

## Excluded from capsule

- private_vault
- dump.rdb
- ai_network
- node_modules
- recovery_packs
- recovery_unpack
- token/runtime/rpc.env
- secrets / keys
