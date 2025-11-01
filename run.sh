#!/bin/sh
set -e  # 遇到错误立即退出

# 写死的配置参数
domain="99gtr.com"
proxyPath="v2god"
cloudflareApiToken="I_ULOfwplN6EInxBN1SNWA6Jh6nkyqLsVu-Fiwb0"
naive_user="aizhihuxiao"
naive_passwd="ecf9a79e-2ff6-4eb7-9e4b-02bffcab5881"

# Reality 配置参数
enable_reality="true"  # 是否启用 Reality (true/false)
reality_uuid="${naive_passwd}"  # Reality UUID（复用 naive 密码）
reality_sni="${domain}"  # Reality SNI（使用主域名）
reality_server_name="www.microsoft.com"  # Reality 伪装域名（握手目标）

echo "========================================="
echo "开始部署 Caddy NaiveProxy + sing-box 服务"
echo "域名: ${domain}"
if [ "$enable_reality" = "true" ]; then
    echo "Reality: 已启用"
fi
echo "========================================="

# 设置时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" > /etc/timezone

# 更新系统并安装依赖
echo "📦 安装系统依赖..."
apt update && apt upgrade -y
apt install -y curl ca-certificates gnupg ntpdate

# 同步时间
echo "� 同步系统时间..."
ntpdate -u pool.ntp.org || ntpdate -u time.google.com || ntpdate -u time.cloudflare.com || echo "⚠️  时间同步失败，继续部署..."

# 安装 Docker（如果未安装）
if ! command -v docker &> /dev/null; then
    echo "🐳 安装 Docker..."
    curl -fsSL https://get.docker.com | sh
fi

# 确保 Docker 服务正在运行
echo "✅ 检查 Docker 服务..."
systemctl daemon-reload 2>/dev/null || true
systemctl enable docker 2>/dev/null || true
systemctl start docker 2>/dev/null || true
sleep 2

# 验证 Docker 可用 - 直接用 docker ps 判断
if docker ps >/dev/null 2>&1; then
    echo "✅ Docker 服务正常运行"
else
    echo "❌ Docker 服务启动失败"
    exit 1
fi

# 检测并清理旧容器
echo "🔍 检测并清理旧容器..."
# 停止并删除 caddy 容器（无论什么镜像）
docker stop caddy 2>/dev/null || true
docker rm caddy 2>/dev/null || true

# 停止并删除 watchtower 容器
docker stop watchtower 2>/dev/null || true
docker rm watchtower 2>/dev/null || true

# 清理旧镜像
docker rmi lingex/caddy-cf-naive:latest 2>/dev/null || true
docker rmi lingex/caddy-cf-naive 2>/dev/null || true

echo "✅ 容器清理完成"

# 创建目录结构
echo "📁 创建目录..."
mkdir -p "$PWD/caddy/data" "$PWD/caddy/config" "$PWD/caddy/logs"
mkdir -p "$PWD/singbox/logs"
# 设置目录权限，允许容器写入
chmod -R 777 "$PWD/caddy/data" "$PWD/caddy/config" "$PWD/caddy/logs"
chmod -R 777 "$PWD/singbox"

# 生成 Caddyfile
echo "📝 生成 Caddyfile..."

if [ -f "./caddy/Caddyfile" ]; then
    echo "⚠️  检测到已存在的 Caddyfile，将被覆盖"
    mv ./caddy/Caddyfile ./caddy/Caddyfile.bak.$(date +%s)
fi

# 根据是否启用 Reality 选择配置模板
if [ "$enable_reality" = "true" ]; then
    if [ -f "Caddyfile.reality.example" ]; then
        echo "📝 使用 Reality + 多CA 支持配置模板..."
        cp Caddyfile.reality.example ./caddy/Caddyfile
    else
        echo "⚠️  未找到 Reality 配置模板，使用默认模板"
        cp Caddyfile.multi-ca.example ./caddy/Caddyfile 2>/dev/null || cp Caddyfile.example ./caddy/Caddyfile
    fi
else
    # 使用新的多CA支持的配置模板（如果存在）
    if [ -f "Caddyfile.multi-ca.example" ]; then
        echo "📝 使用多CA支持配置模板..."
        cp Caddyfile.multi-ca.example ./caddy/Caddyfile
    else
        cp Caddyfile.example ./caddy/Caddyfile
    fi
fi

sed -i "s/domain/${domain}/g" ./caddy/Caddyfile
sed -i "s/proxyPath/${proxyPath}/g" ./caddy/Caddyfile
sed -i "s/cloudflareApiToken/${cloudflareApiToken}/g" ./caddy/Caddyfile
sed -i "s/naive_user/${naive_user}/g" ./caddy/Caddyfile
sed -i "s/naive_passwd/${naive_passwd}/g" ./caddy/Caddyfile

echo "✅ Caddyfile 生成完成"
echo ""
echo "📋 配置预览："
head -3 ./caddy/Caddyfile
echo "..."

