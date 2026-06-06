# i搭不搭 文档中心

最后更新：2026-06-05

## 阅读顺序

这组文档只保留当前有效版本，不再按日期保存多份旧稿。历史实验细节保留在代码、测试和实验数据里，文档只写产品判断、系统边界和可执行结论。

1. [PRD](prd.md)：产品定位、用户流程、核心功能和上线范围。
2. [系统架构](architecture.md)：客户端、后端、数据、LLM、匹配和部署的整体关系。
3. [API Reference](api_reference.md)：移动端、管理端、WebSocket 和公开页面接口清单。
4. [Agent 与 Memory 设计](modules/agent-memory.md)：AI 搭子经纪人、事件抽取、澄清卡片、长期记忆。
5. [匹配系统设计](modules/matching.md)：主动匹配、被动邀请、A2A 精排、黑名单和投票。
6. [地点匹配设计](modules/location-matching.md)：地点解析、活动严格度、评测结论和上线策略。
7. [客户端设计](modules/clients.md)：iOS/Android 的信息架构和体验原则。
8. [部署与运维](ops/deployment.md)：生产环境、同步规则、健康检查和常用命令。
9. [上线清单](ops/launch-checklist.md)：TestFlight、内测、域名、正式上线前事项。
10. [地点匹配评测摘要](reports/location-matching-eval.md)：当前最新评测结果和复跑入口。

## 文档维护规则

- 产品名统一写作 `i搭不搭`，首字母 `i` 保持小写。
- 文档不保存真实密钥、密码、手机号白名单、root 登录信息或可复用 token。
- 只保留一个当前版本；重要变更直接改正文，不再新增 `v1`、`v2`、日期版副本。
- 设计文档写“当前选择”和“下一步”，实验报告只保留最新结论。
- 代码事实以仓库当前实现为准，文档更新应尽量引用实际路径。

## 仓库边界

顶层 `/Users/wuxing/Desktop/dazi` 不是 git 仓库。当前文档位于 iOS 仓库：

```text
/Users/wuxing/Desktop/dazi/dazi/dazi_doc
```

相关代码仓库：

- iOS：`/Users/wuxing/Desktop/dazi/dazi`
- Android：`/Users/wuxing/Desktop/dazi/dazi-android`
- 后端：`/Users/wuxing/Desktop/dazi/dazi-server`

