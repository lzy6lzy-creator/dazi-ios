# i搭不搭邀请码系统设计

## 1. 目标

用可增长、可审计的邀请码机制替换 App 内手机号白名单，同时保留 TestFlight 作为 iOS 安装分发渠道。

本设计解决四个问题：

1. 上海冷启动期间允许新用户免邀请码注册。
2. 只有真实定位在上海并完成核心行为的用户才能获得邀请额度。
3. 当 500 名不同用户获得过邀请额度后，自动关闭免邀请码注册。
4. 邀请链接同时支持当前的 TestFlight 外部测试和未来的 App Store 正式下载。

## 2. 已确认的产品决策

| 主题 | 决策 |
| --- | --- |
| TestFlight | 保留为安装分发渠道，与 App 内注册准入解耦 |
| 冷启动范围 | 上海 |
| 冷启动统计口径 | 获得过任意邀请额度的上海定位用户数，不是注册人数 |
| 自动关闸阈值 | 500 名不同用户 |
| 切换方式 | 达到 500 后硬切换为 `invite_only` |
| 切换保护 | 关闸前签发的免码准入凭证继续有效 10 分钟 |
| 首次发布奖励 | 3 次邀请 |
| 首次匹配奖励 | 2 次邀请 |
| 邀请码形式 | 一个长期个人码，加减可用次数 |
| 分享方式 | 链接优先，海报与复制邀请码作为补充 |
| 安装渠道 | 当前外部 TestFlight Public Link，未来切换 App Store |
| 老用户 | 登录永远不需要邀请码；符合历史里程碑时可补领奖励 |

## 3. 非目标

- 不用邀请码替代 TestFlight 的安装资格。
- 不把官网内测报名记录当作 App 注册白名单。
- 不按每次活动发布重复发放邀请码。
- 不长期保存精确定位坐标。
- 第一版不依赖第三方 deferred deep link SDK。
- 不在异常时回退到手机号白名单。

## 4. 现有系统上下文

当前后端的 `/api/v1/auth/send-code` 和 `/api/v1/auth/login` 同时承担手机号验证和首次注册：

- `send-code` 只允许手机号白名单中的号码继续。
- `login` 首次成功时自动创建 `User` 和默认 `Agent`。
- 内测验证码来自固定环境变量，并没有真正发送短信。
- 白名单来自环境变量和 `internal_test_phones.txt`，运行时动态读取。

官网报名和 App Store Connect/TestFlight 邀请是另一条链路。邀请码上线后，官网报名仍可保留为获客和通知渠道，但不得再向手机号白名单写入数据。

客户端已经具备设备定位能力，但当前只把反向地理编码后的文本用于资料和活动上下文。新机制需要增加一个专门的定位资格验证接口，把短时坐标发送给服务端判定是否在上海。

## 5. 用户生命周期

### 5.1 冷启动开放期

1. 新用户提交手机号并请求验证码，不需要邀请码。
2. 服务端签发 10 分钟有效的 `open` 类型注册准入凭证。
3. 用户完成短信核验后创建账号。
4. 用户可以正常使用 App；定位不是注册前置条件。
5. 用户完成一次有效上海定位后，才有资格领取邀请奖励。
6. 首次有效发布活动，增加 3 次邀请。
7. 首次成功匹配并真正创建聊天室，增加 2 次邀请。
8. 第一次奖励到账时创建长期个人邀请码。

### 5.2 达到 500 人

“获码用户”定义为同时满足以下条件的不同用户：

- 存在有效上海定位资格；
- 至少有一笔正向邀请奖励流水；
- 邀请账户没有因数据修复被删除。

同一用户获得 `3+2` 仍只计为 1 人。第 500 位用户的首次奖励入账和注册模式切换必须在同一事务和数据库锁内完成。成功后 `registration_mode` 从 `open` 变为 `invite_only`。

关闸前已经签发的 `open` 准入凭证可在 10 分钟有效期内继续完成注册。新请求必须提供邀请码。

### 5.3 邀请注册期

1. 好友打开 `https://idabuda.com/i/{code}`。
2. 落地页查询邀请码是否存在、可用和未冻结，但不暴露邀请人隐私。
3. 用户请求短信验证码时，服务端为有效邀请码预占 1 个名额，预占有效期 10 分钟。
4. 短信核验成功后，在同一事务中创建新用户、把预占转为正式兑换并记录 `-1` 流水。
5. 短信失败、登录中断或准入过期不会正式扣减名额。
6. 已有用户登录永远不检查邀请码，也不消耗邀请额度。

## 6. 奖励资格

### 6.1 上海定位

