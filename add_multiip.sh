#!/bin/bash

CONFIG_PATHS=(
  "/usr/local/etc/v2ray/config.json"
  "/etc/v2ray/config.json"
  "/usr/local/etc/xray/config.json"
  "/etc/xray/config.json"
)

# 找到配置文件
for path in "${CONFIG_PATHS[@]}"; do
  if [ -f "$path" ]; then
    CONFIG="$path"
    break
  fi
done

if [ -z "$CONFIG" ]; then
  echo "❌ 未找到 config.json，请先安装 V2Ray 或 Xray"
  exit 1
fi

# 获取所有公网 IP
PUB_IPS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -vE '^127|^192\.168|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])')

for ip in $PUB_IPS; do
  UUID=$(cat /proc/sys/kernel/random/uuid)
  PORT=$((20000 + RANDOM % 40000))

  jq --arg uuid "$UUID" --argjson port "$PORT" --arg listen "$ip" \
  '.inbounds += [{
    "port": $port,
    "listen": $listen,
    "protocol": "vmess",
    "settings": {
      "clients": [{ "id": $uuid, "alterId": 0 }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "none"
    }
  }]' "$CONFIG" > /tmp/config_tmp.json && mv /tmp/config_tmp.json "$CONFIG"

  (systemctl restart v2ray 2>/dev/null || systemctl restart xray 2>/dev/null)

  VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "$ip-$PORT",
  "add": "$ip",
  "port": "$PORT",
  "id": "$UUID",
  "aid": "0",
  "net": "tcp",
  "type": "none",
  "host": "",
  "path": "",
  "tls": ""
}
EOF
)
  VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 -w 0)"
  echo "✅ 已添加: $ip:$PORT UUID=$UUID"
  echo "🔗 $VMESS_LINK"
done
