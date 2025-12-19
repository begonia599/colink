#!/bin/bash
set -e

# ========== CoLink 节点部署脚本 ==========
# 目标服务器配置（新加坡 MC 服务器）
TARGET_SERVER="51.79.218.253:25069"

# KCP 参数
CRYPT="aes-128"
MODE="fast3"
MTU="1350"
SNDWND="2048"
RCVWND="2048"
DATASHARD="10"
PARITYSHARD="3"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 检测系统架构
detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *)       log_error "不支持的架构: $ARCH" ;;
    esac
    log_info "检测到架构: $ARCH"
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    else
        log_error "仅支持 Linux 系统"
    fi
}

# 生成随机密钥
generate_key() {
    KEY=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)
    log_info "生成密钥: $KEY"
}

# 生成随机端口 (20000-30000)
generate_port() {
    PORT=$((RANDOM % 10000 + 20000))
    # 检查端口是否被占用
    while netstat -tuln 2>/dev/null | grep -q ":$PORT " || ss -tuln 2>/dev/null | grep -q ":$PORT "; do
        PORT=$((RANDOM % 10000 + 20000))
    done
    log_info "使用端口: $PORT"
}

# 获取公网 IP (强制 IPv4)
get_public_ip() {
    PUBLIC_IP=$(curl -4 -s --max-time 5 ifconfig.me || curl -4 -s --max-time 5 ipinfo.io/ip || curl -4 -s --max-time 5 icanhazip.com)
    if [[ -z "$PUBLIC_IP" ]]; then
        log_error "无法获取公网 IP"
    fi
    log_info "公网 IP: $PUBLIC_IP"
}

# 下载 kcptun
download_kcptun() {
    KCPTUN_VERSION="20241119"
    DOWNLOAD_URL="https://github.com/xtaci/kcptun/releases/download/v${KCPTUN_VERSION}/kcptun-${OS}-${ARCH}-${KCPTUN_VERSION}.tar.gz"
    
    log_info "下载 kcptun..."
    
    INSTALL_DIR="/opt/colink"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    curl -fsSL "$DOWNLOAD_URL" -o kcptun.tar.gz || log_error "下载失败"
    tar -xzf kcptun.tar.gz
    rm -f kcptun.tar.gz
    
    # kcptun 解压后是 server_linux_amd64 和 client_linux_amd64
    mv server_${OS}_${ARCH} kcptun-server 2>/dev/null || mv server_* kcptun-server 2>/dev/null
    chmod +x kcptun-server
    rm -f client_* # 不需要客户端
    
    log_info "kcptun 安装到 $INSTALL_DIR/kcptun-server"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # ufw (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        ufw allow $PORT/udp >/dev/null 2>&1 && log_info "ufw: 已开放 UDP $PORT"
    fi
    
    # firewalld (CentOS/RHEL)
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$PORT/udp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1 && log_info "firewalld: 已开放 UDP $PORT"
    fi
    
    # iptables
    if command -v iptables &> /dev/null; then
        iptables -C INPUT -p udp --dport $PORT -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p udp --dport $PORT -j ACCEPT 2>/dev/null && log_info "iptables: 已开放 UDP $PORT"
    fi
}

# 创建 systemd 服务
create_service() {
    log_info "创建 systemd 服务..."
    
    cat > /etc/systemd/system/colink-kcp.service << EOF
[Unit]
Description=CoLink KCP Tunnel Server
After=network.target

[Service]
Type=simple
ExecStart=/opt/colink/kcptun-server \\
    -t "$TARGET_SERVER" \\
    -l ":$PORT" \\
    -key "$KEY" \\
    -crypt "$CRYPT" \\
    -mode "$MODE" \\
    -mtu "$MTU" \\
    -sndwnd "$SNDWND" \\
    -rcvwnd "$RCVWND" \\
    -datashard "$DATASHARD" \\
    -parityshard "$PARITYSHARD" \\
    -nocomp
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable colink-kcp
    systemctl start colink-kcp
    
    sleep 2
    if systemctl is-active --quiet colink-kcp; then
        log_info "服务启动成功"
    else
        log_error "服务启动失败，请检查日志: journalctl -u colink-kcp"
    fi
}

# 输出配置信息
output_config() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}部署完成！请复制以下配置到 CoLink 客户端：${NC}"
    echo "=========================================="
    echo ""
    cat << EOF
{
  "server": "$PUBLIC_IP",
  "port": $PORT,
  "key": "$KEY",
  "crypt": "$CRYPT",
  "mode": "$MODE",
  "localPort": 25565
}
EOF
    echo ""
    echo "=========================================="
}

# 主流程
main() {
    echo ""
    echo "=========================================="
    echo "       CoLink 节点部署脚本"
    echo "=========================================="
    echo ""
    
    # 检查 root 权限
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 权限运行此脚本"
    fi
    
    detect_os
    detect_arch
    get_public_ip
    generate_key
    generate_port
    download_kcptun
    configure_firewall
    create_service
    output_config
}

main "$@"
