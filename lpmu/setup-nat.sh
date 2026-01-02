#!/bin/bash
# LPMU网络转发和NAT配置脚本
# 用途: 让agx通过lpmu的任何可用网络接口访问互联网

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 内网接口（连接agx）
INTERNAL_IFACE="enp2s0"
INTERNAL_IP="10.10.99.99"
AGX_IP="10.10.99.98"
SSH_EXTERNAL_PORT="58022"

echo -e "${GREEN}=== LPMU网络转发配置脚本 ===${NC}"

# 1. 启用IP转发
echo -e "${YELLOW}[1/6] 启用IP转发...${NC}"
echo 1 > /proc/sys/net/ipv4/ip_forward
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo -e "${GREEN}已添加到 /etc/sysctl.conf${NC}"
fi
sysctl -p > /dev/null 2>&1

# 2. 清除现有的NAT规则
echo -e "${YELLOW}[2/6] 清除现有NAT和端口转发规则...${NC}"
iptables -t nat -F
iptables -t nat -X
iptables -F FORWARD
echo -e "${GREEN}已清除现有规则${NC}"

# 3. 设置默认FORWARD策略
echo -e "${YELLOW}[3/5] 配置FORWARD链...${NC}"
iptables -P FORWARD DROP
iptables -A FORWARD -i $INTERNAL_IFACE -o $INTERNAL_IFACE -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
echo -e "${GREEN}已配置FORWARD链${NC}"

# 4. 检测有互联网连接的接口并配置NAT
echo -e "${YELLOW}[4/6] 检测互联网连接并配置NAT...${NC}"

# 获取所有活跃的网络接口（排除lo和内网接口）
ACTIVE_IFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$\|^$INTERNAL_IFACE$")

NAT_CONFIGURED=0

for iface in $ACTIVE_IFACES; do
    # 检查接口是否有IP地址
    if ip addr show $iface | grep -q "inet "; then
        # 检查接口是否有默认路由
        if ip route | grep "^default" | grep -q "$iface"; then
            echo -e "${GREEN}  发现互联网接口: $iface${NC}"
            
            # 配置NAT
            iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
            iptables -A FORWARD -i $INTERNAL_IFACE -o $iface -j ACCEPT
            
            NAT_CONFIGURED=1
            echo -e "${GREEN}  已为 $iface 配置NAT${NC}"
        fi
    fi
done

if [ $NAT_CONFIGURED -eq 0 ]; then
    echo -e "${RED}  警告: 未找到有互联网连接的接口${NC}"
    echo -e "${YELLOW}  将配置所有活跃接口的NAT...${NC}"
    
    for iface in $ACTIVE_IFACES; do
        if ip addr show $iface | grep -q "inet "; then
            iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
            iptables -A FORWARD -i $INTERNAL_IFACE -o $iface -j ACCEPT
            echo -e "${GREEN}  已为 $iface 配置NAT${NC}"
        fi
    done
fi

# 5. 配置端口转发
echo -e "${YELLOW}[5/6] 配置端口转发...${NC}"

# 获取有互联网连接的接口
INTERNET_IFACE=$(ip route | grep '^default' | head -1 | awk '{print $5}')