- 使用客户端刚获取的设备坐标，时间不得早于请求前 5 分钟。
- 定位精度必须不差于 1 公里。
- 服务端用上海行政区边界多边形完成 point-in-polygon 判定，不信任客户端提交的城市文字。
- 验证结果有效 30 天。
- 数据库只保存用户、是否在上海、精度、验证时间和风险标志，不保存精确经纬度。
- 定位缺失、过期或不在上海不影响使用 App，只使奖励进入 `pending_location`。
- 用户后续重新定位到上海时，系统自动结算所有待领取里程碑。

### 6.2 首次有效发布

以下行为触发一次 `first_event_publish` 里程碑：

- 用户本人新建并成功公开一个 Event；
- Event 已通过现有必填字段和内容校验；
- 不是编辑、恢复、迁移或管理员代建；
- 该用户以前没有成功结算过同一里程碑。

奖励为 `+3`。活动创建成功不能依赖奖励服务成功；奖励写入失败时通过持久任务重试。

### 6.3 首次成功匹配

只有匹配流程真正创建聊天室并进入成功匹配状态时，才触发 `first_match`。候选召回、匹配分数或未接受的 A2A 结果不算成功匹配。

双方用户分别判断资格，符合条件者各获得 `+2`，终身只结算一次。

### 6.4 老用户补发

上线前已经发布或匹配过的用户生成待领取里程碑：

- 有历史有效活动：待领取 `+3`；
- 有历史成功聊天室：待领取 `+2`。

不能用资料里的 `city=上海` 直接发放。老用户完成一次真实上海定位后才结算，并计入 500 人。无论是否领取，老用户登录不受邀请码限制。

## 7. 分享和安装体验

### 7.1 邀请中心

个人中心增加“邀请好友”入口，展示：

- 剩余邀请次数；
- 长期个人邀请码；
- 首次发布、首次匹配奖励状态；
- 主按钮“邀请微信好友”；
- 次级入口“更多分享方式”，包含海报、复制链接和复制邀请码。

默认分享链接为 `https://idabuda.com/i/{code}`。分享文案使用产品名 `i搭不搭`，不出现具名助理人格。

### 7.2 当前：外部 TestFlight

- App Store Connect 创建 External Testing 分组并通过 TestFlight Beta Review。
- 使用 TestFlight Public Link 分发，不再依赖内部测试人员名额。
- 邀请落地页主按钮为“通过 TestFlight 安装”。
- 安装后用户回到落地页，点击“已安装，打开 i搭不搭”。
- Universal Link 把邀请码交给 App，并自动填入注册页。
- 页面始终显示可复制邀请码，作为安装中断和深链失败兜底。

### 7.3 未来：App Store

邀请链接保持不变，只把后台 `ios_distribution_mode` 从 `testflight` 切换为 `app_store`，并配置 App Store URL。

正式上架后：

- 已安装 App 时，Universal Link 直接打开注册页；
- 未安装时，落地页跳转 App Store；
- 页面使用 Smart App Banner 和 `app-argument` 保留邀请上下文；
- 手动邀请码仍然作为最终兜底。

第一版不承诺安装过程中的无感 deferred deep link。只有漏斗数据证明安装中断损耗明显时，才评估第三方归因/延迟深链 SDK。

### 7.4 域名配置

- iOS target 增加 `applinks:idabuda.com` Associated Domains。
- `idabuda.com/.well-known/apple-app-site-association` 声明 `/i/*` 路径。
- Android 增加对应 App Link 和 `assetlinks.json`。
- App 收到 URL 后只解析格式，邀请码有效性始终由服务端重新验证。

## 8. 短信认证与密钥交付

用户开通的是阿里云号码认证服务 PNVS 的短信认证能力。后端使用：

- `SendSmsVerifyCode` 发送由阿里云动态生成的验证码；
- `CheckSmsVerifyCode` 核验验证码，并以 `Model.VerifyResult == PASS` 为成功条件。

建议验证码参数：

- 纯数字 6 位；
- 有效期 300 秒；
- 同手机号发送间隔至少 60 秒；
- 重发时覆盖旧验证码；
- 不要求接口返回明文验证码。

### 8.1 RAM 权限

不要使用阿里云主账号 AccessKey。创建只用于 `i搭不搭` 生产后端的 RAM 程序用户，并只授予：

```json
{
  "Version": "1",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dypns:SendSmsVerifyCode",
        "dypns:CheckSmsVerifyCode"
      ],
      "Resource": "*"
    }
  ]
}
```

如条件允许，限制 AccessKey 只能从生产服务器公网 IP 调用，并定期轮转。

### 8.2 配置项

