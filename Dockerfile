# 构建阶段 - 使用 Alpine 基础镜像
FROM golang:1.23-alpine AS builder

# 构建参数 - 使用最新版本
ARG CADDY_VERSION=latest
ARG NAIVE_VERSION=naive
ARG XCADDY_VERSION=v0.4.4

# 设置 GOTOOLCHAIN 允许自动下载更新的 Go 版本
ENV GOTOOLCHAIN=auto

# 安装构建依赖
RUN apk add --no-cache git ca-certificates

# 安装 xcaddy
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@${XCADDY_VERSION}

# 构建自定义 Caddy，使用最新的 NaiveProxy 核心
RUN xcaddy build ${CADDY_VERSION} \
    --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@${NAIVE_VERSION} \
    --with github.com/caddy-dns/cloudflare \
    --output /usr/bin/caddy

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
        wget && \
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
        /etc/caddy && \
    # 设置目录权限
    chown -R caddy:caddy /config /data /var/log/caddy /etc/caddy

# 复制编译好的 caddy
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# 设置权限并验证版本
RUN setcap cap_net_bind_service=+ep /usr/bin/caddy && \
    chmod +x /usr/bin/caddy && \
    caddy version && \
    caddy list-modules | grep forward_proxy

# 环境变量
ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data \
    TZ=Asia/Shanghai

# 暴露端口
EXPOSE 80 443 2019

# 数据卷
VOLUME ["/config", "/data", "/var/log/caddy"]

# 切换到非 root 用户（安全性）
USER caddy

# 工作目录
WORKDIR /config/caddy

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider --timeout=3 http://127.0.0.1:2019/config/ 2>&1 || exit 1

# 启动命令
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
