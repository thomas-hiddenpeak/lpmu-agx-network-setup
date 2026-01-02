#!/bin/bash
# 测试LPMU NAT配置

echo "=== LPMU NAT配置测试 ==="
echo ""

# 测试1: IP转发
echo "[1/4] 检查IP转发状态..."
forward_status=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$forward_status" = "1" ]; then
    echo "✓ IP转发已启用"
else
    echo "✗ IP转发未启用"
    exit 1
fi
echo ""

# 测试2: 网络接口
echo "[2/4] 检查网络接口..."
ip -brief addr show | grep -v "^lo"
echo ""

# 测试3: NAT规则
echo "[3/4] 检查NAT规则..."
nat_rules=$(iptables -t nat -L POSTROUTING -n | grep MASQUERADE | wc -l)
if [ "$nat_rules" -gt 0 ]; then
    echo "✓ NAT规则已配置 ($nat_rules 条规则)"
    iptables -t nat -L POSTROUTING -n -v
else
    echo "✗ 未找到NAT规则"
    exit 1
fi
echo ""

# 测试4: FORWARD规则
echo "[4/4] 检查FORWARD规则..."
iptables -L FORWARD -n -v
echo ""

# 测试互联网连接
echo "=== 测试LPMU互联网连接 ==="
if ping -c 3 -W 5 8.8.8.8 > /dev/null 2>&1; then
    echo "✓ LPMU可以访问互联网"
else
    echo "✗ LPMU无法访问互联网"
fi
echo ""

echo "=== 测试完成 ==="
