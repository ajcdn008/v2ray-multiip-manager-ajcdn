#!/bin/bash

# --- 为每个公网IP添加一个VMess用户，生成二维码 ---

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

# 检查 qrencode 是否安装
if ! command -v qrencode &> /dev/null; then
  echo "[📦] 正在安装二维码生成工具 qrencode..."
  if command -v yum &> /dev/null; then
    yum install -y qrencode || exit 1
  elif command -v apt &> /dev/null; then
    apt update && apt install -y qrencode || exit 1
  else
    echo "❌ 不支持的系统，请手动安装 qrencode"
    exit 1
  fi
fi

# 获取所有公网IP（非127.0.0.1，非内网）
IP_LIST=$(ip -4 addr | grep inet | grep -vE '127|192|10\.|172\.(1[6-9]|2[0-9]|3[0-1])' | awk '{print $2}' | cut -d'/' -f1)

if [ -z "$IP_LIST" ]; then
  echo "❌ 未检测到公网IP，请确认服务器绑定了多个 IP"
  exit 1
fi

VMESS_LINKS=""

for TARGET_IP in $IP_LIST; do
  echo -e "🔧 为 IP [$TARGET_IP] 添加 VPN 用户..."
  UUID=$(cat /proc/sys/kernel/random/uuid)
  PORT=$((20000 + RANDOM % 40000))

  jq --arg uuid "$UUID" --argjson port "$PORT" --arg listen "$TARGET_IP" \
  '.inbounds += [{
    "port": $port,
    "listen": $listen,
    "protocol": "vmess",
    "settings": { "clients": [{ "id": $uuid, "alterId": 0 }] },
    "streamSettings": { "network": "tcp", "security": "none" }
  }]' "$CONFIG" > /tmp/config_tmp.json && mv /tmp/config_tmp.json "$CONFIG"

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
  echo "✅ 已添加：$TARGET_IP:$PORT UUID=$UUID"
  echo "$VMESS_LINK" >> /root/vmess_links.txt
  qrencode -o "/root/${TARGET_IP//./_}_$PORT.png" "$VMESS_LINK"
done

(systemctl restart v2ray 2>/dev/null || systemctl restart xray 2>/dev/null)

echo -e "\n🎉 所有公网 IP 用户已创建完毕，可用以下命令管理："
echo "📄 查看用户：bash /root/list_users.sh"
echo "❌ 删除用户：bash /root/delete_user.sh"
echo "🖼️ 所有二维码保存在 /root/*.png 中"
echo "📎 所有 vmess 链接保存在 /root/vmess_links.txt"
