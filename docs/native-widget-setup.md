# macOS 系统小组件接入

更新于 2026-10-30。**1.9（14）已通过完整 Xcode 构建和开发签名，并安装至 `~/Applications/IELTS Vocabulary Lab.app`。** macOS PlugInKit 已识别安装位置的扩展，用户已将词卡加入桌面。旧的自由拖动卡片入口保留，当前已隐藏，避免同时显示两份。

## 能获得的系统体验

使用 WidgetKit Extension 后，词卡由 macOS 管理，与天气、时钟、股票小组件一样支持桌面排列、网格吸附、右键“编辑小组件”和移除。小、中、大三个尺寸已在工程中声明。

右键编辑可选择 Week 1–50、本周第 1–6 个学习日，以及是否自动轮换。所选学习日决定首次显示的 10 个词；“换一批”从本周全部词库随机抽取后续词组。每个词在一轮内只抽取一次，整周全部覆盖后再重新洗牌；新一轮的首批会避开刚学过的上一批。同一周的多个小组件实例共享队列。学习日会映射到现有词库的累计 Day：例如 Week 2 的第 1 天是 Day 8，而不是 Day 1；每周第 7 天是复习日，不新增一套词库。

小组件每批最多 10 词，提供释义展开、下一词和换一批；中、大尺寸还提供上一词和网页默写链接。点击背景或默写链接会启动原应用并打开对应 Week/Day/word。大尺寸展开时额外展示一个常用搭配。词库直接随扩展打包，离线可用。

三个尺寸均提供英音 UK、美音 US 按钮，朗读点击时显示的单词，不切词、不改变释义开关。朗读通过 `AudioPlaybackIntent` 在包含它的菜单栏应用进程执行；引擎是常驻、已静音预热的 `AVSpeechSynthesizer`。按钮无需打开网页，也无需麦克风权限。连续请求会中断上一次朗读。主应用和扩展都编译同一个 Intent，并包含各自的 App Intents 元数据。

本机网页也可通过现有本地 Python 服务使用同一引擎：页面 `/api/speech` → 同一用户的 Unix socket → 菜单栏应用。网络接口只接受本机 Host 和同源 JSON 请求；socket 权限为 0600。没有安装应用或原生引擎不可用时，网页继续使用浏览器朗读。原生桌面卡片也使用同一套引擎。

扩展只存自己的周内抽取队列、当前词和释义状态，不读取或改写网页的 SQLite 学习记录。同一周不同学习日配置的实例共享队列和释义状态。

## 与桌面卡片的区别

| 行为 | 当前桌面卡片 | 系统 WidgetKit 小组件 |
| --- | --- | --- |
| 拖动位置 | 自由拖动、应用保存位置 | 系统排列、网格吸附 |
| 修改周次和学习日 | 卡片内菜单 | 右键“编辑小组件” |
| 关闭和再次添加 | 菜单栏、卡片 × | 系统“移除小组件”、小组件图库 |
| 每批 10 词、手动换批 | 支持 | 周内随机抽取，整周覆盖后重新洗牌 |
| 自动轮换 | 无遮挡时计满 60 秒 | 提交约 15 分钟的轮换时间线，实际刷新由系统安排 |
| 遮挡时暂停计时 | 支持 | WidgetKit 不提供精确遮挡状态给扩展，不能保证 |
| 背景 | 透明窗口、磨砂材质 | 提交透明背景；最终效果受系统小组件外观设置影响 |

WidgetKit 不保持扩展进程常驻，不能靠 Timer 实现严格每分钟切词。Apple 说明常用小组件一天通常获得约 40–70 次刷新，建议时间线条目至少相隔约 5 分钟。工程按 15 分钟生成未来 6 小时的条目；这不是准点刷新保证。按钮交互后会请求刷新。

因此保留原桌面卡片入口，用户可以选择严格计时的桌面卡片或系统排列的小组件。安装系统小组件后，可从菜单栏隐藏旧卡片，避免两份词卡同时显示。

参考：[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)、[Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)。

## 当前机器的构建条件

