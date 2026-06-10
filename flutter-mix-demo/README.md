# Flutter + HarmonyOS 混合开发调试示例

目录结构：

```
flutter-mix-demo/
├── my_flutter_module/      # Flutter Module（Dart 代码在这里改）
├── HarmonyFlutterMix/      # 鸿蒙宿主工程（用 DevEco Studio 打开）
└── README.md
```

## 一、首次运行前

### 1. 构建 Flutter HAR（首次或改了原生插件时需要）

```bash
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
cd my_flutter_module
flutter build har --debug
```

### 2. 用 DevEco Studio 打开鸿蒙工程

打开目录：`HarmonyFlutterMix`

- 配置签名（File → Project Structure → Signing Configs）
- 连接鸿蒙真机或模拟器
- 点击 **Debug** 运行（必须是 Debug，不能 Release）

启动后应看到 Flutter 页面（标题「Flutter 混合页面」、计数器按钮）。

## 二、调试 Flutter 代码（热重载）

DevEco **不能直接调试 Dart**，需要再 attach：

### 方式 A：终端

```bash
cd my_flutter_module
flutter attach
# 或指定设备：flutter attach -d <设备ID>
```

连接成功后：

- 修改 `lib/main.dart` 并保存
- 终端按 `r` → 热重载
- 按 `R` → 热重启
- 按 `q` → 退出调试

### 方式 B：VS Code

1. 用 VS Code 打开 `my_flutter_module` 文件夹
2. DevEco 已 Debug 运行 App 的前提下，运行 **HarmonyOS Attach**
3. 在 Dart 代码里下断点，保存后点 Hot Reload

## 三、验证热重载

1. App 跑起来后执行 `flutter attach`
2. 把 `main.dart` 里「这是来自 Flutter 的内容！」改成别的文字
3. 保存，终端按 `r`
4. 设备上文字应立即更新，计数器数字不变（说明是热重载而非重启）

## 四、常见问题

| 问题 | 处理 |
|------|------|
| `flutter build har` 报 DEVECO_SDK_HOME | `export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"` |
| `flutter attach` 一直等待 | 确认 DevEco 是 Debug 运行，且 Flutter 页面已显示 |
| 改了 Dart 没变化 | 先 `r` 热重载；不行再 `R` 或重装 App |
| ohpm 依赖报错 | 在 `HarmonyFlutterMix` 根目录执行 `ohpm install` |

## 五、工程说明

- `EntryAbility.ets` 继承 `FlutterAbility`，由 Flutter 引擎接管 UI
- `Index.ets` 使用 `FlutterPage` 组件渲染 Flutter 内容
- 宿主通过 `oh-package.json5` 的 `overrides` 引用 Flutter 构建产物
- `include_flutter.ts` 中 `getFlutterProjectPath()` 指向 `../my_flutter_module`
