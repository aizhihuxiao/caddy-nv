# Enhanced Caddy Server

A modern web server solution based on Caddy, featuring Cloudflare DNS integration for automated SSL certificate management.

## Features

- ✅ **Modern Architecture** - High-performance web server
- ✅ **DNS Integration** - Automated wildcard SSL certificate provisioning  
- ✅ **Auto Updates** - Continuous integration with latest upstream
- ✅ **Network Optimization** - Enhanced TCP stack with modern congestion control
- ✅ **Security Focused** - Non-privileged execution with minimal dependencies
- ✅ **Multi-Platform** - Native support for amd64 and arm64 architectures

## 快速开始

### 1. Configuration Setup

Create your server configuration file (`Caddyfile`):

```caddyfile
:443, *.example.com {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
        protocols tls1.2 tls1.3
    }

    route {
        # Enhanced routing configuration
        forward_proxy {
            basic_auth {env.AUTH_USER} {env.AUTH_PASS}
            hide_ip
            hide_via
            probe_resistance
        }
        
        # Default upstream handler
        reverse_proxy https://www.microsoft.com {
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
docker run -d --name web-server \
    --restart=always \
    --net=host \
    -e CF_API_TOKEN=your_api_token \
    -e AUTH_USER=your_username \
    -e AUTH_PASS=your_password \
    -v ./Caddyfile:/etc/caddy/Caddyfile:ro \
    -v server_data:/data/caddy \
    -v server_config:/config \
    -v server_logs:/var/log/caddy \
    aizhihuxiao/caddy-nv:latest
```

### 3. Automated Deployment

Use the automated setup script:

```bash
chmod +x deploy.sh
./deploy.sh
```

For interactive configuration:

```bash
chmod +x setup-interactive.sh  
./setup-interactive.sh
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `CF_API_TOKEN` | Cloudflare API Token | `abc123...` |
| `AUTH_USER` | Authentication username | `admin` |
| `AUTH_PASS` | Authentication password | `secure_password` |

## 目录说明

- `/etc/caddy/Caddyfile` - Caddy 配置文件
- `/data/caddy` - 证书和数据存储
- `/config` - 配置存储
- `/var/log/caddy` - 日志文件

## Management Commands

```bash
# View logs
docker logs -f web-server

# Restart service
docker restart web-server

# Check certificates
docker exec web-server caddy list-certificates

# Graceful configuration reload
docker exec web-server caddy reload --config /etc/caddy/Caddyfile
```

## Performance Tuning

Server-side network optimization recommendations:

```bash
# Enable BBR congestion control
modprobe tcp_bbr
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

For comprehensive optimization, refer to the deployment scripts.

## Client Configuration

Example client configuration for enhanced routing:

```json
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://username:password@example.com"
}
```

## Update Management

```bash
# Pull latest version
docker pull aizhihuxiao/caddy-nv:latest

# Restart container
docker restart web-server
```

Automated updates with Watchtower:

```bash
docker run -d --name watchtower \
    --restart=unless-stopped \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower --cleanup --interval 21600
```

## Local Build

Build from source:

```bash
docker build --no-cache -t enhanced-caddy:latest .
```

## Security Recommendations

- ✅ Use strong authentication credentials
- ✅ Regularly rotate access credentials  
- ✅ Configure security groups to allow only necessary ports
- ✅ Enable CDN services for additional protection
- ✅ Monitor logs for anomalous traffic patterns

## Troubleshooting

### SSL Certificate Issues

```bash
# Verify API token permissions
# Required: Zone:DNS:Edit permissions

# Check detailed logs
docker logs web-server
```

### Connectivity Problems

```bash
# Check port availability
netstat -tlnp | grep 443

# Verify firewall status
ufw status

# Check container status
docker ps
docker logs web-server
```

## License

This project incorporates open source components:
- [Caddy](https://github.com/caddyserver/caddy) - Apache 2.0 License
- [Forward Proxy Module](https://github.com/caddyserver/forwardproxy) - Apache 2.0 License  
- [Cloudflare DNS Plugin](https://github.com/caddy-dns/cloudflare) - Apache 2.0 License

## Documentation

- [Caddy Server Documentation](https://caddyserver.com/docs/)
- [Cloudflare API Reference](https://developers.cloudflare.com/api/)
