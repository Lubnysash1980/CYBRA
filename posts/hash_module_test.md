# CYBRA Hash Module Test

Status: generated

Payload SHA256:
`55bfe18d1b3e50397ee83733e1eaea803566ed3826bf918eca02233dafa99713`

Payload Double SHA:
`045478bf71b3d263c59ea8fc0fece8666f2bce2dd6363c5cfa62f42a15e23c3f`

Root Double SHA:
`3d06bcd9fc3b8f3a06e01cb00a2905beada02e84aed2d43a825a6ffd641b2717`

Manifest:
`hash_storage/test/hash_module_test_manifest.json`

## Detected hash modules

- `gitcybrahash_double_backend.mjs`: True
- `hash_memory.py`: True
- `hash_daemon.mjs`: True
- `cybra_sha_core_manager.sh`: True
- `hash_storage/root_hash.json`: True


## Result

Hash module base pipeline works if:

- payload file exists;
- manifest file exists;
- proof file verifies;
- double SHA is generated;
- root double SHA is generated.
