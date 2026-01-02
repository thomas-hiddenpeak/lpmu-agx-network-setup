#!/bin/bash
# 测试网络连接脚本 - 用于AGX

echo "=== AGX网络连接测试 ==="
echo ""

# 测试1: 本地接口
echo "[1/5] 检查本地网络接口..."
ip addr show | grep "inet " | grep -v "127.0.0.1"
echo ""

# 测试2: 到LPMU的连接
echo "[2/5] 测试到LPMU网关的连接..."
if ping -c 3 -W 2 10.10.99.99; then
    echo "✓ 可以连接到LPMU"
else
    echo "✗ 无法连接到LPMU"
    exit 1
fi
echo ""

# 测试3: 互联网连接（IP）
echo "[3/5] 测试互联网连接（IP地址）..."
if ping -c 3 -W 5 8.8.8.8; then
    echo "✓ 可以连接到互联网"
else
    echo "✗ 无法连接到互联网"
    exit 1
fi
echo ""

# 测试4: DNS解析
echo "[4/5] 测试DNS解析..."
if ping -c 2 -W 5 google.com; then
    echo "✓ DNS解析正常"
else
    echo "✗ DNS解析失败"
fi
echo ""

# 测试5: 路由表
echo "[5/5] 检查路由配置..."
ip route show
echo ""

echo "=== 测试完成 ==="
