# Caddy with NaiveProxy

基于 Caddy 构建的 NaiveProxy 服务器镜像，集成 Cloudflare DNS 插件，支持自动申请通配符 SSL 证书。

## 特性

- ✅ **NaiveProxy** - 最新版本的 naive forwardproxy 插件
- ✅ **Cloudflare DNS** - 支持通配符证书自动申请
- ✅ **自动更新** - 定期构建最新版本
- ✅ **高性能** - 优化的网络配置，支持 BBR
- ✅ **安全** - 非 root 用户运行，最小化依赖
- ✅ **多架构** - 支持 amd64 和 arm64

## 快速开始

### 1. 准备 Caddyfile

创建 `Caddyfile` 配置文件：

```caddyfile
:443, *.yourdomain.com {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
        protocols tls1.2 tls1.3
    }

    route {
        forward_proxy {
            basic_auth {env.NAIVE_USER} {env.NAIVE_PASSWD}
            hide_ip
            hide_via
            probe_resistance
        }
        
        reverse_proxy https://www.cloudflare.com {
            header_up Host {upstream_hostport}
        }
    }
}

:80 {
    redir https://{host}{uri} permanent
}
```

### 2. 启动容器

```bash
docker run -d --name caddy \
    --restart=always \
    --net=host \
    -e CF_API_TOKEN=your_cloudflare_api_token \
    -e NAIVE_USER=username \
    -e NAIVE_PASSWD=password \
    -v ./Caddyfile:/etc/caddy/Caddyfile:ro \
    -v caddy_data:/data/caddy \
    -v caddy_config:/config \
    -v caddy_logs:/var/log/caddy \
    yourusername/caddy-naiveproxy:latest
```

### 3. 使用部署脚本（推荐）

下载并运行自动化部署脚本：

```bash
chmod +x run.sh
./run.sh
```

或使用交互式配置：

```bash
chmod +x run-interactive.sh
./run-interactive.sh
```

## 环境变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `CF_API_TOKEN` | Cloudflare API Token | `abc123...` |
| `NAIVE_USER` | NaiveProxy 用户名 | `myuser` |
| `NAIVE_PASSWD` | NaiveProxy 密码 | `mypassword` |

## 目录说明

- `/etc/caddy/Caddyfile` - Caddy 配置文件
- `/data/caddy` - 证书和数据存储
- `/config` - 配置存储
- `/var/log/caddy` - 日志文件

## 管理命令

```bash
# 查看日志
docker logs -f caddy

# 重启服务
docker restart caddy

# 查看证书
docker exec caddy caddy list-certificates

# 重新加载配置（优雅重启）
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

## 性能优化

服务器端建议启用 BBR 和优化 TCP 参数：

```bash
# 启用 BBR
modprobe tcp_bbr
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

完整优化请参考 `run.sh` 脚本。

## 客户端配置

NaiveProxy 客户端配置示例：

```json
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://username:password@yourdomain.com"
}
```

## 更新镜像

```bash
# 拉取最新版本
docker pull yourusername/caddy-naiveproxy:latest

# 重启容器
docker restart caddy
```

使用 Watchtower 自动更新：

```bash
docker run -d --name watchtower \
    --restart=unless-stopped \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower --cleanup --interval 21600
```

## 构建镜像

本地构建：

```bash
docker build --no-cache -t caddy-naiveproxy:latest .
```

## 安全建议

- ✅ 使用强密码
- ✅ 定期更换认证信息
- ✅ 在云服务商配置安全组，只开放必要端口
- ✅ 启用 Cloudflare CDN（可选）
- ✅ 定期查看日志，检测异常访问

## 故障排查

### 证书申请失败

```bash
# 检查 Cloudflare API Token 权限
# 需要 Zone:DNS:Edit 权限

# 查看详细日志
docker logs caddy
```

### 无法连接

```bash
# 检查端口是否开放
netstat -tlnp | grep 443

# 检查防火墙
ufw status

# 检查容器状态
docker ps
docker logs caddy
```

## 许可证

本项目基于开源组件构建：
- [Caddy](https://github.com/caddyserver/caddy) - Apache 2.0
- [NaiveProxy](https://github.com/klzgrad/forwardproxy) - BSD 3-Clause
- [Cloudflare DNS Plugin](https://github.com/caddy-dns/cloudflare) - Apache 2.0

## 相关链接

- [NaiveProxy 官方](https://github.com/klzgrad/naiveproxy)
- [Caddy 文档](https://caddyserver.com/docs/)
- [Cloudflare API](https://developers.cloudflare.com/api/)
