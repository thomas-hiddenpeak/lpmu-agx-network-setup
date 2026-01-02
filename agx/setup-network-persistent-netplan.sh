#!/bin/bash
# AGX网络持久化配置脚本（使用netplan）

set -e

# 配置参数
AGX_IP="10.10.99.98"
LPMU_IP="10.10.99.99"
NETWORK_IFACE="eth0"  # 根据实际情况修改

echo "=== 使用Netplan配置AGX网络（持久化） ==="

# 检查netplan是否存在
if [ ! -d /etc/netplan ]; then
    echo "错误: /etc/netplan 目录不存在"
    echo "此脚本适用于使用netplan的系统（如Ubuntu 18.04+）"
    exit 1
fi

# 备份现有配置
echo "[1/3] 备份现有配置..."
mkdir -p /etc/netplan/backup
cp /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null || true

# 创建新的netplan配置
echo "[2/3] 创建netplan配置..."
cat > /etc/netplan/01-lpmu-static.yaml << EOF
# AGX网络配置 - 通过LPMU访问互联网
network:
  version: 2
  renderer: networkd
  ethernets:
    $NETWORK_IFACE:
      dhcp4: no
      addresses:
        - $AGX_IP/24
      routes:
        - to: default
          via: $LPMU_IP
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
          - 114.114.114.114
EOF

chmod 600 /etc/netplan/01-lpmu-static.yaml

# 应用配置
echo "[3/3] 应用netplan配置..."
netplan apply

echo ""
echo "=== 配置完成 ==="
echo ""
echo "配置文件: /etc/netplan/01-lpmu-static.yaml"
echo ""
echo "接口状态:"
ip addr show $NETWORK_IFACE
echo ""
echo "路由表:"
ip route show
echo ""
echo "测试连接:"
ping -c 3 $LPMU_IP
