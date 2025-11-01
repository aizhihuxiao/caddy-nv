# 构建阶段 - 使用 Alpine 基础镜像
FROM golang:1.23-alpine AS builder

# 构建参数 - 使用最新版本
ARG CADDY_VERSION=latest
ARG NAIVE_VERSION=naive
ARG XCADDY_VERSION=v0.4.4
ARG SINGBOX_VERSION=latest

# 设置 GOTOOLCHAIN 允许自动下载更新的 Go 版本
ENV GOTOOLCHAIN=auto

# 安装构建依赖
RUN apk add --no-cache git ca-certificates curl

# 安装 xcaddy
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@${XCADDY_VERSION}

# 构建自定义 Caddy，使用最新的 NaiveProxy 核心 + layer4 插件
RUN xcaddy build ${CADDY_VERSION} \
    --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@${NAIVE_VERSION} \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/mholt/caddy-l4 \
    --output /usr/bin/caddy

# 下载 sing-box 最新版本
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; elif [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi && \
    echo "Downloading sing-box for ${ARCH}..." && \
    SINGBOX_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/^v//') && \
    echo "Latest version: ${SINGBOX_VERSION}" && \
    curl -Lo /tmp/sing-box.tar.gz "https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz" && \
    tar -xzf /tmp/sing-box.tar.gz -C /tmp && \
    mv /tmp/sing-box-*/sing-box /usr/bin/sing-box && \
    chmod +x /usr/bin/sing-box && \
    rm -rf /tmp/sing-box*

# 运行阶段 - 使用固定版本
FROM alpine:3.19

# 元数据
LABEL maintainer="caddy-naiveproxy" \
      description="Caddy with NaiveProxy (latest) and Cloudflare DNS" \
      version="1.0"

# 一次性安装所有依赖并创建目录，减少镜像层
RUN apk add --no-cache \
        ca-certificates \
        libcap \
        tzdata \
        wget \
        jq && \
    # 设置时区
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    # 创建非 root 用户
    addgroup -g 1000 caddy && \
    adduser -D -u 1000 -G caddy caddy && \
    # 创建目录结构
    mkdir -p \
        /config/caddy \
        /data/caddy \
        /var/log/caddy \
        /etc/caddy \
        /etc/sing-box \
        /var/log/sing-box && \
    # 设置目录权限
    chown -R caddy:caddy /config /data /var/log/caddy /etc/caddy /etc/sing-box /var/log/sing-box

# 复制编译好的 caddy 和 sing-box
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY --from=builder /usr/bin/sing-box /usr/bin/sing-box

# 设置权限并验证版本
RUN setcap cap_net_bind_service=+ep /usr/bin/caddy && \
    setcap cap_net_bind_service=+ep /usr/bin/sing-box && \
    chmod +x /usr/bin/caddy /usr/bin/sing-box && \
    caddy version && \
    caddy list-modules | grep forward_proxy && \
    sing-box version

# 环境变量
ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data \
    TZ=Asia/Shanghai

# 暴露端口
EXPOSE 80 443 2019 8443

# 数据卷
VOLUME ["/config", "/data", "/var/log/caddy", "/etc/sing-box", "/var/log/sing-box"]

# 创建启动脚本
RUN echo '#!/bin/sh' > /usr/local/bin/docker-entrypoint.sh && \
    echo 'set -e' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'echo "========================================="' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'echo "Starting Caddy + sing-box container"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'echo "========================================="' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'if [ ! -f "/etc/caddy/Caddyfile" ]; then' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "❌ ERROR: /etc/caddy/Caddyfile not found!"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  exit 1' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'if ! caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>&1; then' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "❌ ERROR: Caddyfile validation failed!"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  exit 1' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'if [ -f "/etc/sing-box/config.json" ]; then' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "🚀 Starting sing-box..."' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  sing-box run -c /etc/sing-box/config.json > /var/log/sing-box/sing-box.log 2>&1 &' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  SINGBOX_PID=$!' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "✅ sing-box started with PID: $SINGBOX_PID"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  sleep 2' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  if ! kill -0 $SINGBOX_PID 2>/dev/null; then' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '    echo "❌ sing-box failed to start!"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '    cat /var/log/sing-box/sing-box.log' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '    exit 1' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  fi' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'echo "🚀 Starting Caddy..."' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile' >> /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chown caddy:caddy /usr/local/bin/docker-entrypoint.sh

# 切换到非 root 用户（安全性）
USER caddy

# 工作目录
WORKDIR /config/caddy

# 健康检查 - 检查 Caddy 进程是否运行
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD pgrep caddy > /dev/null || exit 1

# 启动命令 - 同时运行 Caddy 和 sing-box
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
