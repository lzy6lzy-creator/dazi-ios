# 部署与运维

最后更新：2026-08-31

## 1. 生产环境

| 项目 | 值 |
| --- | --- |
| 服务器 | `47.103.127.95` |
| 远端目录 | `/opt/dazi-server` |
| Compose 文件 | `docker-compose.prod.yml` |
| API 容器 | `dazi-api` |
| 定时任务容器 | `dazi-worker` |
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
.env.*
internal_test_phones.txt
.git
.venv*
__pycache__
*.pyc
.pytest_cache
.mypy_cache
certbot
uploads
model-cache
```

示例：

```bash
rsync -az --delete \
  --exclude '.env' \
  --exclude '.env.*' \
  --exclude 'internal_test_phones.txt' \
  --exclude '.git' \
  --exclude '.venv*' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '.pytest_cache' \
  --exclude '.mypy_cache' \
  --exclude 'certbot' \
  --exclude 'uploads' \
  --exclude 'model-cache' \
  /Users/wuxing/Desktop/dazi/dazi/dazi-server/ \
  root@47.103.127.95:/opt/dazi-server/
```

## 4. 重建和启动

在服务器上：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml up -d --build
```

API 镜像由 API 和 worker 共用。API 启动命令先执行 `alembic upgrade head`；
worker 和 Nginx 等 API readiness 通过后再启动，worker 不重复执行迁移。

现有生产库已一次性 stamp 为 `0001_baseline` 并升级到 `0003_reconcile_legacy_schema`。
后续发布只能运行 `upgrade head`，不要再次 stamp 跳过迁移。全新库直接 upgrade。

```bash
docker compose -f docker-compose.prod.yml exec -T api python -m alembic current
docker compose -f docker-compose.prod.yml exec -T api python -m alembic check
```

每次变更模型需新建迁移，并在临时 PostgreSQL 库验证升级与 `alembic check`。
不要对生产执行 `downgrade base`，基线降级会删表；应用回滚与数据库恢复必须分别确认。

查看容器：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml ps
```

## 5. 健康检查

公网：

```bash
curl -fsS https://idabuda.com/health
curl -fsS https://idabuda.com/ready
```

服务器本机：

```bash
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/ready
curl -fsS http://localhost:8000/docs
```

容器：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml ps
```

`/health` 只检查存活；`/ready` 检查 PostgreSQL、当前迁移版本、Redis 和 WebSocket 订阅，失败返回 503。
LLM、短信、APNs 不属于 readiness 探针，需单独做业务验证。
HTTP 会重定向 HTTPS，不能把 301 当作 API 健康成功。

`/opt/dazi-server/uploads` 是用户媒体持久数据，API 和 Nginx 以不同只读/读写挂载共享。部署同步不得删除；备份和恢复时应与 PostgreSQL 一起处理。

`/opt/dazi-server/model-cache` 是 API 与 worker 共用的 Hugging Face 模型缓存，部署时保留，
Docker 构建上下文排除该目录及环境文件、密钥、白名单和用户媒体。

## 6. 常用运维命令

API 日志：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml logs -f api worker
```

重启 API：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml restart api worker
```

进入数据库：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml exec db psql -U dazi -d dazi
```

Redis 检查：

```bash
cd /opt/dazi-server
docker compose -f docker-compose.prod.yml exec redis redis-cli ping
```

无用户数据写入的跨进程检查（临时随机用户标识，不发送短信或 APNs）：

```bash
docker compose -f docker-compose.prod.yml exec -T api \
  python -m scripts.smoke_runtime --ws-url wss://idabuda.com/ws
