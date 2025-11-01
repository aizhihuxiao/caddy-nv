# 🔐 多CA智能证书申请系统

## 问题背景

Let's Encrypt 对证书申请有速率限制：
- **每个域名每天最多失败5次**
- 同一天部署多台服务器时容易触发限制
- 触发后需要等待24小时才能重试

## 解决方案

本系统实现了**智能多CA切换机制**，自动尝试多个免费证书颁发机构：

1. **Let's Encrypt** (默认) - 最流行的免费CA
2. **ZeroSSL** - 另一个主流免费CA
3. **Google Trust Services** - Google提供的免费证书
4. **Buypass** - 挪威的免费CA
5. **Let's Encrypt Staging** - 测试环境（无限制）

当一个CA失败时，自动切换到下一个，直到成功为止。

## 📁 新增文件

### 1. `Caddyfile.multi-ca.example`
包含多个ACME服务器配置注释的Caddyfile模板

### 2. `cert-manager.sh` ⭐ 核心脚本
智能证书申请脚本，功能：
- 自动尝试多个CA服务器
- 失败时自动切换到下一个
- 记录失败状态，避免重复尝试
- 彩色日志输出，易于监控
- 自动清理过期记录

## 🚀 使用方法

### 方式1: 自动部署（推荐）

运行 `run.sh` 会自动调用智能证书申请：

```bash
chmod +x run.sh
./run.sh
```

脚本会：
1. 部署Caddy容器
2. 自动检测 `cert-manager.sh`
3. 使用多CA智能申请证书
4. 失败时自动切换CA

### 方式2: 手动证书申请

如果自动申请失败，可以手动运行：

```bash
chmod +x cert-manager.sh
./cert-manager.sh
```

### 方式3: 已有容器重新申请

如果容器已经在运行，只想重新申请证书：

```bash
export CADDY_DIR="$PWD/caddy"
export CONTAINER_NAME="caddy"
./cert-manager.sh
```

## 🔍 工作原理

### 智能切换流程

```
开始
  ↓
尝试 Let's Encrypt
  ↓
成功? → 是 → 完成 ✅
  ↓ 否
检查失败原因（速率限制/其他错误）
  ↓
记录失败状态
  ↓
尝试 ZeroSSL
  ↓
成功? → 是 → 完成 ✅
  ↓ 否
尝试 Google Trust Services
  ↓
成功? → 是 → 完成 ✅
  ↓ 否
尝试 Buypass
  ↓
成功? → 是 → 完成 ✅
  ↓ 否
尝试 Let's Encrypt Staging (测试)
  ↓
成功? → 是 → 完成 ✅
  ↓ 否
全部失败 ❌
```

### 状态记录

脚本在 `caddy/acme-state.txt` 记录尝试状态：
```
2025-11-01|letsencrypt|failed
2025-11-01|zerossl|success
```

- 自动避免重复尝试失败的CA
- 每天同一CA失败3次后跳过
- 自动清理7天前的记录

## 📊 日志示例

```bash
[INFO] 🔐 开始智能证书申请流程
[INFO] 域名: *.99gtr.com
[INFO] =========================================
[INFO] 尝试使用: Let's Encrypt Production
[INFO] ACME URL: https://acme-v02.api.letsencrypt.org/directory
[INFO] =========================================
[ERROR] 检测到速率限制错误
[ERROR] ❌ 证书申请失败
[WARNING] 切换到下一个CA...
[INFO] =========================================
[INFO] 尝试使用: ZeroSSL
[INFO] ACME URL: https://acme.zerossl.com/v2/DV90
[INFO] =========================================
[SUCCESS] 证书文件已生成
[SUCCESS] ✅ 证书申请成功！使用的CA: ZeroSSL
```

## 🛠️ 手动切换CA

如果需要手动指定某个CA，编辑 `caddy/Caddyfile`：

