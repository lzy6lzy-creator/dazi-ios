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
