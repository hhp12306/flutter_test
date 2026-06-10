# 鸿蒙 + Flutter 混合开发调试操作指南

> 适用工程：`flutter-mix-demo`  
> 工具：DevEco Studio（鸿蒙壳）+ Android Studio / VS Code（Flutter 调试）

---

## 一、工程结构

```
flutter-mix-demo/
├── my_flutter_module/      # Flutter Module（Android Studio 打开这个）
├── HarmonyFlutterMix/      # 鸿蒙宿主工程（DevEco Studio 打开这个）
└── README.md
```

| 目录 | 用什么 IDE 打开 | 作用 |
|------|----------------|------|
| `HarmonyFlutterMix` | DevEco Studio | 编译、安装、Debug 运行鸿蒙 App |
| `my_flutter_module` | Android Studio / VS Code | 编写 Dart 代码、`flutter attach` 热重载 |

---

## 二、环境要求

- Flutter SDK：3.22+（含 OpenHarmony 支持，如 `flutter_ohos`）
- DevEco Studio：5.0+
- `flutter doctor` 能识别鸿蒙设备
- 两台 IDE 可同时打开，各司其职

首次集成或改了原生插件时，需构建 HAR：

```bash
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
cd my_flutter_module
flutter build har --debug
```

日常只改 Dart 代码时，**不必每次**都 build har。

---

## 三、核心原则（最重要）

`flutter attach` 依赖设备日志里这一条（**只在 App 启动时打印一次**）：

```
The Dart VM service is listening on http://127.0.0.1:xxxxx/...
```

因此：

| 顺序 | 结果 |
|------|------|
| ❌ 先 DevEco 跑 App → 再 attach | 一直 `Waiting...`，连不上 |
| ✅ 先 attach 等着 → 再 DevEco Debug 跑 App | 能连上 |
| ✅ attach 等着 → 杀掉 App → 再 DevEco Debug 重跑 | 能连上 |

**记住：attach 必须早于 App 启动，或 App 在 attach 等待期间重启。**

---

## 四、完整操作流程（Android Studio 版）

### 第 1 步：DevEco 配置签名（仅首次）

1. 用 DevEco Studio 打开 `HarmonyFlutterMix`
2. **File → Project Structure → Signing Configs** 配置签名
3. 连接鸿蒙真机或模拟器

### 第 2 步：Android Studio 打开 Flutter 工程

打开目录：

```
/Users/huhuiping/Downloads/flutter-mix-demo/my_flutter_module
```

### 第 3 步：先执行 attach（保持运行）

Android Studio 底部 **Terminal**：

```bash
cd /Users/huhuiping/Downloads/flutter-mix-demo/my_flutter_module
flutter attach -d <你的设备ID>
```

查看设备 ID：

```bash
flutter devices
```

示例：

```bash
flutter attach -d MJE0224926019108
```

看到以下提示后**不要关闭终端**：

```
Waiting for a connection from Flutter on MJE0224926019108...
```

### 第 4 步：DevEco Debug 启动 App

1. 切到 DevEco Studio
2. 确认工具栏是 **Debug**（虫子图标），不是 Run
3. 点击 **Debug** 运行到手机
4. 等待 Flutter 页面显示（标题「Flutter 混合页面」）

### 第 5 步：确认 attach 已连接

Android Studio 终端应从 `Waiting...` 变为：

```
r  Hot reload. 🔥🔥🔥
R  Hot restart.
h  List all available interactive commands.
d  Detach (terminate "flutter run" but leave application running).
q  Quit (terminate the application on the device).

A Dart VM Service on <设备> is available at: http://127.0.0.1:xxxxx/...
```

出现以上内容即表示调试连接成功。

---

## 五、App 已在运行时怎么办？

不需要先杀 App，按这个顺序：

1. 先执行 `flutter attach`，看到 `Waiting...`
2. 再杀掉手机上已运行的 App（或 DevEco 重新 Debug 运行）
3. App 重启后 attach 自动连上

---

## 六、热重载测试

1. 在 Android Studio 中打开 `lib/main.dart`
2. 修改文字，例如把「这是来自 Flutter 的内容！」改为「热重载成功！」
3. **保存文件**（Cmd+S）
4. 在 attach 终端按 **`r`**

预期：手机上文字立即更新，计数器数字不变（说明是热重载而非重启）。

### 常用快捷键

| 按键 | 作用 |
|------|------|
| `r` | 热重载（改 UI 最常用） |
| `R` | 热重启（改了 `main()`、`initState()` 等时用） |
| `d` | 断开 attach，App 继续运行 |
| `q` | 退出 attach 并终止 App |

也可点击 Android Studio 工具栏的 **Hot Reload**（闪电图标）。

---

## 七、VS Code 方式（可选）

1. 用 VS Code 打开 `my_flutter_module`
2. 运行 **HarmonyOS Attach**（`.vscode/launch.json` 已配置）
3. 看到等待连接后，去 DevEco Debug 运行 App

---

## 八、常见问题

### 1. 一直 `Waiting for a connection...`

- 确认 attach **先于** App 启动，或 App 在 attach 等待期间重启
- 确认 DevEco 是 **Debug** 模式，不是 Release
- 用详细模式排查：`flutter attach -v -d <设备ID>`

### 2. 改了代码界面没变化

- 保存后按 `r` 热重载
- 不行再按 `R` 热重启
- 确认 attach 终端已显示 `r Hot reload`

### 3. `flutter build har` 报错 DEVECO_SDK_HOME

```bash
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
```

### 4. 为什么需要 `flutter build har`？

鸿蒙依赖 HAR 包格式集成 Flutter 引擎和模块。`flutter build har` 是首次集成 / 发版时需要；日常改 Dart 用 attach + 热重载即可，不必每次 build。

### 5. 查看设备是否有 VM Service 日志

```bash
export PATH="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains:$PATH"
hdc shell hilog -e flutter | grep -i "Dart VM service"
```

App 启动时应能看到 `The Dart VM service is listening on...`。

---

## 九、日常开发速查

```
┌─────────────────────────────────────────────────────────┐
│  1. Android Studio Terminal: flutter attach（等着）      │
│  2. DevEco Studio: Debug 运行 HarmonyFlutterMix         │
│  3. 终端出现 r Hot reload → 改 main.dart → 保存 → 按 r   │
└─────────────────────────────────────────────────────────┘
```

---

## 十、双 IDE 分工总结

| 任务 | 使用工具 |
|------|----------|
| 跑鸿蒙 App、调 ArkTS 原生代码 | DevEco Studio |
| 写 Dart、热重载、断点调试 | Android Studio / VS Code |
| 首次集成 / 插件变更 / 发版 | 终端 `flutter build har` |
