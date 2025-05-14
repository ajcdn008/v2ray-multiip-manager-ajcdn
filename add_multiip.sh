#!/bin/bash

# --- 自动识别服务器所有公网 IP 并批量添加 V2Ray 用户（兼容 secondary IP）+ 生成 VMess 链接 ---

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

IP_LIST=$(ip -4 addr | grep -oP 'inet \K[0-9.]+(?=/)' | grep -vE '^(127|10|172\.(1[6-9]|2[0-9]|3[01])|192\.168)')

if [ -z "$IP_LIST" ]; then
  echo "❌ 未检测到公网 IP，请确认服务器绑定了多 IP"
  echo "--- 当前 ip a 输出如下 ---"
  ip a
  exit 1
fi

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

for IP in $IP_LIST; do
  echo "\n🔧 为 IP [$IP] 添加 VPN 用户..."
  UUID=$(cat /proc/sys/kernel/random/uuid)
  PORT=$((20000 + RANDOM % 40000))

  jq --arg uuid "$UUID" --argjson port "$PORT" --arg listen "$IP" \
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

  echo "✅ 已添加：$IP:$PORT UUID=$UUID"

  # 生成 VMess 链接 JSON
  VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "$IP-$PORT",
  "add": "$IP",
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
  echo -e "🔗 VMess 链接：\n$VMESS_LINK"
done

(systemctl restart v2ray 2>/dev/null || systemctl restart xray 2>/dev/null)

cat <<EOF > /root/list_users.sh
#!/bin/bash
jq -r '.inbounds[] | select(.protocol=="vmess") | "监听IP: \(.listen // "0.0.0.0")\\n端口: \(.port)\\nUUID: \(.settings.clients[0].id)\\n----"' "$CONFIG"
EOF
chmod +x /root/list_users.sh

cat <<EOF > /root/delete_user.sh
#!/bin/bash
read -p "请输入要删除的端口号: " PORT
jq 'del(.inbounds[] | select(.port == '"\$PORT"'))' "$CONFIG" > /tmp/config_tmp.json && mv /tmp/config_tmp.json "$CONFIG"
(systemctl restart v2ray 2>/dev/null || systemctl restart xray 2>/dev/null)
echo "✅ 已删除端口 \$PORT 的用户"
EOF
chmod +x /root/delete_user.sh

echo -e "\n🎉 所有公网 IP 用户已创建完毕，可用以下命令管理："
echo "📄 查看用户：bash /root/list_users.sh"
echo "❌ 删除用户：bash /root/delete_user.sh"