```

worker 日志与 API 进程日志分开；后台匹配详情仍读取数据库 `match_logs`。
worker 每 15 秒更新心跳，任何调度循环退出都会让 worker 失败退出，由 Compose 重启。
worker 的 `EMBEDDING_REMOTE_URL` 指向 API 的受保护内部接口，避免 2GB 机器加载两份模型。
该接口不对公网反代；内部请求使用服务端凭证，不能把凭证交给客户端。

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
- worker 启动后每 24 小时通过公开 RDAP 和 TLS 握手核查域名、HTTPS 证书日期；后台也可手动点击“在线核查域名/证书”。在线失败时保留上次日期。
- 台账只保存日期、负责人、控制台链接和非敏感备注；不要填写密码、API Key 或证书私钥。
- 首次启动会按稳定 slug 写入项目初始台账，`ON CONFLICT DO NOTHING`，不会覆盖后台中的人工修改。

当前项目基准包括：

- `idabuda.com` 域名：2027-06-04。
- HTTPS 证书：北京时间 2026-11-27；2026-08-29 通过公网 TLS 握手核实，自动续期机制仍待控制台确认。
- ICP 年度核查：2027-06-29；这是核查提醒，不代表备案有固定到期日。
- 阿里云服务器、PNVS 套餐和 Apple 会员：暂记为 2027 年 6 月，具体日期待控制台核实。
- Moonshot/Kimi：无固定到期日，按月检查余额和近期消耗。
- TestFlight 1.1 (11)：2026-08-31 上传并进入内部测试，Apple 返回有效期为北京时间 2026-11-29 16:05:20，已同步提醒台账。

## 9. 发布后观察

每次部署后至少检查：

- `/health` 与 `/ready` 在公网 HTTPS 和本机均返回 200。
- `/docs` 在服务器本机可打开。
- `dazi-api`、`dazi-worker`、`dazi-db`、`dazi-redis` 均 healthy，`dazi-web` running。
- 登录 smoke test 通过。
- WebSocket ping/pong 通过。
- 匹配日志没有持续异常。
- 磁盘空间和 Docker 镜像占用正常。

## 10. 备份与巡检

- `dazi-backup.timer` 每天北京时间 03:30 后三分钟内运行，保留至少 14 天加密备份。
- 备份包含 PostgreSQL custom dump、用户媒体和 SHA-256 清单；使用 GPG AES-256 加密。
- 密钥在 `/opt/dazi-secrets/backup-passphrase`，必须独立保管且不可提交 Git。
- 每份备份会自动解密并恢复到 `dazi_restore_*` 临时数据库，检查表数、迁移版本和本地图片引用，再删除临时库。验证失败不产生正式备份文件。
- 媒体按数据库快照前后的文件并集归档；并发删除导致引用缺失时恢复校验会失败，需重试，不宣称它是 PITR 或原子文件系统快照。
- `dazi-health.timer` 每五分钟检查本机/公网 readiness、容器、磁盘、可用内存、DB 连接数和最近错误日志，报告在 `/var/lib/dazi-ops/health.json`。
- 定时器与服务文件在 `dazi-server/ops/systemd/`。失败状态记录于 systemd/journal，不会向用户发送 App 系统通知。
- 持续异地备份存储和邮件/外部故障通知尚未配置；生产机丢失时不能只依赖同机备份。
- 2026-08-31 已将一份验证通过的加密备份另存到本机 `重要信息/生产备份/`，密钥单独放在 `重要信息/备份密钥/`，目录 700、文件 600；这不是持续异地同步。

2026-08-31 验证：恢复 27 张业务表到 `0003_reconcile_legacy_schema`，损坏密文被拒绝，
无临时恢复库遗留。生产当时无自定义图片引用；图片缺失/路径越界另有单测覆盖。
基础巡检全部通过，DB 连接 9/100，最近五分钟无错误日志。

```bash
systemctl list-timers 'dazi-*'
systemctl start dazi-backup.service
journalctl -u dazi-backup.service -n 40 --no-pager
systemctl start dazi-health.service
cat /var/lib/dazi-ops/health.json
bash /opt/dazi-server/scripts/verify_production_backup.sh /opt/dazi-backups/encrypted/指定备份.tar.gpg
```

上述验证脚本只创建临时恢复库，不会把备份覆盖到生产。真正恢复生产需要另外确认停机窗口、目标数据库、媒体目录和回滚镜像。