在本地被 Git 忽略的 `dazi-server/.env` 中配置，绝不能把真实值发到聊天、写进代码、提交到 Git 或放入设计文档：

```dotenv
ALIYUN_DYPNS_ACCESS_KEY_ID=请填RAM用户AccessKeyId
ALIYUN_DYPNS_ACCESS_KEY_SECRET=请填RAM用户AccessKeySecret
ALIYUN_DYPNS_REGION_ID=cn-hangzhou
ALIYUN_DYPNS_SCHEME_NAME=默认方案或控制台中的方案名称
ALIYUN_DYPNS_SIGN_NAME=控制台显示的赠送签名
ALIYUN_DYPNS_TEMPLATE_CODE=100001
ALIYUN_DYPNS_ENABLED=true
```

仓库只提交同名空占位的 `.env.example`。生产部署时把值写入服务器 `/opt/dazi-server/.env`；现有同步和部署流程必须继续排除 `.env`。

实现阶段只需要用户确认变量已经填好，不需要读取或打印 Secret。验证脚本必须隐藏手机号和 AccessKey，只输出请求 ID、状态码和脱敏号码。

### 8.3 频控

阿里云频控之外，服务端再增加：

- 同手机号 60 秒内最多发送一次；
- 同手机号每天最多 10 次；
- 同 IP 每小时最多 30 次；
- 连续验证码错误 5 次后冻结该 admission；
- API 响应不区分“手机号已注册”与“未注册”，减少账号枚举。

## 9. 数据模型

### 9.1 `invitation_programs`

单行活动配置：

- `id`
- `registration_mode`: `open | invite_only | paused`
- `launch_city_code`: `310000`
- `qualified_target`: 默认 `500`
- `location_valid_days`: 默认 `30`
- `qualified_user_count`: 事务内维护的缓存计数
- `ios_distribution_mode`: `testflight | app_store`
- `testflight_public_url`
- `app_store_url`
- `transitioned_at`
- `updated_by`
- `created_at`, `updated_at`

`qualified_user_count` 是便于关闸和后台展示的缓存；审计和修复时以奖励账户和流水重新计算。

### 9.2 `user_invitation_accounts`

- `user_id`，主键和外键
- `code`，唯一、大小写不敏感
- `granted_total`
- `consumed_total`
- `reserved_total`
- `status`: `active | suspended`
- `first_qualified_at`
- `created_at`, `updated_at`

可用次数为 `granted_total - consumed_total - reserved_total`，必须大于等于 0。

邀请码使用不包含易混字符的 8 位大写字母和数字，并由加密安全随机数生成；发生唯一键冲突时重试。

### 9.3 `invitation_ledger`

- `id`
- `user_id`
- `entry_type`: `first_event | first_match | redemption | admin_adjustment | repair`
- `amount`: `+3`、`+2`、`-1` 或人工调整值
- `idempotency_key`，唯一
- `source_event_id`
- `source_chat_room_id`
- `invitee_user_id`
- `location_verification_id`
- `operator_id`
- `reason`
- `created_at`

余额缓存和流水必须在同一事务更新。

### 9.4 `signup_admissions`

- `id`
- `phone`
- `admission_type`: `open | invitation`
- `invitation_account_user_id`
- `status`: `issued | verified | consumed | expired | cancelled`
- `install_id_hash`
- `ip_hash`
- `expires_at`
- `consumed_at`
- `created_at`

邀请码模式下创建 admission 时把账户 `reserved_total + 1`。过期、取消或失败后释放预占；注册成功时 `reserved_total - 1`、`consumed_total + 1`，并写 `-1` 流水。

### 9.5 `location_verifications`

- `id`
- `user_id`
- `city_code`
- `is_launch_city`
- `accuracy_meters`
- `risk_flags`
- `verified_at`
- `expires_at`

不保存经纬度。

## 10. 服务边界

### `RegistrationPolicyService`

- 返回当前注册模式和客户端展示文案；
- 签发开放期 10 分钟准入；
- 在 500 人关闸时执行行锁和状态转换；
- 支持管理员提前关闭、临时重开或暂停新注册。

### `InvitationService`

- 创建长期个人码；
- 查询余额和奖励状态；
- 创建、释放和消费预占；
- 冻结邀请码；
- 生成邀请关系和审计流水。

### `InvitationRewardService`

- 接收发布和匹配里程碑；
- 用唯一 `idempotency_key` 保证只结算一次；
- 定位无效时记录待领取状态；
- 结算第一笔奖励时增加获码用户计数并检查 500 阈值；
- 用持久任务重试，不让奖励故障回滚活动或匹配。

