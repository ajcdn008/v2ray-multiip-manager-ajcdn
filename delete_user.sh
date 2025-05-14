#!/bin/bash

CONFIG=""
POSSIBLE_PATHS=(
  "/usr/local/etc/v2ray/config.json"
  "/etc/v2ray/config.json"
  "/usr/local/etc/xray/config.json"
  "/etc/xray/config.json"
)

for path in "${POSSIBLE_PATHS[@]}"; do
  if [ -f "$path" ]; then
    CONFIG="$path"
    break
  fi
done

if [ -z "$CONFIG" ]; then
  echo "❌ 未找到 config.json，请先安装并配置好 V2Ray/Xray"
  exit 1
fi

PORT="$1"
if [ -z "$PORT" ]; then
  echo "❌ 请输入要删除的端口号，例如：bash /root/delete_user.sh 12345"
  exit 1
fi

jq "del(.inbounds[] | select(.port == $PORT))" "$CONFIG" > /tmp/config_tmp.json && mv /tmp/config_tmp.json "$CONFIG"

(systemctl restart v2ray 2>/dev/null || systemctl restart xray 2>/dev/null)

echo "✅ 已删除端口 $PORT 的用户并重启 V2Ray/Xray"
