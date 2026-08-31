# 2026-08-31 本轮验收

## 已完成

1. 生产基线修复部署与 API 冒烟验证。
2. 活动评价持久化，双方结束后再关闭共享聊天室。
3. 用户与 AI 自定义头像持久化、跨设备同步。
4. 相册持久化与访问权限校验。
5. 聊天室列表固定批量查询；20 个房间实测 7 次 SQL。
6. Alembic 迁移、独立 worker、跨进程实时消息、readiness、加密备份和基础巡检。
7. XCTest/UI 测试、GitHub CI，以及 TestFlight 内部测试发布。

## 自动验证

| 项目 | 结果 |
| --- | --- |
| 后端 pytest | 353 passed，26 subtests passed |
| iOS 静态回归 | 67 passed |
| 原生 XCTest/UI | 14 单元测试 + 2 UI 测试，全部通过 |
| 小屏幕复测 | iPhone 16e 上 2 项 UI 测试通过 |
| GitHub Actions | backend、ios 两个作业均 success |
| 生产迁移 | 0003_reconcile_legacy_schema；alembic check 无差异 |
| WebSocket | 子进程发布经 Redis 到公网 WSS，单次投递 |
| worker 向量调用 | 返回 768 维向量，worker 未加载本地模型 |
| 备份恢复 | 27 张业务表恢复通过，损坏密文拒绝，无临时库遗留 |
| 基础巡检 | 首轮全部通过，每五分钟执行 |

代码验收提交为 `ae3407b470dbbf1e262a4c39508a0195ad161034`。
[CI 运行记录](https://github.com/lzy6lzy-creator/dazi-ios/actions/runs/33371024684)
包含后端 JUnit 与 iOS xcresult 工件，保留 7 天。

原生测试使用模拟器 ad-hoc 签名，真实运行 Keychain 存取/迁移，不以 mock 绕过。
UI 测试使用隔离数据验证活动左右翻页与筛选；不登录真实用户、不发送短信、不修改生产活动。
Release 二进制检查未包含 Debug 测试入口。

## TestFlight

- App：6776567684，Bundle ID：`com.linke.dazi`。
- 版本：1.1 (11)。
- Apple processingState：`VALID`。
- internalBuildState：`IN_BETA_TESTING`。
- 现有内部测试组具有所有构建访问权限，不需要新增测试者邀请。
- 分发签名的 `aps-environment` 为 `production`。
- 有效期：北京时间 2026-11-29 16:05:20。
- externalBuildState：`READY_FOR_BETA_SUBMISSION`；本轮未提交外部 Beta 审核或 App Store 正式上架审核。

## 尚未完成

- 真机完整主链路与异常流程，尤其是首次联网/定位授权、前后台切换、APNs 和长时间断线恢复。
- App Store 正式上架所需的隐私声明、年龄分级、审核资料和最终提交。
- 持续异地备份、外部故障通知、HTTPS 自动续期机制核实；已保存本机恢复副本，但不等同持续异地同步。
- 原审查保留的 refresh token 会话级轮换与吊销。当前仍是无服务端会话的 JWT，不应称为安全 TODO 已清零。

Android 不在本轮范围。