本机已安装完整 Xcode 27.2，`xcodebuild` 与 `appintentsmetadataprocessor` 可用。用户已为两个 Target 配置同一开发团队，Keychain 中已有有效 Apple Development 证书。系统图库可用性仍以签名构建、安装后的实机验收为准。

首次签名时，macOS 可能弹出“codesign 想要访问钥匙串中的密钥”。由用户在系统窗口内输入 Mac 登录密码并点击“允许”即可；无需提供密码给其他人，也无需关闭系统安全保护。

## 在完整 Xcode 中构建

1. 安装适合本机 macOS 的完整 Xcode，完成首次启动所需组件安装。
2. 打开 `mac/IELTSVocabularyLab.xcodeproj`，选择共享 Scheme“IELTS Vocabulary Lab”。
3. 在主应用与 `IELTSVocabularyWidget` 两个 Target 的 Signing & Capabilities 中选择相同 Team，处理 Xcode 显示的证书与配置问题。Widget Target 已开启 App Sandbox。Bundle ID 不应随意改动，否则现有登录项和本机偏好会被视为另一个应用。
4. Build 并运行主应用。Xcode 会生成 App Intents 元数据、复制词库，并将签名后的 `.appex` 嵌入主应用。
5. 退出旧版本，将构建出的应用安装到 `~/Applications/IELTS Vocabulary Lab.app` 后启动。系统图库实际发现、添加和交互需在这一步验收。
6. 桌面右键 → 编辑小组件 → 搜索“IELTS 每日词卡”或“IELTS Vocabulary Lab”，选择尺寸后添加。
7. 右键词卡 → 编辑小组件，设置 Week、学习日和自动轮换。系统管理添加/移除，主应用菜单不伪造图库注册成功。

命令行入口不会更改全局 `xcode-select`，不会替换正在运行的应用：

```sh
./mac/build-widget-app.sh --check
./mac/build-widget-app.sh
```

构建默认使用两个 Target 在 Xcode 中保存的 Team。如需临时覆盖，可使用 `DEVELOPMENT_TEAM=你的TeamID ./mac/build-widget-app.sh`。如 Xcode 不在默认位置，可设置 `DEVELOPER_DIR=/实际路径/Xcode.app/Contents/Developer`。`--unsigned` 仅用于完整 Xcode 下的构建检查，不代表可安装或可被图库运行。

成功构建后，退出正在运行的旧应用并安装系统小组件版：

```sh
./mac/install-app.sh --widget
```

安装器先复制和校验新应用，再替换 `~/Applications/IELTS Vocabulary Lab.app`；旧版本只在替换过程中临时保留用于失败回滚，安装成功后会自动清理，不留下旧版副本。`--no-open` 可用于只安装、不立即启动。

原 `./mac/build-app.sh` 继续构建现有桌面卡片版。它不会自动将 Xcode 工程产物安装进当前应用。

只有 Command Line Tools 时，可运行 `./mac/check-widget-source.sh` 检查词库行为、扩展 API 约束和两种 CPU 架构的 Swift 源码。这项检查不能替代 Xcode 构建或系统图库实测。

## 需要完成的实机验收

- [x] Xcode 27.2 构建与开发签名成功；主应用与扩展签名严格校验通过，包内含扩展与 App Intents 元数据。
- [x] 安装版本为 1.9（14），PlugInKit 已识别 `~/Applications` 中的扩展；网页服务、词库与 SQLite WASM 资源可正常访问。
- [x] 真实 300 个学习日、6000 个词的周内无重复抽取、跨轮不与上一批重叠、上下词、释义状态保持、轮换和持久化逻辑检查通过；网页与扩展打包词库一致。
- 系统图库能找到词卡，桌面可添加并吸附、调整三个尺寸、右键编辑和移除。
- Week 1–50 的本周第 1–6 天映射正确，每批 10 词，按钮操作不唤起主应用。
- 第 10 个词后在当前批循环，换批跳到下一批首词，展开释义和重新收起正确。
- 词条跳转、扩展重启后的展示状态、自动轮换在系统调度下可用。
- 显示效果、长单词缩放及当前 macOS 的透明/着色样式可读。
