# Mac App Store 版

## 当前架构

- 主窗口使用 `WKWebView`，网页、词库、SQL.js 与 SQLite 种子数据库都随 App 离线打包。
- `appassets://` 资源处理器只读取 App Bundle 内的静态资源，不开放任意文件路径或网络请求。
- 发音通过 `WKScriptMessageHandler` 调用常驻的 `AVSpeechSynthesizer`。
- 翻译工具默认调用 macOS Translation framework 在设备本地翻译；可选 DeepL API 在线翻译（包含 API Free 月度字符额度）。停止输入约 0.6 秒后自动翻译，也可手动重试；选择 DeepL 后原文会在自动或手动翻译时发送到 DeepL，API Key 保存于 macOS 钥匙串，原文和译文不写入学习数据库。
- 学习数据库由 SQL.js 生成 SQLite 快照，通过窄接口原子写入 App Sandbox 的 `Application Support/IELTS Vocabulary Lab/learning.sqlite`。
- SQLite 导入和导出使用 macOS 文件面板，并由用户选择文件位置。
- 主 App 启用 App Sandbox 与 Hardened Runtime；为嵌入式 WebKit 进程读取离线资源申请网络客户端沙盒能力，但运行时不启动 Python、不监听 localhost，也不依赖外部浏览器。导航委托阻止学习页发起外部 HTTP/HTTPS 导航。
- `PrivacyInfo.xcprivacy` 声明本地设置与小组件计时使用的 Required Reason APIs；不收集应用内学习数据、不进行跟踪。
- `vendor/sql-wasm.js` 和 `vendor/sql-wasm.wasm` 使用 sql.js 项目当前 MIT License；随分发包附带 `Resources/site/vendor/THIRD-PARTY-LICENSES.txt`。
- WidgetKit 扩展保留沙盒签名、App Intents 元数据和现有桌面词卡。

静态网页开发与自托管仍可继续运行 `python3 serve.py`。该路径独立于 Mac App Store App。

## 版本与构建

工程当前版本为 2.0（16）。需要完整 Xcode 和已配置的 Apple Developer Team：

```sh
./mac/build-app.sh
./mac/install-app.sh
```

构建使用 Xcode 工程中已设置的 Team 与自动签名。安装脚本会在替换应用前校验签名；旧应用只在安装过程中临时保留用于失败回滚，安装成功后自动清理。

创建 App Store Connect 记录并确认它登记了工程当前的 Bundle ID 后，配置 Mac App Store 分发签名；如果当前 ID 尚未登记，就创建 ASC App 记录并把工程与 Widget 的 Bundle ID 改成已登记标识。之后在 Xcode 选择 `Any Mac`，执行 Product → Archive，再从 Organizer 验证与上传。

上传前还需要完成应用名称、说明、截图、隐私问卷、年龄分级、支持网址和隐私政策等 App Store Connect 元数据。App 现在仅在用户通过菜单栏选择后启用登录时启动，不会在首次启动时自行注册。当前工作树完成了沙盒化与离线运行架构；尚未配置 App Store Connect 标识和分发签名，也没有归档、上传或提交审核。

## 旧版学习数据迁移

旧静态网页把学习数据库存在浏览器的 IndexedDB 中。新 Mac App 使用独立的沙盒 SQLite 文件，系统不会自动把某个浏览器的 IndexedDB 复制到应用容器。

1. 在旧网页的“学习统计”页选择“导出学习数据”，保存 SQLite 文件。
2. 打开新版 Mac App，进入“学习统计”，选择“导入学习数据”。
3. 在 macOS 文件面板中选中刚导出的 `.sqlite` 文件，导入完成后刷新统计视图。

导入会用选择的数据库替换当前 App 学习库；新安装且尚未记录学习数据时直接导入即可。网页和 App 不会自动同步，建议迁移后保留导出的备份。

## 提交前检查

- 使用 App Store Connect 中已登记的 Bundle ID 和有效 Apple Distribution 配置归档。
- 在干净的 macOS 用户账户中验证首次启动、无网络启动、数据库写入、重启后数据保留及 SQLite 导入导出。
- 验证系统小组件安装、设置、发音及 Widget 到主 App 的学习页深链。
- 随包提供第三方许可与致谢页面，并核对 App Store Connect 对 WebKit、WidgetKit 和登录项行为的当前审核要求。
- 核对 App Store 隐私问卷、支持页面、隐私政策和截图。应用不上传学习数据，也没有分析或广告 SDK。
- 随包提供第三方许可文件，并核对 App Store Connect 对 WebKit、WidgetKit 和登录项行为的当前审核要求。
- 通过 App Store Connect TestFlight 或审核流程做最终签名与安装验证。
