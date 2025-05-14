#!/bin/bash

# --- 为指定 IP 添加一个 VMess 用户，含二维码 ---

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

# 获取参数（指定IP）
TARGET_IP="$1"
if [ -z "$TARGET_IP" ]; then
  echo "用法: bash add_multiip.sh 你的公网IP"
  exit 1
fi

# 检查依赖
for cmd in jq qrencode; do
  if ! command -v $cmd &>/dev/null; then
    echo "[📦] 安装依赖：$cmd..."
    if command -v apt &>/dev/null; then
      apt update && apt install -y $cmd
    elif command -v yum &>/dev/null; then
      yum install -y $cmd
    else
      echo "❌ 请手动安装 $cmd"
      exit 1
    fi
  fi

  if ! command -v $cmd &>/dev/null; then
    echo "❌ $cmd 安装失败"
    exit 1
  fi

  echo "✅ $cmd 已安装"
done

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

VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "$TARGET_IP:$PORT",
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
echo "$VMESS_LINK" >> /root/vmess_links.txt
qrencode -o "/root/${TARGET_IP//./_}_$PORT.png" "$VMESS_LINK"

echo "✅ 添加成功！"
echo "IP: $TARGET_IP"
echo "端口: $PORT"
echo "UUID: $UUID"
echo -e "🔗 VMess 链接：\n$VMESS_LINK"
echo "🖼️ 二维码已保存：/root/${TARGET_IP//./_}_$PORT.png"