# 生成 sing-box Reality 配置（如果启用）
if [ "$enable_reality" = "true" ]; then
    echo ""
    echo "🔐 生成 sing-box Reality 配置..."
    
    # 使用预定义的 UUID（与 naive 密码一致）
    REALITY_UUID="${reality_uuid}"
    
    # 生成 Reality 密钥对
    if ! command -v docker &> /dev/null; then
        echo "⚠️  Docker 未安装，使用默认密钥"
        REALITY_PRIVATE_KEY="YJnovvjJxsWQ6JKdDPqBjUs00dDs_6b3k1R5VEssAEw"
        REALITY_PUBLIC_KEY="eSyY2BcdvGOJxglH4zJJGM4iCPPJPQf7MFu1ItHkxAg"
        REALITY_SHORT_ID=$(cat /dev/urandom 2>/dev/null | tr -dc 'a-f0-9' | fold -w 8 | head -n 1 || echo "0123abcd")
    else
        # 使用临时容器生成密钥对
        echo "📝 使用 sing-box 生成 Reality 密钥对..."
        KEYS=$(docker run --rm aizhihuxiao/caddy-nv:latest sing-box generate reality-keypair 2>/dev/null || echo "")
        
        if [ -z "$KEYS" ]; then
            echo "⚠️  密钥生成失败，使用默认密钥"
            REALITY_PRIVATE_KEY="YJnovvjJxsWQ6JKdDPqBjUs00dDs_6b3k1R5VEssAEw"
            REALITY_PUBLIC_KEY="eSyY2BcdvGOJxglH4zJJGM4iCPPJPQf7MFu1ItHkxAg"
            REALITY_SHORT_ID=$(cat /dev/urandom 2>/dev/null | tr -dc 'a-f0-9' | fold -w 8 | head -n 1 || echo "0123abcd")
        else
            REALITY_PRIVATE_KEY=$(echo "$KEYS" | grep "PrivateKey" | awk '{print $2}')
            REALITY_PUBLIC_KEY=$(echo "$KEYS" | grep "PublicKey" | awk '{print $2}')
            REALITY_SHORT_ID=$(cat /dev/urandom 2>/dev/null | tr -dc 'a-f0-9' | fold -w 8 | head -n 1 || echo "0123abcd")
        fi
    fi
    
    # 生成 sing-box 配置文件
    if [ -f "singbox-config.json.example" ]; then
        cp singbox-config.json.example ./singbox/config.json
        sed -i "s/REALITY_UUID/${REALITY_UUID}/g" ./singbox/config.json
        sed -i "s/REALITY_PRIVATE_KEY/${REALITY_PRIVATE_KEY}/g" ./singbox/config.json
        sed -i "s/REALITY_SHORT_ID/${REALITY_SHORT_ID}/g" ./singbox/config.json
        sed -i "s/REALITY_SERVER_NAME/${reality_server_name}/g" ./singbox/config.json
        echo "✅ sing-box 配置生成完成"
        
        # 保存 Reality 配置信息
        cat > ./singbox/reality-info.txt << EOF
Reality 配置信息
生成时间: $(date)
========================================

服务器信息:
域名: ${domain}
端口: 443 (与 NaiveProxy 共享)
Reality SNI: ${reality_sni}
握手伪装域名: ${reality_server_name}

密钥信息:
UUID: ${REALITY_UUID} (与 NaiveProxy 密码一致)
Private Key: ${REALITY_PRIVATE_KEY}
Public Key: ${REALITY_PUBLIC_KEY}
Short ID: ${REALITY_SHORT_ID}

========================================
工作原理:
1. sing-box 监听 443 端口
2. Reality 协议流量由 sing-box 处理
3. 非 Reality 流量自动 fallback 到 Caddy (NaiveProxy)
4. UUID 与 NaiveProxy 密码统一管理

客户端配置:
- 地址: ${domain}
- 端口: 443
- UUID: ${REALITY_UUID}
- Public Key: ${REALITY_PUBLIC_KEY}
- Short ID: ${REALITY_SHORT_ID}
- SNI: ${reality_sni}
- Server Name: ${reality_server_name}
- Flow: xtls-rprx-vision
========================================
EOF
        chmod 600 ./singbox/reality-info.txt
        echo "📝 Reality 配置信息已保存到: ./singbox/reality-info.txt"
    else
        echo "⚠️  未找到 sing-box 配置模板"
    fi
fi

# 启动 Caddy 容器（使用新镜像）
echo "🚀 启动 Caddy 容器..."

# 根据是否启用 Reality 调整容器启动参数
if [ "$enable_reality" = "true" ] && [ -f "./singbox/config.json" ]; then
    docker run -d --name caddy \
        --restart=always \
        --net=host \
        --log-opt max-size=10m \
        --log-opt max-file=3 \
        -v $PWD/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
        -v $PWD/caddy/data:/data/caddy \
        -v $PWD/caddy/config:/config \
        -v $PWD/caddy/logs:/var/log/caddy \
        -v $PWD/singbox/config.json:/etc/sing-box/config.json:ro \
        -v $PWD/singbox/logs:/var/log/sing-box \
        aizhihuxiao/caddy-nv:latest
    echo "✅ Caddy + sing-box 容器启动完成"
