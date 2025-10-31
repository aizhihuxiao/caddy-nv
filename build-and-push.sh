#!/bin/bash
set -e

# 配置 - 修改为你的 Docker Hub 用户名
DOCKERHUB_USERNAME="your-username"
IMAGE_NAME="${DOCKERHUB_USERNAME}/caddy-naiveproxy"
DATE_TAG=$(date +%Y%m%d)

echo "========================================="
echo "  构建并推送到 Docker Hub"
echo "========================================="
echo "镜像名称: ${IMAGE_NAME}"
echo "标签: latest, ${DATE_TAG}"
echo ""

# 登录 Docker Hub
echo "🔐 登录 Docker Hub..."
docker login

# 拉取最新基础镜像
echo ""
echo "📥 拉取最新基础镜像..."
docker pull caddy:2.8-builder-alpine
docker pull alpine:3.19

# 构建多架构镜像（需要 buildx）
echo ""
echo "🔨 构建多架构镜像（amd64, arm64）..."
echo "   - 使用最新的 Caddy 和 NaiveProxy 核心"
echo "   - 这可能需要几分钟时间..."
echo ""

# 创建并使用 buildx builder
docker buildx create --name naiveproxy-builder --use 2>/dev/null || docker buildx use naiveproxy-builder

# 构建并推送
docker buildx build --no-cache \
    --platform linux/amd64,linux/arm64 \
    --build-arg CADDY_VERSION=latest \
    --build-arg NAIVE_VERSION=naive \
    -t ${IMAGE_NAME}:latest \
    -t ${IMAGE_NAME}:${DATE_TAG} \
    --push \
    .

echo ""
echo "✅ 构建完成！"
echo ""

# 验证镜像（拉取并测试）
echo "🔍 验证镜像..."
docker pull ${IMAGE_NAME}:latest
docker run --rm ${IMAGE_NAME}:latest caddy version
echo ""
echo "📋 检查 NaiveProxy 模块..."
docker run --rm ${IMAGE_NAME}:latest caddy list-modules | grep forward_proxy

echo ""
echo "========================================="
echo "✅ 成功推送到 Docker Hub！"
echo "========================================="
echo "镜像地址："
echo "  - ${IMAGE_NAME}:latest"
echo "  - ${IMAGE_NAME}:${DATE_TAG}"
echo ""
echo "使用方式："
echo "  docker pull ${IMAGE_NAME}:latest"
echo ""
echo "查看镜像："
echo "  https://hub.docker.com/r/${DOCKERHUB_USERNAME}/caddy-naiveproxy"
echo "========================================="