### `LocationEligibilityService`

- 校验坐标时间和精度；
- 判断是否在上海行政边界内；
- 只保存资格结论；
- 定位成功后触发待领取奖励结算。

### `SmsVerificationService`

- 封装阿里云 SDK；
- 发送和核验验证码；
- 执行应用侧频控和脱敏日志；
- 本地/测试环境可注入 fake provider，生产禁止固定万能验证码。

## 11. API 契约

### 公开与认证 API

| Method | Path | 用途 |
| --- | --- | --- |
| `GET` | `/api/v1/auth/registration-policy` | 返回 `open/invite_only/paused` 和是否需要邀请码 |
| `POST` | `/api/v1/auth/send-code` | 校验注册策略、邀请码并发送短信，返回 admission token |
| `POST` | `/api/v1/auth/login` | 核验短信；新用户消费 admission，老用户直接登录 |
| `POST` | `/api/v1/location/verify` | 提交短时坐标并返回上海资格状态 |
| `GET` | `/api/v1/invitations/me` | 返回个人码、余额、奖励和待领取状态 |
| `GET` | `/api/v1/invitations/{code}/status` | 落地页查询邀请码是否可用，不返回邀请人隐私 |
| `GET` | `/i/{code}` | Web 邀请落地页 |

`send-code` 请求增加可选 `invite_code` 和 `install_id`。服务端先按手机号查询是否已有 User：已有用户在任何注册模式下都可以发送验证码，不要求邀请码；只有新用户才执行 `open/invite_only/paused` 准入策略。对外响应保持相同结构，不能借此枚举手机号是否已注册。响应增加 `admission_token`、`expires_in` 和 `registration_mode`。

`login` 请求增加可选 `admission_token`。处理顺序为：

1. 核验短信；
2. 查询手机号是否已有 User；
3. 老用户直接发 token；
4. 新用户必须提交有效 admission；
5. 同事务创建 User、Agent 和 invitation redemption；
6. admission 标记为 consumed。

### 管理 API

- 查看和修改 invitation program；
- 查看冷启动进度和重算结果；
- 查询个人码、余额、奖励、兑换和邀请链；
- 冻结或恢复邀请码；
- 人工增减额度，必须填写原因；
- 切换 TestFlight/App Store 分发地址；
- 查看异常频控、奖励重试和关闸审计。

## 12. 客户端改动

### iOS

- 登录页在 `invite_only` 时显示邀请码输入框；Universal Link 自动填入。
- 删除白名单错误文案和固定验证码自动填入。
- 增加邀请中心、系统分享、邀请海报和复制动作。
- 增加上海定位领奖提示和待领取状态。
- 支持 `/i/*` Universal Links。
- TestFlight 真机验证安装后返回邀请页再打开 App 的路径。

### Android

- 与 iOS 使用同一注册策略、邀请码和奖励 API。
- 增加 App Links、邀请中心和定位资格上传。
- 删除白名单错误文案和内部测试验证码假设。

老版本客户端在 `invite_only` 上线后可能无法展示邀请码输入框，因此正式关闸前必须确保最低可用版本已经发布，并通过后端强制升级或清晰错误引导阻止旧版本尝试注册。老用户登录仍保持兼容。

## 13. 管理后台

后台增加“邀请码”面板：

- 冷启动进度：`qualified_user_count / 500`；
- 当前注册模式和最近切换时间；
- TestFlight/App Store 分发模式和 URL；
- 获码用户、总发放、已消费、已预占和剩余额度；
- 分享打开、安装点击、App 打开、注册、发布和匹配漏斗；
- 搜索个人码、邀请人或被邀请人；
- 冻结码、人工调额度和审计历史；
- 奖励失败任务与手动重试。

## 14. 并发与一致性

- 个人账户行在预占、释放、消费和发奖时使用 `SELECT ... FOR UPDATE`。
- `idempotency_key` 唯一索引阻止重复奖励。
- `invitee_user_id` 在 redemption 流水中唯一，阻止同一新账号重复归因。
- 第一次正向奖励在 program 行锁内更新获码人数并检查阈值。
- admission 过期释放任务可重复执行，状态机保证只释放一次。
- 后台重算人数只修正缓存，不修改历史流水。

## 15. 异常处理

