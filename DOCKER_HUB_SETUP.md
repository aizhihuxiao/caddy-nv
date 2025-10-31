# Docker Hub 构建配置指南

本文档说明如何在 Docker Hub 上设置自动构建。

## 方法 1：使用 GitHub Actions（推荐）

### 步骤 1：创建 Docker Hub Access Token

1. 登录 [Docker Hub](https://hub.docker.com)
2. 点击右上角头像 → **Account Settings**
3. 左侧菜单选择 **Security**
4. 点击 **New Access Token**
5. 输入描述（如：GitHub Actions）
6. 权限选择：**Read, Write, Delete**
7. 点击 **Generate**
8. **立即复制** Token（只显示一次）

### 步骤 2：设置 GitHub Secrets

1. 进入你的 GitHub 仓库
2. 点击 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 添加以下 Secrets：

   **Secret 1:**
   - Name: `DOCKERHUB_USERNAME`
   - Value: 你的 Docker Hub 用户名

   **Secret 2:**
   - Name: `DOCKERHUB_TOKEN`
   - Value: 刚才复制的 Access Token

### 步骤 3：推送代码触发构建

```bash
# 初始化 Git 仓库（如果还没有）
git init
git add .
git commit -m "Initial commit: Caddy NaiveProxy"

# 连接到 GitHub（创建仓库后）
git remote add origin https://github.com/your-username/caddy-naiveproxy.git
git branch -M main
git push -u origin main
```

推送后，GitHub Actions 会自动：
- 构建 amd64 和 arm64 架构镜像
- 推送到 Docker Hub
- 更新 Docker Hub 的 README

### 步骤 4：查看构建状态

1. GitHub 仓库 → **Actions** 标签
2. 查看构建进度和日志
3. 构建完成后，访问 Docker Hub 查看镜像

### 自动构建时间

- ✅ 每次 push 到 main/master 分支
- ✅ 每周日凌晨 2 点（自动拉取最新 NaiveProxy）
- ✅ 手动触发（Actions → Run workflow）

---

## 方法 2：本地构建推送

如果不想使用 GitHub Actions，可以本地手动构建：

### 步骤 1：安装 Docker Buildx

```bash
# 检查是否已安装
docker buildx version

# 启用 buildx（如果需要）
docker buildx create --use
```

### 步骤 2：修改脚本

编辑 `build-and-push.sh`，修改第 4 行：

```bash
DOCKERHUB_USERNAME="your-username"  # 改为你的 Docker Hub 用户名
```

### 步骤 3：执行构建

```bash
chmod +x build-and-push.sh
./build-and-push.sh
```

脚本会：
1. 登录 Docker Hub
2. 拉取最新基础镜像
3. 构建 amd64 和 arm64 镜像
4. 推送到 Docker Hub
5. 验证构建结果

---

## 方法 3：Docker Hub Automated Builds

### 步骤 1：创建 Docker Hub 仓库

1. 登录 [Docker Hub](https://hub.docker.com)
2. 点击 **Create Repository**
3. 填写：
   - Repository Name: `caddy-naiveproxy`
   - Visibility: **Public** 或 **Private**
4. 点击 **Create**

### 步骤 2：连接 GitHub

1. 进入刚创建的仓库
2. 点击 **Builds** 标签
3. 点击 **Link to GitHub**
4. 授权 Docker Hub 访问你的 GitHub
5. 选择你的仓库

### 步骤 3：配置构建规则

添加构建规则：

| Source Type | Source | Docker Tag | Dockerfile | Build Context | Autobuild |
|-------------|--------|------------|------------|---------------|-----------|
| Branch      | main   | latest     | Dockerfile | /             | ✅        |
| Branch      | main   | {sourceref}| Dockerfile | /             | ✅        |

### 步骤 4：触发首次构建

1. 点击 **Save and Build**
2. 等待构建完成（可能需要 10-20 分钟）
3. 查看构建日志

**注意**：Docker Hub Automated Builds 只支持 amd64 架构。

---

## 验证构建

### 查看镜像信息

```bash
# 拉取镜像
docker pull your-username/caddy-naiveproxy:latest

# 查看 Caddy 版本
docker run --rm your-username/caddy-naiveproxy:latest caddy version

# 验证 NaiveProxy 模块
docker run --rm your-username/caddy-naiveproxy:latest caddy list-modules | grep forward_proxy
```

### 测试运行

```bash
docker run -d --name test-caddy \
    -p 443:443 \
    -v ./Caddyfile.example:/etc/caddy/Caddyfile:ro \
    your-username/caddy-naiveproxy:latest

# 查看日志
docker logs test-caddy

# 清理
docker stop test-caddy && docker rm test-caddy
```

---

## 更新镜像

### GitHub Actions 自动更新

- **每周日凌晨 2 点**自动构建最新版本
- **手动触发**：GitHub → Actions → Build and Push → Run workflow

### 手动更新

```bash
# 重新运行构建脚本
./build-and-push.sh
```

---

## 在服务器上使用

修改 `run.sh` 和 `run-interactive.sh` 中的镜像名：

```bash
# 将这行：
lingex/caddy-cf-naive

# 改为：
your-username/caddy-naiveproxy:latest
```

然后部署：

```bash
./run.sh
```

---

## 故障排查

### GitHub Actions 构建失败

1. 检查 Secrets 是否正确设置
2. 查看 Actions 日志查找错误
3. 验证 Docker Hub Token 权限

### 本地构建失败

1. 确保 Docker Buildx 已安装
2. 检查网络连接（需要拉取基础镜像）
3. 确保已登录 Docker Hub

### 无法推送到 Docker Hub

1. 验证用户名和密码
2. 检查 Docker Hub 仓库是否存在
3. 确认 Access Token 权限包含 Write

---

## 推荐配置

✅ **使用 GitHub Actions**（自动化、支持多架构）
✅ **启用定时构建**（每周自动更新 NaiveProxy）
✅ **设置 Watchtower**（服务器自动拉取新镜像）

这样可以确保始终使用最新版本的 NaiveProxy 核心！
