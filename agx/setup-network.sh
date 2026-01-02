#!/bin/bash
# AGX网络配置脚本
# 用途: 配置agx使用lpmu作为网关访问互联网

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置参数
AGX_IP="10.10.99.98"
LPMU_IP="10.10.99.99"
SUBNET_MASK="255.255.255.0"
NETWORK_IFACE="eth0"  # 根据实际情况修改，可能是enp2s0等

echo -e "${GREEN}=== AGX网络配置脚本 ===${NC}"

# 1. 检测网络接口
echo -e "${YELLOW}[1/5] 检测网络接口...${NC}"
echo "当前网络接口:"
ip -brief addr show | grep -v "^lo"

# 尝试自动检测主网络接口
if ip addr show $NETWORK_IFACE &> /dev/null; then
    echo -e "${GREEN}  使用接口: $NETWORK_IFACE${NC}"
else
    echo -e "${RED}  接口 $NETWORK_IFACE 不存在${NC}"
    echo -e "${YELLOW}  可用接口:${NC}"
    ip -o link show | awk -F': ' '{print "    " $2}' | grep -v "^    lo$"
    echo -e "${YELLOW}  请编辑脚本，修改 NETWORK_IFACE 变量${NC}"
    exit 1
fi

# 2. 配置静态IP地址
echo -e "${YELLOW}[2/5] 配置静态IP地址...${NC}"
ip addr flush dev $NETWORK_IFACE
ip addr add $AGX_IP/24 dev $NETWORK_IFACE
ip link set $NETWORK_IFACE up
echo -e "${GREEN}  已配置 $NETWORK_IFACE: $AGX_IP/24${NC}"

# 3. 配置默认网关
echo -e "${YELLOW}[3/5] 配置默认网关...${NC}"
ip route del default 2>/dev/null || true
ip route add default via $LPMU_IP dev $NETWORK_IFACE
echo -e "${GREEN}  已设置默认网关: $LPMU_IP${NC}"

# 4. 配置DNS
echo -e "${YELLOW}[4/5] 配置DNS...${NC}"
# 备份原有DNS配置
if [ -f /etc/resolv.conf ]; then
    cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# 写入新的DNS配置
cat > /etc/resolv.conf << EOF
# DNS配置 - 由AGX网络配置脚本生成
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 114.114.114.114
EOF

echo -e "${GREEN}  已配置DNS服务器${NC}"

# 5. 测试连接
echo -e "${YELLOW}[5/5] 测试网络连接...${NC}"

# 测试到网关的连接
echo -e "${YELLOW}  测试到LPMU的连接...${NC}"
if ping -c 3 -W 2 $LPMU_IP > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ 可以连接到LPMU ($LPMU_IP)${NC}"
else
    echo -e "${RED}  ✗ 无法连接到LPMU ($LPMU_IP)${NC}"
fi

# 测试互联网连接
echo -e "${YELLOW}  测试互联网连接...${NC}"
if ping -c 3 -W 5 8.8.8.8 > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ 可以连接到互联网 (8.8.8.8)${NC}"
else
    echo -e "${RED}  ✗ 无法连接到互联网${NC}"
    echo -e "${YELLOW}  请检查LPMU上的NAT配置${NC}"
fi

# 测试DNS解析
echo -e "${YELLOW}  测试DNS解析...${NC}"
if ping -c 2 -W 5 google.com > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ DNS解析正常${NC}"
else
    echo -e "${YELLOW}  ✗ DNS解析失败或无法访问测试域名${NC}"
fi

# 显示当前网络配置
echo -e "\n${GREEN}=== 当前网络配置 ===${NC}"
echo -e "${GREEN}IP地址:${NC}"
ip addr show $NETWORK_IFACE | grep "inet "

echo -e "\n${GREEN}路由表:${NC}"
ip route show

echo -e "\n${GREEN}DNS配置:${NC}"
cat /etc/resolv.conf | grep "^nameserver"

echo -e "\n${GREEN}=== 配置完成 ===${NC}"
echo -e "${YELLOW}注意: 此配置在重启后会丢失，请使用持久化脚本保存配置${NC}"
