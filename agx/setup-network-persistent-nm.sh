#!/bin/bash
# AGX网络持久化配置脚本（使用NetworkManager）

set -e

# 配置参数
AGX_IP="10.10.99.98"
LPMU_IP="10.10.99.99"
CONNECTION_NAME="lpmu-static"
NETWORK_IFACE="eth0"  # 根据实际情况修改

echo "=== 使用NetworkManager配置AGX网络（持久化） ==="

# 检查NetworkManager是否安装
if ! command -v nmcli &> /dev/null; then
    echo "错误: NetworkManager未安装"
    echo "请安装: sudo apt-get install network-manager"
    exit 1
fi

# 删除可能存在的旧连接
echo "[1/3] 删除旧连接配置..."
nmcli connection delete "$CONNECTION_NAME" 2>/dev/null || true

# 创建新的连接
echo "[2/3] 创建新的静态IP连接..."
nmcli connection add \
    type ethernet \
    con-name "$CONNECTION_NAME" \
    ifname "$NETWORK_IFACE" \
    ipv4.method manual \
    ipv4.addresses "$AGX_IP/24" \
    ipv4.gateway "$LPMU_IP" \
    ipv4.dns "8.8.8.8,8.8.4.4,114.114.114.114" \
    connection.autoconnect yes

# 激活连接
echo "[3/3] 激活连接..."
nmcli connection up "$CONNECTION_NAME"

echo ""
echo "=== 配置完成 ==="
echo ""
echo "连接信息:"
nmcli connection show "$CONNECTION_NAME" | grep -E "ipv4\.(addresses|gateway|dns)"
echo ""
echo "接口状态:"
ip addr show $NETWORK_IFACE
echo ""
echo "路由表:"
ip route show
