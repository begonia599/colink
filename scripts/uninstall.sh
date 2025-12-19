#!/bin/bash

# ========== CoLink 节点卸载脚本 ==========

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo ""
echo "=========================================="
echo "       CoLink 节点卸载脚本"
echo "=========================================="
echo ""

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} 请使用 root 权限运行此脚本"
    exit 1
fi

# 获取当前端口（用于关闭防火墙）
if [[ -f /etc/systemd/system/colink-kcp.service ]]; then
    PORT=$(grep -oP '(?<=-l ":)\d+' /etc/systemd/system/colink-kcp.service)
fi

# 停止并禁用服务
if systemctl is-active --quiet colink-kcp 2>/dev/null; then
    log_info "停止服务..."
    systemctl stop colink-kcp
fi

if systemctl is-enabled --quiet colink-kcp 2>/dev/null; then
    log_info "禁用服务..."
    systemctl disable colink-kcp
fi

# 删除服务文件
if [[ -f /etc/systemd/system/colink-kcp.service ]]; then
    log_info "删除服务文件..."
    rm -f /etc/systemd/system/colink-kcp.service
    systemctl daemon-reload
fi

# 删除安装目录
if [[ -d /opt/colink ]]; then
    log_info "删除安装目录 /opt/colink..."
    rm -rf /opt/colink
fi

# 关闭防火墙端口
if [[ -n "$PORT" ]] && command -v ufw &> /dev/null; then
    log_info "关闭防火墙端口 UDP $PORT..."
    ufw delete allow $PORT/udp >/dev/null 2>&1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}卸载完成！${NC}"
echo "=========================================="
echo ""