if [ -n "$INTERNET_IFACE" ]; then
    # 5.1 配置 SSH 端口转发（AGX:22 -> LPMU:58022）
    echo -e "  配置 SSH 端口转发: AGX:22 -> LPMU:$SSH_EXTERNAL_PORT"
    iptables -t nat -A PREROUTING -i $INTERNET_IFACE -p tcp --dport $SSH_EXTERNAL_PORT -j DNAT --to-destination $AGX_IP:22
    iptables -t nat -A POSTROUTING -d $AGX_IP -p tcp --dport 22 -j SNAT --to-source $INTERNAL_IP
    iptables -A FORWARD -i $INTERNET_IFACE -o $INTERNAL_IFACE -p tcp --dport 22 -d $AGX_IP -j ACCEPT
    iptables -A FORWARD -i $INTERNAL_IFACE -o $INTERNET_IFACE -p tcp --sport 22 -s $AGX_IP -j ACCEPT
    echo -e "${GREEN}  ✓ SSH: 外部访问 LPMU:58022 -> AGX:22${NC}"
    
    # 5.2 配置端口范围转发（AGX:58000-58999 -> LPMU:58000-58999）
    echo -e "  配置端口范围转发: LPMU:58000-58999 -> AGX:58000-58999"
    
    # DNAT: 将 LPMU 的 58000-58999 端口转发到 AGX 相同端口
    iptables -t nat -A PREROUTING -i $INTERNET_IFACE -p tcp --dport 58000:58999 -j DNAT --to-destination $AGX_IP
    iptables -t nat -A PREROUTING -i $INTERNET_IFACE -p udp --dport 58000:58999 -j DNAT --to-destination $AGX_IP
    
    # SNAT: 确保返回流量经过 LPMU
    iptables -t nat -A POSTROUTING -d $AGX_IP -p tcp --dport 58000:58999 -j SNAT --to-source $INTERNAL_IP
    iptables -t nat -A POSTROUTING -d $AGX_IP -p udp --dport 58000:58999 -j SNAT --to-source $INTERNAL_IP
    
    # 允许转发流量（TCP）
    iptables -A FORWARD -i $INTERNET_IFACE -o $INTERNAL_IFACE -p tcp --dport 58000:58999 -d $AGX_IP -j ACCEPT
    iptables -A FORWARD -i $INTERNAL_IFACE -o $INTERNET_IFACE -p tcp --sport 58000:58999 -s $AGX_IP -j ACCEPT
    
    # 允许转发流量（UDP）
    iptables -A FORWARD -i $INTERNET_IFACE -o $INTERNAL_IFACE -p udp --dport 58000:58999 -d $AGX_IP -j ACCEPT
    iptables -A FORWARD -i $INTERNAL_IFACE -o $INTERNET_IFACE -p udp --sport 58000:58999 -s $AGX_IP -j ACCEPT
    
    echo -e "${GREEN}  ✓ 端口范围: 外部访问 LPMU:58000-58999 -> AGX:58000-58999 (TCP/UDP)${NC}"
    echo -e "${GREEN}  已配置端口转发${NC}"
else
    echo -e "${RED}  警告: 未找到互联网接口，端口转发可能不工作${NC}"
fi

# 6. 保存iptables规则
echo -e "${YELLOW}[6/6] 保存iptables规则...${NC}"
if command -v iptables-save &> /dev/null; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
    iptables-save > /etc/iptables.rules 2>/dev/null || \
    echo -e "${YELLOW}  无法保存规则（可能需要手动安装iptables-persistent）${NC}"
fi

# 显示当前配置
echo -e "\n${GREEN}=== 配置完成 ===${NC}"

echo -e "\n${GREEN}端口转发配置:${NC}"
echo -e "  SSH:        LPMU:58022 -> AGX:22"
echo -e "  端口范围:    LPMU:58000-58999 -> AGX:58000-58999 (TCP/UDP)"

echo -e "\n${GREEN}当前NAT规则:${NC}"
iptables -t nat -L PREROUTING -n -v --line-numbers | head -20
echo -e "\n${GREEN}当前POSTROUTING规则:${NC}"
iptables -t nat -L POSTROUTING -n -v --line-numbers | head -20

echo -e "\n${GREEN}当前FORWARD规则:${NC}"
iptables -L FORWARD -n -v --line-numbers | head -20

echo -e "\n${GREEN}IP转发状态:${NC}"
cat /proc/sys/net/ipv4/ip_forward

echo -e "\n${GREEN}活跃的网络接口:${NC}"
ip -brief addr show | grep -v "^lo"

echo -e "\n${GREEN}=== 配置已完成 ===${NC}"
echo -e "${YELLOW}端口转发说明:${NC}"
echo -e "  1. SSH 访问: ssh -p 58022 user@LPMU_IP"
echo -e "  2. 端口范围: LPMU:58000-58999 已映射到 AGX 相同端口"
echo -e "  3. 支持协议: TCP 和 UDP"
echo -e "${YELLOW}提示: 如果插入新的USB网卡，请重新运行此脚本${NC}"
