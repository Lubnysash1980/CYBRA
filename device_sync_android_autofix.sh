#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p device/android devices hash_storage/device posts proofs feeds

DEVICE_ID_FILE="device/android/device_id.txt"

if [ ! -f "$DEVICE_ID_FILE" ]; then
  ID="android_$(getprop ro.product.model 2>/dev/null | tr ' /' '__')_$(date +%s)"
  echo "$ID" > "$DEVICE_ID_FILE"
fi

DEVICE_ID="$(cat "$DEVICE_ID_FILE")"

cat > "devices/${DEVICE_ID}.json" <<JSON
{
  "device_id": "$DEVICE_ID",
  "type": "android_termux",
  "model": "$(getprop ro.product.model 2>/dev/null || echo unknown)",
  "android": "$(getprop ro.build.version.release 2>/dev/null || echo unknown)",
  "repo": "CYBRA",
  "git_branch": "$(git branch --show-current 2>/dev/null || echo unknown)",
  "ai_os_backend": true,
  "double_sha_backend": true,
  "memory_mode": "accelerated_hash_index",
  "time": "$(date -Iseconds)"
}
JSON

sha256sum "devices/${DEVICE_ID}.json" > "hash_storage/device/${DEVICE_ID}.sha256"

cat > feeds/device_sync_android.json <<JSON
{
  "status": "active",
  "device_id": "$DEVICE_ID",
  "double_sha": true,
  "git_sync": true,
  "android_accelerated": true
}
JSON

cat > posts/device_sync_android_status.md <<MD
# CYBRA Android Device Sync

Status: active

Device ID:
$DEVICE_ID

Mode:
Android Termux accelerated hash memory

Modules:
- GitHub sync
- Double SHA
- AI OS backend
- CYBRA Parliament
- Device memory
MD

sha256sum \
device/android/device_id.txt \
devices/${DEVICE_ID}.json \
hash_storage/device/${DEVICE_ID}.sha256 \
feeds/device_sync_android.json \
posts/device_sync_android_status.md \
> proofs/device_sync_android.sha256

echo "✅ Android device integrated: $DEVICE_ID"
