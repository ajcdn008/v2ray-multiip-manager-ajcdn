#!/bin/bash

# --- 一键部署多IP V2Ray VPN 包含：安装、批量添加、单IP添加、管理工具安装 ---

# 颜色函数
info() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# 1. 安装 V2Ray（官方脚本）
info "安装 V2Ray..."
bash <(curl -s -L https://git.io/v2ray.sh)

# 2. 下载多IP批量用户添加脚本
info "下载批量添加用户脚本 add_multiip.sh..."
curl -o /root/add_multiip.sh https://raw.githubusercontent.com/ajcdn008/v2ray-multiip-manager-ajcdn/main/add_multiip.sh
chmod +x /root/add_multiip.sh

# 3. 下载指定IP添加用户脚本
info "下载单IP添加用户脚本 add_user.sh..."
curl -o /root/add_user.sh https://raw.githubusercontent.com/ajcdn008/v2ray-multiip-manager-ajcdn/main/add_user.sh
chmod +x /root/add_user.sh

# 4. 下载管理脚本（查看/删除）
info "安装管理工具 list_users.sh / delete_user.sh..."
curl -o /root/list_users.sh https://raw.githubusercontent.com/ajcdn008/v2ray-multiip-manager-ajcdn/main/list_users.sh
chmod +x /root/list_users.sh

curl -o /root/delete_user.sh https://raw.githubusercontent.com/ajcdn008/v2ray-multiip-manager-ajcdn/main/delete_user.sh
chmod +x /root/delete_user.sh

# 5. 执行批量添加用户
info "为所有公网 IP 批量添加初始用户..."
bash /root/add_multiip.sh

info "✅ 安装完成！可使用如下命令管理："
echo "  🔁 添加新用户：bash /root/add_user.sh 公网IP"
echo "  📄 查看所有用户：bash /root/list_users.sh"
echo "  ❌ 删除指定端口：bash /root/delete_user.sh"
