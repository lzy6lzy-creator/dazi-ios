# 代码健康审查

最后更新：2026-08-31

## 范围

本次审查覆盖当前发布主线：iOS SwiftUI 客户端、FastAPI 后端、生产配置和 `dazi_doc` 当前文档。Android 仓库有独立未整理改动，本次不修改，也不声明其功能与 iOS 一致。

## 已完成清理

- iOS access/refresh token 从 `UserDefaults` 迁移到 Keychain，并自动迁移旧值。
- 修复 WebSocket 被误标为主动关闭、掉线不重连的问题；连接改用 Bearer header，并忽略旧 task 的延迟回调。
- 真机消息提醒只由 APNs 展示，模拟器保留本地通知回退，避免前台重复横幅。
- iOS 26 反向地理编码从已弃用的 `CLGeocoder` 迁移到 MapKit。
- 注册、编辑个人资料和编辑 Agent 改为服务端保存成功后再更新本地状态。
- API 增加正文、资料、列表和分页边界；管理 token 使用常量时间比较。
- 删除独立 draft 模型配置、统一后台替代后的 `match_test.html`，以及未使用的密码/表单依赖。Alembic 已接入实际迁移流程。
- 管理后台删除已失效的事件城市筛选和统计，事件地点统一展示 `location`。
- 活动评价接入 `event_feedbacks` 后端表，分别保存体验/搭子评分与评论，并在双方结束后关闭聊天室。
- 用户和 Agent 图片头像接入持久化媒体目录、内容校验、跨设备 URL 展示和注销清理。
- 活动相册迁移为服务端媒体 + 数据库元数据，公开读取同时受主页可见性和单项展示开关控制。
- 聊天室列表改为固定 7 次查询，已用生产数据库事务验证 20 个房间。
- Alembic 基线、历史 schema 对齐和 HNSW 索引声明已接入，生产库检查无结构差异。
- WebSocket 使用 Redis 跨进程分发并防重复；定时任务迁到独立 worker，以数据库会话锁互斥。
- 增加数据库/Redis/迁移/WebSocket readiness、worker 心跳，以及生产 CORS 正式域名白名单。

## 仍需产品或架构决策

### 运维收尾

1. PostgreSQL 与媒体已有加密备份、临时库恢复验证及每日定时器；持续异地存储仍待配置。
2. 已有每五分钟 API、资源、数据库连接和错误日志巡检；外部通知渠道仍待配置。
3. worker 运行日志见 `docker compose logs worker`；后台内存日志窗口只显示 API 进程，持久化匹配详情仍来自数据库。

### 工程保障

1. 已增加 XCTest/UI Test target，本机 16 项通过，另在 iPhone 16e 重跑 2 项 UI 测试通过。前后台、系统权限、APNs 和 WebSocket 长时间断线恢复仍需真机验证。
2. 已增加 GitHub Actions，覆盖后端回归、迁移、跨进程消息和 iOS 原生测试；是否通过以对应 commit 的 Actions 结果为准。
3. refresh token 是无服务端会话的 30 天 JWT，普通退出无法撤销已泄露的 refresh token；正式上线前应引入会话 ID、轮换与吊销。

## 验证命令

```bash
cd /Users/wuxing/Desktop/dazi/dazi/dazi-server
.venv311/bin/python -m pytest -q
.venv311/bin/python -m pip check

cd /Users/wuxing/Desktop/dazi/dazi
python3 -m unittest discover tests
xcodebuild -project dazi.xcodeproj -scheme dazi \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' build

xcodebuild test -project dazi.xcodeproj -scheme dazi -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
```

本机没有 Docker CLI，因此 `docker compose config` 和容器级 smoke test 需要在装有 Docker 的环境或生产服务器执行。
