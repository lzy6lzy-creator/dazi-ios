# 代码健康审查

最后更新：2026-08-29

## 范围

本次审查覆盖当前发布主线：iOS SwiftUI 客户端、FastAPI 后端、生产配置和 `dazi_doc` 当前文档。Android 仓库有独立未整理改动，本次不修改，也不声明其功能与 iOS 一致。

## 已完成清理

- iOS access/refresh token 从 `UserDefaults` 迁移到 Keychain，并自动迁移旧值。
- 修复 WebSocket 被误标为主动关闭、掉线不重连的问题；连接改用 Bearer header，并忽略旧 task 的延迟回调。
- 真机消息提醒只由 APNs 展示，模拟器保留本地通知回退，避免前台重复横幅。
- iOS 26 反向地理编码从已弃用的 `CLGeocoder` 迁移到 MapKit。
- 注册、编辑个人资料和编辑 Agent 改为服务端保存成功后再更新本地状态。
- API 增加正文、资料、列表和分页边界；管理 token 使用常量时间比较。
- 删除独立 draft 模型配置、统一后台替代后的 `match_test.html`，以及未使用的密码/表单/迁移运行时依赖。
- 管理后台删除已失效的事件城市筛选和统计，事件地点统一展示 `location`。
- 活动评价接入 `event_feedbacks` 后端表，分别保存体验/搭子评分与评论，并在双方结束后关闭聊天室。
- 用户和 Agent 图片头像接入持久化媒体目录、内容校验、跨设备 URL 展示和注销清理。

## 仍需产品或架构决策

### 高优先级

1. **活动相册存储会随照片数量退化。** `GalleryStore` 把所有照片编码进一个 JSON 文件并在主线程同步读写，应改为独立图片文件/对象存储与轻量元数据索引。

### 扩容前

1. `GET /api/v1/chat/rooms` 对每个房间继续查询当前成员、事件、成员资料、最新消息和未读状态，属于 N+1 查询；应批量查询或使用明确的 eager loading。
2. WebSocket 连接表只存在单个 API 进程内；多 worker/多实例前需要 Redis Pub/Sub 或独立消息层。
3. 匹配、内测邀请和提醒监控都运行在 API 进程内；扩容前应迁到独立 worker，并增加分布式锁。
4. 数据库仍依赖 `create_all()` 和启动时 `ALTER TABLE`，缺少可审计、可回滚的迁移版本。
5. `/health` 只检查进程存活；应增加 PostgreSQL/Redis readiness 和外部服务指标。

### 工程保障

1. iOS 目前只有 Python 静态源码回归和编译验证，没有 XCTest/UI Test target，手势、前后台、权限、Keychain、推送和断线重连仍需真机测试。
2. 仓库没有 GitHub Actions；提交和部署前的测试依赖人工执行。
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
```

本机没有 Docker CLI，因此 `docker compose config` 和容器级 smoke test 需要在装有 Docker 的环境或生产服务器执行。
