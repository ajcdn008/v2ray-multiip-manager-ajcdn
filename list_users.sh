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

echo -e "当前所有用户配置如下："
echo -e "端口  |  UUID"
echo "---------------------------"

jq -r '.inbounds[] | select(.protocol=="vmess") | "\(.port)  |  \(.settings.clients[0].id)"' "$CONFIG"
