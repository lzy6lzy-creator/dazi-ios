# 上线清单

最后更新：2026-06-05

## 1. 当前状态

- 后端已部署到 `47.103.127.95`。
- 内测登录已切到环境变量验证码 + 手机号白名单。
- 旧固定验证码和默认管理 token 已从代码与远端部署中移除。
- 主动匹配已升级为向量召回、硬过滤、A2A 精排和聊天室创建。
- 被动匹配已改为邀请确认制。
- 地点匹配已拆出 normalizer/policy 并完成本地评测。
- iOS 和 Android 已接入主要活动、聊天室、投票和被动邀请流程。

## 2. TestFlight 前 P0

- [ ] 生成并上传 iOS TestFlight 构建。
- [ ] 确认 iOS 包使用当前公网 API。
- [ ] 在 App Store Connect 创建或确认 App、Bundle ID、版本号和 Build 号。
- [ ] 填写 App 隐私、出口合规、年龄分级等 TestFlight 必填项。
- [ ] 真机跑主链路：登录、首次注册、编辑资料、创建活动、匹配、聊天室、投票。
- [ ] 真机跑被动邀请：接受、拒绝、拒绝后不重复推送同一用户对。
- [ ] 真机跑异常链路：未白名单手机号、错误验证码、网络断开、退出重登。
- [ ] 检查 iOS token 安全存储方案。
- [ ] 确认文档和代码里没有真实 key、密码、root 登录信息。

## 3. Android 内测前 P0

- [ ] 重新运行 `./gradlew :app:testDebugUnitTest`。
- [ ] 重新运行 `./gradlew :app:assembleDebug`。
- [ ] 真机检查登录、活动、聊天室、投票、被动邀请。
- [ ] 检查输入法、权限弹窗、WebSocket 断线重连。
- [ ] token 迁移到加密存储。
- [ ] 域名切换后移除 cleartext 放行。

## 4. 后端 P0

- [ ] 跑登录、创建活动、匹配、聊天室投票的端到端 smoke test。
- [ ] 跑主动 A2A 成功/失败两轮、候选被锁跳过、被动邀请接受/拒绝测试。
- [ ] 部署后观察 passive matching 日志，确认旧的直接建房链路不再出现。
- [ ] 确认生产 DB 中 memory 相关表结构存在。
- [ ] 明确回滚策略：保留上一个可部署 commit 和数据库备份。

## 5. 域名和 HTTPS

- [ ] DNS 指向服务器。
- [ ] Nginx 反代 API 和 WebSocket。
- [ ] HTTPS 证书和自动续期。
- [ ] iOS base URL 切到 HTTPS 域名。
- [ ] Android base URL 和 WebSocket URL 切到 HTTPS/WSS。
- [ ] 移除 iOS ATS 临时放行。
- [ ] 移除 Android cleartext 临时放行。
- [ ] 重新跑 iOS、Android 真机 smoke test。

## 6. 正式上线前 P1

- [ ] 接入真实短信服务，关闭内测验证码模式。
- [ ] 用 Alembic 正式迁移替代运行时 `create_all()` 依赖。
- [ ] WebSocket ConnectionManager 改为 Redis Pub/Sub 或独立消息层。
- [ ] 定时匹配任务从 API 进程拆到独立 worker。
- [ ] PostgreSQL 定时备份、恢复演练和备份加密。
- [ ] 基础监控：API 健康、错误日志、磁盘、内存、DB 连接数。
- [ ] 生产 CORS 白名单收敛到正式域名。
- [ ] 准备 App Store 素材、隐私政策、用户协议和客服反馈入口。

