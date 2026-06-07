# i搭不搭

`i搭不搭` 项目主仓库，当前统一管理 iOS 客户端、FastAPI 后端、文档和实验代码。

## 目录

- `dazi/`：iOS SwiftUI 客户端。
- `dazi-server/`：FastAPI 后端服务。
- `dazi_doc/`：产品、架构、模块、部署和上线文档。
- `labs/`：独立实验和 prompt 验证代码。

## 常用命令

后端测试：

```bash
cd dazi-server
.venv311/bin/python -m pytest
```

iOS Debug 构建：

```bash
xcodebuild -project dazi.xcodeproj -scheme dazi -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

## iOS 两人协作：Bundle ID 本地私有配置

为避免两个人都用同一个 `Bundle ID` 导致真机安装互相覆盖，项目已支持本地覆盖个人后缀。

### 1. 仓库默认

- 发布/打包用 `com.linke.dazi`
- 本地真机调试可改成：
  - `com.linke.dazi.dev.你的名字`

### 2. 每位开发者设置自己的个人后缀

在你本地新增文件（不提交）：

```text
Config/BundleID.local.xcconfig
```

内容示例：

```xcconfig
APP_BUNDLE_ID_SUFFIX = .dev.yourname
```

`yourname` 改成你自己的唯一标识（英文拼音/英文名均可）。

### 3. 签名流程

1. Xcode 打开 `dazi.xcodeproj`
2. 选 `dazi` Target 的 `Signing & Capabilities`
3. `Team` 选你自己的 Personal Team（本地真机调试）
4. `Bundle Identifier` 使用默认值（已从配置读取）
5. Debug 真机运行即可自动使用你本地后缀

### 4. 注意

- `BundleID.local.xcconfig` 已加入 `.gitignore`，不会提交到仓库。
- App Store / TestFlight 走 `Release` 配置，不受本地后缀影响。

### 5. 最短操作清单（给合作者）

1. `git checkout main && git pull`
2. 新建 `Config/BundleID.local.xcconfig`，写 `APP_BUNDLE_ID_SUFFIX = .dev.你的名字`
3. 打开 Xcode，`dazi` Target 的 `Signing & Capabilities` 选自己的 Personal Team
4. Build/Run 到真机（Debug）
