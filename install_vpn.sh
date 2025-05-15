#!/bin/bash

# --- 一键部署多IP V2Ray VPN 并绑定出口IP 路由策略 ---

info() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# 获取网关（自动获取主路由网关）
GATEWAY=$(ip route | grep default | awk '{print $3}')

# 1. 安装 V2Ray
info "安装 V2Ray..."
bash <(curl -s -L https://git.io/v2ray.sh)

# 2. 安装二维码生成工具
info "安装二维码工具 qrencode..."
if command -v yum &>/dev/null; then
  yum install -y qrencode
elif command -v apt &>/dev/null; then
  apt update && apt install -y qrencode
else
  error "不支持的系统，请手动安装 qrencode"
  exit 1
fi

# 3. 下载所需脚本
info "下载批量添加用户脚本 add_multiip.sh..."
curl -o /root/add_multiip.sh https://raw.githubusercontent.com/ajcdn008/v2ray-multiip-manager-ajcdn/main/add_multiip.sh
chmod +x /root/add_multiip.sh

info "下载单IP添加用户脚本 add_user.sh..."
curl -o /root/add_user.sh https://raw.githubusercontent.com/ajcdn008/v2ray-multiip-manager-ajcdn/main/add_user.sh
chmod +x /root/add_user.sh

info "安装管理工具 list_users.sh / delete_user.sh..."
curl -o /root/list_users.sh https://raw.githubusercontent.com/ajcdn008/v2ray-multiip-manager-ajcdn/main/list_users.sh
chmod +x /root/list_users.sh
curl -o /root/delete_user.sh https://raw.githubusercontent.com/ajcdn008/v2ray-multiip-manager-ajcdn/main/delete_user.sh
chmod +x /root/delete_user.sh

# 4. 设置多IP出口策略路由
info "配置多IP出口策略路由..."
ip add show eth0 | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | while read ip; do
  last=$(echo $ip | awk -F. '{print $4}')
  table="rt$last"
  id=$((100 + last))
  echo "$id $table" >> /etc/iproute2/rt_tables 2>/dev/null
  ip rule add from $ip table $table
  ip route add default via $GATEWAY dev eth0 table $table
  info "已为 $ip 设置出口路由绑定 ($table)"
done

# 5. 添加 VPN 用户
info "为所有公网 IP 批量添加初始用户..."
bash /root/add_multiip.sh | tee /root/vmess_links.txt

# 6. 生成二维码图片
info "生成二维码图片..."
grep -oE 'vmess://[a-zA-Z0-9+/=]+' /root/vmess_links.txt | while read -r line; do
  qrencode -o "/root/$(echo $line | cut -c 9-20).png" "$line"
done

info "✅ 安装完成！使用以下命令管理："
echo "  🔁 添加新用户：bash /root/add_user.sh 公网IP"
echo "  📄 查看所有用户：bash /root/list_users.sh"
echo "  ❌ 删除指定端口：bash /root/delete_user.sh"
echo "  🖼️ 所有二维码保存在 /root/*.png 文件中"
