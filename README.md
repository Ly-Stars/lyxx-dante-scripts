# Dante 多IP固定出口脚本

自动部署 Dante SOCKS5 代理，支持多IP固定出口。

## 系统支持

- CentOS 7+
- Debian / Ubuntu

## 快速开始

### 1. 下载脚本

```bash
wget https://raw.githubusercontent.com/Ly-Stars/lyxx-dante-scripts/main/dante-multi-ip.sh -O dante-multi-ip.sh
chmod +x dante-multi-ip.sh
```

### 2. 部署

```bash
# 示例：3个IP，端口13688
./dante-multi-ip.sh \
    --ip=你的IP1:你的IP2:你的IP3 \
    --port=13688 \
    --user=用户名 \
    --passwd=密码
```

### 3. 参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `--ip` | 公网IP列表（用冒号分隔） | `--ip=1.1.1.1:2.2.2.2:3.3.3.3` |
| `--port` | 端口（默认13688） | `--port=13688` |
| `--user` | 用户名 | `--user=admin` |
| `--passwd` | 密码 | `--passwd=123456` |

## 卸载

```bash
./dante-multi-ip.sh --uninstall
```

## 使用示例

### 单IP

```bash
./dante-multi-ip.sh \
    --ip=你的公网IP \
    --port=13688 \
    --user=用户名 \
    --passwd=密码
```

### 3个IP

```bash
./dante-multi-ip.sh \
    --ip=公网IP1:公网IP2:公网IP3 \
    --port=13688 \
    --user=用户名 \
    --passwd=密码
```

## 客户端配置

| 配置项 | 值 |
|--------|-----|
| 代理类型 | SOCKS5 |
| 地址 | 你的公网IP |
| 端口 | 13688 |
| 用户名 | 部署时指定的用户名 |
| 密码 | 部署时指定的密码 |

### 测试命令

```bash
curl -x socks5://用户名:密码@IP:端口 ifconfig.me
```

## 工作原理

1. 自动检测每个公网IP对应的内网IP
2. 为每个IP创建独立的Dante实例
3. 使用iptables端口转发实现固定出口
4. 哪个IP进入，就从哪个IP出去

## 常见问题

### 1. 端口不通

检查防火墙：
```bash
firewall-cmd --list-ports
# 或
iptables -L -n
```

### 2. 无法访问外网

检查阿里云EIP是否购买出口带宽

### 3. 重启后失效

需要将iptables规则写入启动脚本

## GitHub

https://github.com/Ly-Stars/lyxx-dante-scripts
