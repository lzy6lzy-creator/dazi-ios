# 部署与运维

最后更新：2026-08-01

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

生产 compose 中 API 只映射到宿主机 `127.0.0.1:8000`，公网流量通过 Nginx 和 `https://idabuda.com` 暴露。

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
uploads
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
  --exclude 'uploads' \
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
curl -fsS https://idabuda.com/health
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

`/health` 当前只证明 API 进程可以响应，不代表 PostgreSQL、Redis、LLM、短信或 APNs 均健康。部署验证仍需检查容器状态、Redis ping、关键 API 和日志。

`/opt/dazi-server/uploads` 是用户媒体持久数据，API 和 Nginx 以不同只读/读写挂载共享。部署同步不得删除；备份和恢复时应与 PostgreSQL 一起处理。

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

## 8. 到期提醒台账

统一后台 `/admin#reminders` 提供域名、证书、备案、云服务、短信、Apple 和 LLM 余额检查台账。数据保存在 PostgreSQL 的 `service_reminders` 表中，并继续使用现有 `ADMIN_TOKEN` 鉴权。

- 确切日期直接显示年月日；只有月份的信息必须标记为“具体日待核实”。
- 到期、定期核查和余额检查使用同一台账，但页面文案会区分事项类型。
- 点击“已续费”或“本轮已检查”后，配置了周期的事项会顺延到下一周期。
- 服务启动后每 24 小时通过公开 RDAP 和 TLS 握手核查域名、HTTPS 证书日期；后台也可手动点击“在线核查域名/证书”。在线失败时保留上次日期。
- 台账只保存日期、负责人、控制台链接和非敏感备注；不要填写密码、API Key 或证书私钥。
- 首次启动会按稳定 slug 写入项目初始台账，`ON CONFLICT DO NOTHING`，不会覆盖后台中的人工修改。

当前项目基准包括：

- `idabuda.com` 域名：2027-06-04。
- HTTPS 证书：北京时间 2026-11-27；2026-08-29 通过公网 TLS 握手核实，自动续期机制仍待控制台确认。
- ICP 年度核查：2027-06-29；这是核查提醒，不代表备案有固定到期日。
- 阿里云服务器、PNVS 套餐和 Apple 会员：暂记为 2027 年 6 月，具体日期待控制台核实。
- Moonshot/Kimi：无固定到期日，按月检查余额和近期消耗。

## 9. 发布后观察

每次部署后至少检查：

- `/health` 公网和本机均可用。
- `/docs` 在服务器本机可打开。
- `dazi-api`、`dazi-db`、`dazi-redis`、`dazi-web` 均 running。
- 登录 smoke test 通过。
- WebSocket ping/pong 通过。
- 匹配日志没有持续异常。
- 磁盘空间和 Docker 镜像占用正常。
