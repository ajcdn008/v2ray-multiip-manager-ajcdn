#!/bin/bash

# --- 指定 IP 添加单个 VMess 用户脚本 add_user.sh ---

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

# 判断参数
TARGET_IP="$1"
if [ -z "$TARGET_IP" ]; then
  echo "❌ 请传入目标 IP，例如：bash /root/add_user.sh 27.124.46.63"
  exit 1
fi

# 检查 jq 是否安装
if ! command -v jq &> /dev/null; then
  echo "[📦] 正在安装 jq..."
  if command -v yum &> /dev/null; then
    yum install -y jq || exit 1
  elif command -v apt &> /dev/null; then
    apt update && apt install -y jq || exit 1
  else
    echo "❌ 不支持的系统，请手动安装 jq"
    exit 1
  fi
fi

# 添加用户
UUID=$(cat /proc/sys/kernel/random/uuid)
PORT=$((20000 + RANDOM % 40000))

jq --arg uuid "$UUID" --argjson port "$PORT" --arg listen "$TARGET_IP" \
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

# 生成 VMess 链接
VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "$TARGET_IP-$PORT",
  "add": "$TARGET_IP",
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

# 输出结果
echo "✅ 成功添加新用户："
echo "IP: $TARGET_IP"
echo "端口: $PORT"
echo "UUID: $UUID"
echo -e "🔗 VMess 链接：\n$VMESS_LINK"
