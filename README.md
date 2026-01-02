# LPMU和AGX网络配置指南

## 📋 目录

- [快速开始](#快速开始)
- [概述](#概述)
- [LPMU配置（网关）](#一lpmu配置作为网关)
- [AGX配置（客户端）](#二agx配置客户端)
- [测试网络](#三测试网络连接)
- [故障排查](#四故障排查)
- [目录结构](#目录结构)

## 🚀 快速开始

### LPMU 配置（3步完成）

```bash
# 1. 传输文件
scp -r lpmu/ user@10.10.99.99:~/network-setup/

# 2. SSH 连接并配置
ssh user@10.10.99.99
cd ~/network-setup/lpmu
chmod +x *.sh

# 3. 一键配置（智能路由 + NAT）
sudo ./setup-smart-route.sh
```

### AGX 配置（3步完成）

```bash
# 1. 传输文件
scp -r agx/ user@10.10.99.98:~/network-setup/

# 2. SSH 连接并配置
ssh user@10.10.99.98
cd ~/network-setup/agx
chmod +x *.sh

# 3. 配置网络（推荐 Netplan）
sudo ./setup-network-persistent-netplan.sh
```

### 测试连接

```bash
# 在 AGX 上测试
ping -c 3 10.10.99.99   # 测试网关
ping -c 3 8.8.8.8       # 测试互联网
ping -c 3 google.com    # 测试DNS
```

---

## 概述

本配置方案让AGX (10.10.99.98) 通过LPMU (10.10.99.99) 访问互联网。

### 网络拓扑
```
互联网
  ↓
LPMU (10.10.99.99)
  ├─ enp2s0 (固定接口) ← 连接AGX
  └─ WiFi/USB网卡 (动态) ← 连接互联网
       ↓
AGX (10.10.99.98)
```

### 智能路由特性

- ✓ **优先使用 enp2s0**：首选有线连接
- ✓ **自动故障转移**：enp2s0 失败时切换到 WiFi 等
- ✓ **自动恢复**：enp2s0 恢复后自动切换回来
- ✓ **自动配置 NAT**：一键完成路由和NAT配置
- ✓ **持续监控**：每 30 秒检查网络状态

## 一、LPMU配置（作为网关）

### 快速部署（推荐）

1. **将文件传输到LPMU**
   ```bash
   scp -r lpmu/ user@10.10.99.99:~/network-setup/
   ```

2. **SSH连接到LPMU**
   ```bash
   ssh user@10.10.99.99
   cd ~/network-setup/lpmu
   ```

3. **赋予执行权限**
   ```bash
   chmod +x *.sh
   ```

4. **执行智能路由配置（一键完成）**
   ```bash
   sudo ./setup-smart-route.sh
   ```
   
   这个脚本会自动：
   - ✓ 检测 enp2s0 是否可用
   - ✓ 如果不可用，自动选择其他可用接口
   - ✓ 配置最优默认路由
   - ✓ 测试互联网连接
   - ✓ **自动配置 NAT 和防火墙规则**

5. **在 AGX 上测试**
   ```bash
   ping 8.8.8.8
   ping google.com
   ```

### 安装为系统服务（推荐）

安装智能路由系统服务后，LPMU 重启后会自动：
- 选择最优网络接口
- 配置 NAT 和防火墙
- 持续监控网络状态
- 自动故障转移和恢复

```bash
# 安装智能路由服务
sudo ./install-smart-route-service.sh

# 启动服务
sudo systemctl start lpmu-smart-route.service
sudo systemctl start lpmu-smart-route-monitor.service

# 查看状态
sudo systemctl status lpmu-smart-route-monitor.service

# 查看实时日志
sudo journalctl -u lpmu-smart-route-monitor.service -f
```

### 手动配置（不推荐）

如果只需要配置 NAT 而不需要智能路由：

```bash
sudo ./setup-nat.sh
```

### 脚本说明

#### `setup-smart-route.sh`（推荐使用）
- 智能检测并选择最优网络接口
- 优先使用 enp2s0，失败时自动切换
- 配置路由表
- **自动调用 setup-nat.sh 配置 NAT**
- 测试互联网连接

#### `monitor-smart-route.sh`
- 持续监控网络状态（30秒间隔）
- 检测接口故障并自动切换
- enp2s0 恢复时自动切换回来
- 路由变更时自动重新配置 NAT

#### `setup-nat.sh`
- 启用 IP 转发
- 检测有互联网连接的接口
- 配置 NAT (MASQUERADE)
- 配置防火墙规则

#### `install-smart-route-service.sh`
- 将脚本安装为 systemd 服务
- 开机自动启动
- 自动监控网络变化

## 二、AGX配置（客户端）

### 快速部署

1. **将文件传输到AGX**
   ```bash
   scp -r agx/ user@10.10.99.98:~/network-setup/
   ```

2. **SSH连接到AGX**
   ```bash
   ssh user@10.10.99.98
   cd ~/network-setup/agx
   ```

3. **赋予执行权限**
   ```bash
   chmod +x *.sh
   ```

4. **检查并修改网络接口名称**
   
   查看当前接口：
   ```bash
   ip link show
   ```
   
   编辑脚本中的 `NETWORK_IFACE` 变量，改为实际接口名（如 `eth0`、`enP1p1s0`等）

5. **选择配置方式**

   **方式A: 临时配置（重启后失效）**
   ```bash
   sudo ./setup-network.sh
   ```

   **方式B: 使用NetworkManager（推荐，适用于有NetworkManager的系统）**
   ```bash
   sudo ./setup-network-persistent-nm.sh
   ```

   **方式C: 使用Netplan（推荐，适用于Ubuntu 18.04+）**
   ```bash
   sudo ./setup-network-persistent-netplan.sh
   ```

### 脚本说明

#### `setup-network.sh`
- 配置静态IP: 10.10.99.98/24
- 设置网关: 10.10.99.99
- 配置DNS服务器
- 测试网络连接
- **重启后失效**

#### `setup-network-persistent-nm.sh`
- 使用NetworkManager创建持久化连接
- 重启后自动生效
- 适用于：Ubuntu Desktop, RHEL, CentOS等

#### `setup-network-persistent-netplan.sh`
- 使用Netplan配置
- 创建 `/etc/netplan/01-lpmu-static.yaml`
- 适用于：Ubuntu 18.04+, Ubuntu Server

## 三、测试网络连接

### 在AGX上测试

```bash
# 1. 测试到LPMU的连接
ping -c 3 10.10.99.99

# 2. 测试互联网连接（IP）
ping -c 3 8.8.8.8

# 3. 测试DNS解析
ping -c 3 google.com

# 4. 检查路由
ip route show

# 5. 检查DNS配置
cat /etc/resolv.conf
```

### 在LPMU上检查

```bash
# 1. 检查IP转发是否启用
cat /proc/sys/net/ipv4/ip_forward
# 应该显示 1

# 2. 检查NAT规则
sudo iptables -t nat -L POSTROUTING -n -v

# 3. 检查FORWARD规则
sudo iptables -L FORWARD -n -v

# 4. 查看当前网络接口
ip -brief addr show
```

## 四、故障排查

### AGX无法连接到互联网

1. **检查AGX到LPMU的连接**
   ```bash
   ping 10.10.99.99
   ```
   如果失败，检查物理连接和AGX的IP配置

2. **在LPMU上检查IP转发**
   ```bash
   cat /proc/sys/net/ipv4/ip_forward
   ```
   应该显示 1

3. **在LPMU上检查NAT规则**
   ```bash
   sudo iptables -t nat -L POSTROUTING -n -v
   ```
   应该看到MASQUERADE规则

4. **在LPMU上测试互联网连接**
   ```bash
   ping -c 3 8.8.8.8
   ```
   确保LPMU本身可以访问互联网

5. **在AGX上检查路由**
   ```bash
   ip route show
   ```
   应该有 `default via 10.10.99.99`

### USB网卡插入后无法使用

1. **在LPMU上检查新接口是否被识别**
   ```bash
   ip link show
   ```

2. **重新运行NAT配置**
   ```bash
   sudo /tmp/network-setup/lpmu/setup-nat.sh
   ```

3. **如果安装了监控服务，检查日志**
   ```bash
   sudo journalctl -u lpmu-nat-monitor.service -n 50
   ```

### DNS解析失败

1. **检查AGX的DNS配置**
   ```bash
   cat /etc/resolv.conf
   ```

2. **手动测试DNS**
   ```bash
   nslookup google.com 8.8.8.8
   ```

3. **检查LPMU是否阻止了DNS流量**
   ```bash
   sudo iptables -L FORWARD -n -v
   ```

## 五、目录结构

```
network-setup/
├── README.md                    # 本文件（完整文档）
├── lpmu/                        # LPMU（网关）脚本
│   ├── setup-smart-route.sh    # 智能路由配置（推荐使用）
│   ├── monitor-smart-route.sh  # 路由监控
│   ├── setup-nat.sh            # NAT配置
│   ├── install-smart-route-service.sh  # 安装系统服务
│   ├── install-persistent.sh   # iptables持久化
│   └── test-nat.sh             # 测试NAT
└── agx/                         # AGX（客户端）脚本
    ├── setup-network.sh         # 临时网络配置
    ├── setup-network-persistent-nm.sh    # NetworkManager持久化
    ├── setup-network-persistent-netplan.sh  # Netplan持久化
    └── test-connection.sh       # 测试连接
```

## 六、卸载配置

### LPMU

```bash
# 停止并禁用服务
sudo systemctl stop lpmu-nat-monitor.service
sudo systemctl stop lpmu-nat.service
sudo systemctl disable lpmu-nat-monitor.service
sudo systemctl disable lpmu-nat.service

# 删除服务文件
sudo rm /etc/systemd/system/lpmu-nat*.service
sudo rm /usr/local/bin/lpmu-*.sh

# 清除iptables规则
sudo iptables -t nat -F
sudo iptables -F FORWARD

# 禁用IP转发
sudo sysctl -w net.ipv4.ip_forward=0
```

### AGX

```bash
# 如果使用NetworkManager
sudo nmcli connection delete lpmu-static

# 如果使用Netplan
sudo rm /etc/netplan/01-lpmu-static.yaml
sudo netplan apply

# 恢复DHCP（如果需要）
sudo dhclient
```

## 七、注意事项

1. **安全性**：此配置允许AGX通过LPMU访问互联网，请确保两台机器的安全

2. **防火墙**：如果LPMU或AGX有其他防火墙规则，可能需要调整

3. **网络接口名称**：不同系统的网络接口命名可能不同，请根据实际情况修改脚本

4. **权限**：所有配置脚本都需要root权限（sudo）

5. **优先接口配置**：如需修改优先接口，编辑 `setup-smart-route.sh` 第7行：
   ```bash
   PRIMARY_IFACE="enp2s0"  # 改为你的接口名
   ```

## 八、常用命令

```bash
# LPMU - 查看NAT规则
sudo iptables -t nat -L -n -v

# LPMU - 查看FORWARD规则
sudo iptables -L FORWARD -n -v

# LPMU - 重启NAT配置
sudo systemctl restart lpmu-nat.service

# AGX - 查看网络配置
ip addr show
ip route show

# AGX - 测试连接
ping -c 3 10.10.99.99  # 测试网关
ping -c 3 8.8.8.8      # 测试互联网
ping -c 3 google.com   # 测试DNS

# 查看实时日志
sudo journalctl -u lpmu-nat-monitor.service -f
```
