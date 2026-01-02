#!/bin/bash

# 智能路由配置脚本
# 优先使用 enp2s0，如果无法联网则自动切换到其他接口

set -e

PRIMARY_IFACE="enp2s0"
TEST_HOST="8.8.8.8"
TIMEOUT=3

echo "=== LPMU 智能路由配置 ==="
echo ""

# 获取接口的网关
get_gateway() {
    local iface=$1
    ip route show dev "$iface" | grep -oP 'default via \K[0-9.]+' | head -1
}

# 测试接口是否能访问互联网
test_internet() {
    local iface=$1
    local gateway=$2
    
    if [ -z "$gateway" ]; then
        return 1
    fi
    
    # 通过特定接口 ping 测试
    ping -c 2 -W $TIMEOUT -I "$iface" "$TEST_HOST" &>/dev/null
    return $?
}

# 获取所有有网关的接口
get_all_interfaces_with_gateway() {
    ip route | grep '^default' | awk '{print $5}' | sort -u
}

echo "1. 检测所有可用接口..."
INTERFACES=$(get_all_interfaces_with_gateway)
echo "   发现接口: $INTERFACES"
echo ""

# 测试主接口
echo "2. 测试主接口 $PRIMARY_IFACE..."
PRIMARY_GATEWAY=$(get_gateway "$PRIMARY_IFACE")

if [ -n "$PRIMARY_GATEWAY" ]; then
    echo "   网关: $PRIMARY_GATEWAY"
    if test_internet "$PRIMARY_IFACE" "$PRIMARY_GATEWAY"; then
        echo "   ✓ $PRIMARY_IFACE 可以访问互联网"
        CHOSEN_IFACE="$PRIMARY_IFACE"
        CHOSEN_GATEWAY="$PRIMARY_GATEWAY"
    else
        echo "   ✗ $PRIMARY_IFACE 无法访问互联网"
    fi
else
    echo "   ✗ $PRIMARY_IFACE 没有配置网关"
fi

echo ""

# 如果主接口不可用，尝试其他接口
if [ -z "$CHOSEN_IFACE" ]; then
    echo "3. 主接口不可用，测试备用接口..."
    
    for iface in $INTERFACES; do
        if [ "$iface" = "$PRIMARY_IFACE" ]; then
            continue
        fi
        
        echo "   测试 $iface..."
        gateway=$(get_gateway "$iface")
        
        if [ -n "$gateway" ]; then
            echo "     网关: $gateway"
            if test_internet "$iface" "$gateway"; then
                echo "     ✓ $iface 可以访问互联网"
                CHOSEN_IFACE="$iface"
                CHOSEN_GATEWAY="$gateway"
                break
            else
                echo "     ✗ $iface 无法访问互联网"
            fi
        fi
    done
    echo ""
fi

# 如果找到可用接口，配置路由
if [ -n "$CHOSEN_IFACE" ]; then
    echo "4. 配置路由 - 使用接口: $CHOSEN_IFACE (网关: $CHOSEN_GATEWAY)"
    
    # 删除所有默认路由
    echo "   删除旧的默认路由..."
    while sudo ip route del default 2>/dev/null; do
        :
    done
    
    # 添加选定的默认路由（最高优先级）
    echo "   添加新的默认路由..."
    sudo ip route add default via "$CHOSEN_GATEWAY" dev "$CHOSEN_IFACE" metric 100
    
    # 如果选定的不是主接口，为主接口添加低优先级路由（以便后续恢复）
    if [ "$CHOSEN_IFACE" != "$PRIMARY_IFACE" ] && [ -n "$PRIMARY_GATEWAY" ]; then
        echo "   为 $PRIMARY_IFACE 添加备用路由..."
        sudo ip route add default via "$PRIMARY_GATEWAY" dev "$PRIMARY_IFACE" metric 200 2>/dev/null || true
    fi
    
    echo ""
    echo "5. 当前路由表："
    ip route show
    
    echo ""
    echo "6. 测试互联网连接："
    if ping -c 3 "$TEST_HOST"; then
        echo ""
        echo "✓ 互联网连接正常！"
        echo ""
        echo "当前使用接口: $CHOSEN_IFACE"
        echo "网关: $CHOSEN_GATEWAY"
        
        # 自动配置 NAT
        echo ""
        echo "7. 自动配置 NAT..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -f "$SCRIPT_DIR/setup-nat.sh" ]; then
            sudo "$SCRIPT_DIR/setup-nat.sh"
        else
            echo "   警告: 找不到 setup-nat.sh，请手动运行:"
            echo "   sudo ./setup-nat.sh"
        fi
    else
        echo ""
        echo "✗ 互联网连接失败"
        exit 1
    fi
else
    echo "✗ 错误：没有找到可用的互联网连接"
    echo ""
    echo "当前路由表："
    ip route show
    exit 1
fi

echo ""
echo "=== 配置完成 ==="
