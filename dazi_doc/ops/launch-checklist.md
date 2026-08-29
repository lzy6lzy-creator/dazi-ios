# 上线清单

最后更新：2026-08-29

## 1. 当前状态

- 后端已部署到 `47.103.127.95`。
- 动态验证码已接入阿里云 PNVS；固定测试码只对服务端白名单生效。
- 新用户已接入开放名额/邀请码准入和注册期定位判断。
- 主动匹配已升级为向量召回、硬过滤、A2A 精排和聊天室创建。
- 被动匹配已改为邀请确认制。
- 地点匹配已拆出 normalizer/policy 并完成本地评测。
- iOS 已接入主要活动、Clarify、匹配、推送、聊天室、投票、被动邀请、公开主页和账号注销流程。
- Android 当前不在发布范围，本清单不代表 Android 已同步。

## 2. TestFlight 前 P0

- [ ] 生成并上传 iOS TestFlight 构建。
- [ ] 确认 iOS 包使用当前公网 API。
- [ ] 在 App Store Connect 创建或确认 App、Bundle ID、版本号和 Build 号。
- [ ] 填写 App 隐私、出口合规、年龄分级等 TestFlight 必填项。
- [ ] 真机跑主链路：登录、首次注册、编辑资料、创建活动、匹配、聊天室、投票。
- [ ] 真机跑被动邀请：接受、拒绝、拒绝后不重复推送同一用户对。
- [ ] 真机跑异常链路：未白名单手机号、错误验证码、网络断开、退出重登。
- [x] access/refresh token 迁移到 Keychain，并兼容搬迁旧本地 token。
- [ ] 真机验证 WebSocket 断线重连、前后台切换和 token 刷新后的重连。
- [ ] 真机确认新聊天室/新消息只有一条 APNs 提醒，无本地通知重复。
- [ ] 确认文档和代码里没有真实 key、密码、root 登录信息。

## 3. 当前已知不完整功能

- [x] 活动评价接入后端持久化；双方事件均结束后再关闭共享聊天室。
- [x] 用户和 Agent 自定义头像接入持久化媒体上传、URL 展示和跨设备同步。
- [x] 活动相册拆为服务端图片文件 + 数据库元数据，并按公开主页可见性鉴权读取。
- [x] 聊天室列表批量加载成员、事件、最新消息和未读数，消除按房间增长的 N+1 查询。

## 4. 后端 P0

- [ ] 跑登录、创建活动、匹配、聊天室投票的端到端 smoke test。
- [ ] 跑主动 A2A 成功/失败两轮、候选被锁跳过、被动邀请接受/拒绝测试。
- [ ] 部署后观察 passive matching 日志，确认旧的直接建房链路不再出现。
- [ ] 确认生产 DB 中 memory 相关表结构存在。
- [ ] 明确回滚策略：保留上一个可部署 commit 和数据库备份。

## 5. 域名和 HTTPS

- [x] DNS 指向服务器。
- [x] Nginx 反代 API 和 WebSocket。
- [ ] HTTPS 证书和自动续期。
- [x] iOS base URL 使用 `https://idabuda.com`，WebSocket 使用 WSS。
- [x] iOS 不使用 ATS cleartext 临时放行。
- [ ] 重新跑 iOS 真机 smoke test。

## 6. 正式上线前 P1

- [x] 接入真实 PNVS 动态验证码；保留白名单固定码仅用于内部测试。
- [ ] 用 Alembic 正式迁移替代运行时 `create_all()` 依赖。
- [ ] WebSocket ConnectionManager 改为 Redis Pub/Sub 或独立消息层。
- [ ] 定时匹配任务从 API 进程拆到独立 worker。
- [ ] PostgreSQL 定时备份、恢复演练和备份加密。
- [ ] 基础监控：API 健康、错误日志、磁盘、内存、DB 连接数。
- [ ] 增加 readiness 检查，区分 API 存活与 PostgreSQL/Redis 可用。
- [ ] 生产 CORS 白名单收敛到正式域名。
- [ ] 准备 App Store 素材、隐私政策、用户协议和客服反馈入口。
