# 部署与运维

最后更新：2026-06-05

## 1. 生产环境

| 项目 | 值 |
| --- | --- |
| 服务器 | `47.103.127.95` |
| 远端目录 | `/opt/dazi-server` |
| Compose 文件 | `docker-compose.prod.yml` |
| API 容器 | `dazi-api` |
| DB | PostgreSQL 16 + pgvector |
| Cache | Redis 7 |
| Web | Nginx |

生产 compose 中 API 监听服务器本机 `127.0.0.1:8000`。公网流量应通过 Nginx 暴露，优先使用 `https://idabuda.com`，域名未完全可用时使用 `http://47.103.127.95`。

## 2. 敏感信息规则

不要把以下内容写进文档或提交到 git：

- `.env`
- Moonshot/Kimi、DeepSeek、OpenAI 等 API key
- `ADMIN_TOKEN`
- JWT secret
- 数据库密码
- SSH/root 密码
- 真实手机号白名单
- 证书私钥

部署细节可参考顶层敏感文档 `/Users/wuxing/Desktop/dazi/重要信息/deploy.md`，但不要把其中的秘密复制到本目录。

## 3. 同步规则

从后端仓库同步到服务器时，至少排除：

```text
.env
.git
.venv*
__pycache__
*.pyc
.pytest_cache
.mypy_cache
certbot
```

示例：

```bash
rsync -az --delete \
  --exclude '.env' \
  --exclude '.git' \
  --exclude '.venv*' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '.pytest_cache' \
  --exclude '.mypy_cache' \
  --exclude 'certbot' \
  /Users/wuxing/Desktop/dazi/dazi/dazi-server/ \
  root@47.103.127.95:/opt/dazi-server/
```

## 4. 重建和启动

在服务器上：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml up -d --build
```

查看容器：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml ps
```

## 5. 健康检查

公网：

```bash
curl -fsS http://47.103.127.95/health
```

服务器本机：

```bash
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/docs
```

容器：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml ps
```

## 6. 常用运维命令

API 日志：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml logs -f dazi-api
```

重启 API：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml restart dazi-api
```

进入数据库：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml exec dazi-db psql -U dazi -d dazi
```

Redis 检查：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml exec dazi-redis redis-cli ping
```

## 7. 内测白名单

白名单文件位于服务器 `/opt/dazi-server/internal_test_phones.txt`。修改后服务会动态读取，通常不需要重启 API。

验证脚本在后端仓库：

```bash
python scripts/smoke_internal_phones_hot_reload.py
python scripts/smoke_internal_test.py
```

## 8. 发布后观察

每次部署后至少检查：

- `/health` 公网和本机均可用。
- `/docs` 在服务器本机可打开。
- `dazi-api`、`dazi-db`、`dazi-redis`、`dazi-web` 均 running。
- 登录 smoke test 通过。
- WebSocket ping/pong 通过。
- 匹配日志没有持续异常。
- 磁盘空间和 Docker 镜像占用正常。

