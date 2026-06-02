# CYBRA Hash Module Test

Status: generated

Payload SHA256:
`eae07d205651fdc60d787af09a18aa1698df10400907b13eb78556f65dbbc50e`

Payload Double SHA:
`45a1f584754a2f5ad3723fea8f7167e560fb1c46399df75bb12cd91775f95160`

Root Double SHA:
`6581782f91d4b7eeccf991fea53ea3b22f592bfeaca9865bfe4dff7d83238752`

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
