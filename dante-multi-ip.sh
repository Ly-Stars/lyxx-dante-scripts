#!/bin/bash
#
# Dante SOCKS5 多IP固定出口自动部署脚本
# 基于Lozy脚本修改，支持多IP独立出口
#

VERSION="1.0"
DEFAULT_PORT="1368"
DEFAULT_USER=""
DEFAULT_PASSWD=""

# 检查root
if [ $(id -u) != "0" ]; then
    echo "Error: Please use root to run this script"
    exit 1
fi

# 检查参数
show_help() {
    echo "Dante Multi-IP Auto Install Script v${VERSION}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --ip=IP1:IP2:IP3    Public IPs (colon separated)"
    echo "  --port=PORT         SOCKS5 port (default: 13688)"
    echo "  --user=USERNAME     Auth username"
    echo "  --passwd=PASSWORD   Auth password"
    echo "  --uninstall         Uninstall"
    echo ""
    echo "Example:"
    echo "  $0 --ip=1.2.3.4:5.6.7.8:9.10.11.12 --port=1368 --user=myuser --passwd=mypass"
    exit 1
}

# 解析参数
for param in $@; do
    case "${param}" in
        --ip=*)
            ip_list=$(echo "${param#--ip=}" | tr ':' ' ')
            ;;
        --port=*)
            DEFAULT_PORT="${param#--port=}"
            ;;
        --user=*)
            DEFAULT_USER="${param#--user=}"
            ;;
        --passwd=*)
            DEFAULT_PASSWD="${param#--passwd=}"
            ;;
        --uninstall)
            uninstall=1
            ;;
        --help|-h)
            show_help
            ;;
    esac
done

# 卸载
if [ "$uninstall" == "1" ]; then
    echo "Uninstalling..."
    pkill -9 sockd 2>/dev/null
    rm -rf /etc/danted*
    rm -f /etc/systemd/system/danted@.service
    systemctl daemon-reload
    echo "Done."
    exit 0
fi

# 检查必要参数
if [ -z "$ip_list" ]; then
    echo "Error: --ip is required"
    show_help
fi

if [ -z "$DEFAULT_USER" ] || [ -z "$DEFAULT_PASSWD" ]; then
    echo "Error: --user and --passwd are required"
    show_help
fi

echo "========================================="
echo "Dante Multi-IP Install v${VERSION}"
echo "========================================="
echo "IPs: $ip_list"
echo "Port: $DEFAULT_PORT"
echo "User: $DEFAULT_USER"
echo "========================================="

# 检测系统
if [ -s "/etc/os-release" ]; then
    os_name=$(sed -n 's/PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release)
    if [ -n "$(echo ${os_name} | grep -Ei 'CentOS')" ]; then
        SYSTEM="centos"
    elif [ -n "$(echo ${os_name} | grep -Ei 'Debian|Ubuntu')" ]; then
        SYSTEM="debian"
    fi
fi

echo "System: $SYSTEM"

# 安装依赖
if [ "$SYSTEM" == "centos" ]; then
    yum install -y gcc make libwrap-devel pam-devel wget
elif [ "$SYSTEM" == "debian" ]; then
    apt-get update -qq
    apt-get install -y -qq gcc make libwrap0-dev libpam0g-dev wget
fi

# 编译安装Dante
cd /tmp
wget -q https://www.inet.no/dante/files/dante-1.4.3.tar.gz
tar xzf dante-1.4.3.tar.gz
cd dante-1.4.3

./configure --prefix=/etc/danted && make -j1 && make install

# 创建用户
useradd -M -s /sbin/nologin ${DEFAULT_USER} 2>/dev/null
echo "${DEFAULT_USER}:${DEFAULT_PASSWD}" | chpasswd

# 生成配置文件 (每个IP一个实例)
instance=1
for ip in $ip_list; do
    # 获取对应的内网IP
    internal_ip=$(ip addr | grep -B1 "$ip" | grep inet | awk '{print $2}' | cut -d'/' -f1)
    
    if [ -z "$internal_ip" ]; then
        echo "Warning: Cannot find internal IP for $ip, skipping..."
        continue
    fi
    
    cat > /etc/danted-${instance}.conf << EOF
logoutput: /var/log/danted-${instance}.log
internal: ${internal_ip} port = ${DEFAULT_PORT}
external: ${internal_ip}
socksmethod: username none
clientmethod: none
user.privileged: root
user.notprivileged: nobody

client pass { from: 0.0.0.0/0 to: 0.0.0.0/0 }
socks pass { from: 0.0.0.0/0 to: 0.0.0.0/0 }
EOF

    echo "Config $instance: Public IP $ip -> Internal IP $internal_ip"
    instance=$((instance + 1))
done

# systemd服务
cat > /etc/systemd/system/danted@.service << 'EOF'
[Unit]
Description=Dante SOCKS daemon (instance %i)
After=network.target

[Service]
Type=forking
PIDFile=/var/run/danted%i.pid
ExecStart=/etc/danted/sbin/sockd -f /etc/danted-%i.conf -D
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# 启动所有实例
for i in $(seq 1 $((instance-1))); do
    systemctl enable danted@${i}
    systemctl restart danted@${i}
done

sleep 2

# 配置端口转发 (iptables)
iptables -t nat -F PREROUTING 2>/dev/null
instance=1
for ip in $ip_list; do
    internal_ip=$(ip addr | grep -B1 "$ip" | grep inet | awk '{print $2}' | cut -d'/' -f1)
    [ -z "$internal_ip" ] && continue
    iptables -t nat -A PREROUTING -d $ip -p tcp --dport ${DEFAULT_PORT} -j DNAT --to-destination ${internal_ip}:${DEFAULT_PORT}
    echo "Port forward: $ip:${DEFAULT_PORT} -> ${internal_ip}:${DEFAULT_PORT}"
done

# 保存iptables
if [ "$SYSTEM" == "centos" ]; then
    service iptables save 2>/dev/null
fi

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo "Port: ${DEFAULT_PORT}"
echo "User: ${DEFAULT_USER}"
echo "Pass: ${DEFAULT_PASSWD}"
echo ""
echo "Test commands:"
for ip in $ip_list; do
    echo "  curl -x socks5://${ip}:${DEFAULT_PORT} ifconfig.me"
done