```caddyfile
{
    # 选择其中一个取消注释
    
    # acme_ca https://acme-v02.api.letsencrypt.org/directory
    acme_ca https://acme.zerossl.com/v2/DV90
    # acme_ca https://dv.acme-v02.api.pki.goog/directory
    # acme_ca https://api.buypass.com/acme/directory
    
    email admin@yourdomain.com
}
```

然后重启容器：
```bash
docker restart caddy
```

## 📋 各CA对比

| CA | 速率限制 | 证书有效期 | 兼容性 | 特点 |
|---|---|---|---|---|
| Let's Encrypt | 5次/天 (失败) | 90天 | ⭐⭐⭐⭐⭐ | 最流行 |
| ZeroSSL | 较宽松 | 90天 | ⭐⭐⭐⭐⭐ | 商业支持 |
| Google Trust | 未知 | 90天 | ⭐⭐⭐⭐⭐ | Google背书 |
| Buypass | 较宽松 | 180天 | ⭐⭐⭐⭐ | 有效期长 |
| LE Staging | 无限制 | 90天 | ⭐ | 仅用于测试 |

## 🔧 故障排查

### 证书申请失败

1. **检查日志**
   ```bash
   docker logs caddy --tail 50
   ```

2. **检查Cloudflare Token**
   - 确保有 `Zone:DNS:Edit` 权限
   - Token未过期

3. **检查DNS解析**
   ```bash
   nslookup yourdomain.com
   ```

4. **查看状态文件**
   ```bash
   cat caddy/acme-state.txt
   ```

### 所有CA都失败

可能原因：
- Cloudflare API Token无效
- DNS解析问题
- 网络连接问题
- 域名配置错误

解决方法：
```bash
# 1. 验证配置
cat caddy/Caddyfile

# 2. 测试网络
curl -I https://acme-v02.api.letsencrypt.org/directory

# 3. 重新生成配置
./run.sh
```

### 手动清理重试

```bash
# 停止容器
docker stop caddy

# 清理证书缓存
rm -rf caddy/data/caddy/certificates/*

# 清理状态记录
rm -f caddy/acme-state.txt

# 重新申请
./cert-manager.sh
```

## 🎯 最佳实践

### 1. 部署多台服务器

同一天部署多台时：

```bash
# 第1台 - 使用默认配置
./run.sh

# 第2台 - 如果失败，会自动切换CA
./run.sh

# 第3台 - 继续切换
./run.sh
```

### 2. 定期检查证书

创建定时任务检查证书过期：

```bash
# 添加到 crontab
0 2 * * * docker exec caddy caddy list-certificates
```

### 3. 监控证书状态

```bash
# 查看当前证书
docker exec caddy caddy list-certificates

# 查看证书文件
ls -lh caddy/data/caddy/certificates/
```

## 📌 注意事项

1. **首次申请**：可能需要等待1-2分钟
2. **速率限制**：虽然有多CA，但建议避免频繁重新申请
3. **生产环境**：避免使用 Staging CA（仅测试用）
4. **备份**：重要证书建议定期备份 `caddy/data` 目录

## 🔗 相关文档

- [Let's Encrypt 速率限制](https://letsencrypt.org/docs/rate-limits/)
- [ZeroSSL 文档](https://zerossl.com/documentation/)
- [Caddy ACME 文档](https://caddyserver.com/docs/automatic-https)
- [Cloudflare DNS API](https://developers.cloudflare.com/dns/)

## 📝 更新日志

### 2025-11-01
- ✅ 添加多CA智能切换机制
- ✅ 创建 `cert-manager.sh` 证书管理脚本
- ✅ 集成到自动部署流程
- ✅ 添加状态记录和失败跟踪
- ✅ 支持5个免费CA服务器

---

**问题反馈**: 如遇到问题，请提供以下信息：
1. `docker logs caddy` 输出
2. `cat caddy/acme-state.txt` 内容
3. 执行的具体命令