| 场景 | 行为 |
| --- | --- |
| 邀请码不存在、冻结或用完 | 统一提示“邀请码不可用”，允许改填，不暴露邀请人 |
| 最后一个名额被并发使用 | 只有成功预占者继续，余额不为负 |
| admission 过期 | 释放预占并要求重新发送验证码 |
| 定位缺失或过期 | App 可用，奖励显示待领取 |
| 定位不在上海 | App 可用，不发奖励，不计入 500 |
| 奖励写入失败 | 活动/匹配成功，持久任务重试 |
| TestFlight 审核中或名额已满 | 落地页显示状态并收集通知意向，不回退白名单 |
| 深链失败 | 展示并允许复制邀请码 |
| 阿里云短信不可用 | 不创建新注册；老用户可在短信恢复后登录，不启用万能码 |
| 注册模式 `paused` | 现有用户可登录，新用户看到维护提示 |

## 16. 白名单下线范围

在新客户端、真实短信和邀请系统验证完成后删除：

- `/auth/send-code` 和 `/auth/login` 的手机号白名单判断；
- `INTERNAL_TEST_PHONES` 与 `INTERNAL_TEST_PHONES_FILE` 生产配置；
- `internal_test_phones.txt` 的运行时挂载和热加载；
- iOS/Android 白名单错误文案和固定验证码自动填入；
- 官网报名邀请后写入手机号白名单的逻辑；
- 白名单热更新脚本、测试和运维说明。

保留官网 `beta_signups` 数据和 TestFlight 分发能力，但将它们改为通知、外部测试和运营分析用途。

本地测试可使用注入的 fake SMS provider；不要把生产固定验证码作为调试回退。

## 17. 上线顺序

1. 无行为变更部署：新增模型、服务、管理配置和观测。
2. 接入阿里云 PNVS 短信并完成频控、脱敏和失败测试。
3. 发布支持邀请码、定位和深链的新 iOS/Android 客户端。
4. 配置 TestFlight External Testing、Public Link、AASA 和 Android App Links。
5. 运行老用户历史里程碑扫描，生成待领取记录。
6. 把注册模式切换为 `open`，关闭手机号白名单。
7. 观察短信成功率、注册漏斗、奖励和定位异常。
8. 达到 500 人后系统自动切到 `invite_only`。
9. 稳定运行后删除白名单遗留代码和运维资产。

任何阶段需要止损时，使用 `paused` 暂停新注册；不要恢复手机号白名单。已有用户登录和已发布活动不受影响。

## 18. 测试与验收

### 后端单元与集成测试

- `open` 模式不需要邀请码，`invite_only` 必须提供。
- 老用户在任何模式都不检查邀请码。
- 上海边界、边缘点、过期定位和低精度定位。
- 首次发布只发一次 `+3`。
- 首次匹配只发一次 `+2`。
- 老用户历史里程碑只补发一次。
- 第 500 人触发模式切换。
- 关闸前签发的开放 admission 在 10 分钟内继续有效。
- 邀请预占、过期释放、注册消费和失败回滚。
- 多并发消费最后一个名额时只有一个成功。
- 短信发送频控和核验以 `VerifyResult == PASS` 为准。
- 奖励任务失败后可幂等重试。
- 管理员调整、冻结和重算全部留审计记录。

### 客户端与真机测试

- 分享到微信、复制链接和海报。
- 已安装 App 时 Universal Link 自动填码。
- 未安装时通过外部 TestFlight 安装，返回页面后打开 App 并填码。
- 深链失败时手动复制和填写。
- 定位拒绝、过期、上海和非上海状态。
- 老版本客户端在关闸后的升级提示。
- iOS 和 Android 登录、分享和奖励状态一致。

### 生产验收

- 生产登录链路不再读取手机号白名单。
- 生产固定验证码不可用。
- `.env` 不在同步内容、Git 历史或日志中。
- 阿里云短信请求和手机号日志均脱敏。
- 邀请余额无负数，奖励无重复，获码人数可重算。
- 管理后台可解释每一笔发放和消费。
- 公开 UI 统一使用 `i搭不搭`，不出现具名助理人格。

## 19. 参考资料

- [阿里云号码认证服务：短信认证服务](https://help.aliyun.com/zh/pnvs/user-guide/sms-authentication-service)
- [阿里云 PNVS：SendSmsVerifyCode](https://help.aliyun.com/zh/pnvs/developer-reference/api-dypnsapi-2017-05-25-sendsmsverifycode)
- [阿里云 PNVS：CheckSmsVerifyCode](https://help.aliyun.com/zh/pnvs/developer-reference/api-dypnsapi-2017-05-25-checksmsverifycode)
- [阿里云 RAM：创建 AccessKey](https://help.aliyun.com/zh/ram/user-guide/create-an-accesskey-pair)
- [Apple：TestFlight 外部测试](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- [Apple：Supporting Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
- [Apple：Smart App Banners](https://developer.apple.com/documentation/webkit/promoting-apps-with-smart-app-banners)