else
    docker run -d --name caddy \
        --restart=always \
        --net=host \
        --log-opt max-size=10m \
        --log-opt max-file=3 \
        -v $PWD/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
        -v $PWD/caddy/data:/data/caddy \
        -v $PWD/caddy/config:/config \
        -v $PWD/caddy/logs:/var/log/caddy \
        aizhihuxiao/caddy-nv:latest
    echo "✅ Caddy 容器启动完成（仅 NaiveProxy）"
fi

# 检查 Caddy 启动状态
echo "⏳ 等待 Caddy 启动..."
sleep 5
if docker ps | grep -q caddy; then
    echo "✅ Caddy 容器启动成功"
    docker logs caddy --tail 20
    
    # 智能证书申请 - 多CA自动切换
    echo ""
    echo "🔐 开始智能证书申请（支持多CA自动切换）..."
    if [ -f "./cert-manager.sh" ]; then
        chmod +x ./cert-manager.sh
        export CADDY_DIR="$PWD/caddy"
        export CONTAINER_NAME="caddy"
        
        # 运行智能证书申请脚本
        if ./cert-manager.sh; then
            echo "✅ 证书申请成功"
        else
            echo "⚠️  证书申请可能失败，请检查日志"
            echo "💡 提示: 可以稍后手动运行 ./cert-manager.sh 重试"
        fi
    else
        echo "⚠️  未找到 cert-manager.sh，使用默认证书申请方式"
        echo "💡 等待Caddy自动申请证书（使用默认Let's Encrypt）..."
        sleep 30
    fi
else
    echo "❌ Caddy 容器启动失败，查看日志:"
    docker logs caddy
    exit 1
fi

# 启动 Watchtower 自动更新
echo "🔄 启动 Watchtower..."
docker run -d --name watchtower \
    --restart=unless-stopped \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower --cleanup --interval 86400

# 开启 BBR 和性能优化
echo "🚄 配置网络性能优化..."
modprobe tcp_bbr 2>/dev/null || echo "⚠️  BBR 模块加载失败"

# 检查 sysctl.conf 是否已包含配置，避免重复添加
if ! grep -q "# BBR 加速" /etc/sysctl.conf; then
cat >> /etc/sysctl.conf << EOF

# BBR 加速
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# TCP 性能优化
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_notsent_lowat=16384

# 连接队列优化
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=8192
net.core.netdev_max_backlog=16384

# 大缓冲区 - 提升高带宽性能
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.ipv4.tcp_mem=786432 1048576 26777216

# TIME_WAIT 快速回收
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15

# 保持连接活跃
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=3

# IP 转发（如果需要）
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
else
    echo "⚠️  网络优化配置已存在，跳过添加"
fi

sysctl -p > /dev/null

# 验证优化
echo "✅ 网络优化已应用"
sysctl net.ipv4.tcp_congestion_control
sysctl net.ipv4.tcp_fastopen

# 禁用系统防火墙（使用云防火墙）
echo "🔥 禁用系统防火墙..."
if command -v ufw &> /dev/null; then
    ufw --force disable
    systemctl disable ufw 2>/dev/null || true
    echo "✅ UFW 防火墙已禁用"
fi

if command -v firewalld &> /dev/null; then
    systemctl stop firewalld 2>/dev/null || true
    systemctl disable firewalld 2>/dev/null || true
    echo "✅ Firewalld 已禁用"
fi

# 清理可能存在的 iptables 规则
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "✅ iptables 规则已清空"

echo ""
echo "========================================="
echo "✅ 部署完成！"
echo "========================================="
echo "域名: ${domain}"
echo "代理路径: /${proxyPath}"
echo "Naive 用户: ${naive_user}"
echo ""
if [ "$enable_reality" = "true" ] && [ -f "./singbox/reality-info.txt" ]; then
    echo "🔐 Reality 已启用 (443端口共享)"
    echo "Reality UUID: ${REALITY_UUID}"
    echo "Reality Public Key: ${REALITY_PUBLIC_KEY}"
    echo ""
    echo "📋 完整 Reality 配置: ./singbox/reality-info.txt"
    echo ""
    echo "⚠️  架构说明："
    echo "   1. sing-box 监听 443 端口"
    echo "   2. Reality 流量由 sing-box 直接处理"
    echo "   3. 其他流量自动 fallback 到 Caddy (NaiveProxy)"
    echo "   4. 两个协议共享同一个域名和端口"
    echo ""
fi
echo "⚠️  请在云服务商控制台配置安全组："
echo "   - 开放 22/tcp  (SSH)"
echo "   - 开放 80/tcp  (HTTP)"
echo "   - 开放 443/tcp (HTTPS - NaiveProxy + Reality 共享)"
echo ""
echo "📊 查看日志: docker logs -f caddy"
echo "🔍 检查状态: docker ps"
echo "🛑 停止服务: docker stop caddy"
echo "🔄 重启服务: docker restart caddy"
echo "========================================"