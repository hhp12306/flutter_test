# DIWeb H5 容器优化参考（HarmonyOS + Flutter）

> **用途**：将此文档复制到公司项目，或让 Cursor / 其他 AI 工具读取后，与现有 Harmony Flutter 混合方案做对照比对。  
> **Demo 来源**：`HarmonyFlutterMix`  
> **Cursor Skill**：`.cursor/skills/harmony-flutter-diweb/SKILL.md`（精简版 + 比对流程）

---

## 快速摘要

| 优化 | 做法 | 收益 |
|------|------|------|
| 单 WebView Overlay | Index 层常驻，`Visibility.Hidden` 不销毁 | 复开 ~5ms（同 URL） |
| WebView 预热 | 进社区 Tab 调 `prewarmWeb` | 省冷启动 ~几十 ms |
| Bridge 分档 | `community` 4 API / `full` 93 API | 脚本 1.6KB vs 10.5KB |
| URL 切换遮罩 | `pendingNavigation` + Loading | 无旧页闪烁 |
| 错误过滤 | 子资源/ORB 不误报整页失败 | 稳定性 |
| 加载监控 | STEP + REPORT 分段日志 | 可量化对比 |

**远程 H5 首开 300–800ms 是正常现象**（网络/HTML 主导）；不同帖子 URL 无法普遍「缓存秒开」。

---

## 业务前提

- 发现 Tab = Flutter 社区首页
- 二级页 = 远程 H5（Flutter MethodChannel 传 URL）
- 返回 = **直接关 Overlay**，不走 Web 后退
- 全 App **共用一个 WebView**
- 关 H5 后 Flutter **不刷新**

若公司项目前提不同，请跳过不适用项。

---

## 架构图

```
Flutter (发现页)
    │ MethodChannel: openH5 { url, title, bridgeProfile? }
    ▼
DIWebChannelPlugin
    ▼
DIWebRouter.open(useOverlay=true)
    ▼
DIWebSession.openInOverlay → AppStorage[diwebOverlayVisible=true]
    ▼
DIWebOverlay (Index 常驻)
    └── DIWeb (shared WebviewController, src=about:blank)
            ├── loadUrl → onPageEnd → injectBridge(community|full)
            └── 返回 → DIWebRouter.back() → closeOverlay (非 goBack)
```

---

## 核心文件

| 路径 | 职责 |
|------|------|
| `entry/src/main/ets/pages/Index.ets` | Tab 框架 + `DIWebOverlay()` 常驻 |
| `entry/src/main/ets/diweb/DIWebOverlay.ets` | Overlay UI、遮罩、返回 |
| `entry/src/main/ets/diweb/DIWebSession.ets` | 单例 Controller、预热、open/close |
| `entry/src/main/ets/diweb/DIWebRouter.ets` | 统一 open/back、loadMode |
| `entry/src/main/ets/diweb/DIWeb.ets` | Web 组件、错误过滤、Bridge 注入 |
| `entry/src/main/ets/diweb/DIWebBridgeScript.ets` | community/full 脚本生成 |
| `entry/src/main/ets/plugins/DIWebChannelPlugin.ets` | Flutter 通道 |
| `entry/src/main/ets/pages/tabs/DiscoverTab.ets` | 预热触发点 |
| `entry/src/main/ets/diweb/DIWebLoadMonitor.ets` | 耗时监控 |

---

## 七大优化详解

### 1. Index 常驻 Overlay + 单 WebView

- Web 初始 `about:blank`，避免占位页进历史栈
- 隐藏用 `Visibility.Hidden`，不 `destroy` Web
- `DIWebSession.getSharedController()` 全局复用

### 2. 预热

```typescript
// DiscoverTab 激活时
DIWebSession.getInstance().prewarmWeb('社区Tab')
```

仅唤醒引擎；**不能**预加载远程 HTML。

### 3. Bridge 分档

| profile | APIs | 体积 |
|---------|------|------|
| community | getAppInfo, close, setTitle, toast | ~1.6KB |
| full | 93 个（压测） | ~10.5KB |

Flutter 默认 `bridgeProfile: 'community'`。同 URL 切换档位会 `forceReloadTick++` 重载。

### 4. URL 切换遮罩

换 URL 时 Web `opacity=0` + 全屏 Loading，`onPageEnd` 后消失，避免旧内容闪现。

### 5. 子资源错误不误报

忽略：`-32 ORB`、主文档已 loaded 后的错误、非主文档 URL 的失败。  
错误 UI 必须是 **Stack 浮层**，不能卸载 Web（否则重试崩溃）。

### 6. 加载监控

HiLog 搜 `DIWeb/MONITOR` + `#N REPORT`。  
「可见耗时」= 遮罩消失时刻，含 Overlay + HTML + Bridge。

### 7. Flutter 对接

```dart
const channel = MethodChannel('com.example.harmonyfluttermix/diweb');
await channel.invokeMethod('openH5', {
  'url': 'https://...',
  'title': '帖子标题',
  'bridgeProfile': 'community', // 可选
});
```

---

## 实测数据（Demo 模拟器）

| 场景 | 可见耗时 | 说明 |
|------|----------|------|
| 本地首开（预热后） | ~55ms | 首次加载 |
| 同 URL 再开 | ~5ms | 缓存秒开 |
| 同 URL 换 Bridge | ~35ms | 同URL重载 |
| 远程百度 | ~547ms | HTML ~546ms，原生 ~8ms |

---

## 与公司项目比对清单

复制给 AI 时，可要求逐项填写「Demo / 公司 / 差异 / 建议」：

**架构**

- [ ] H5 用 Overlay 还是 push 新页？
- [ ] WebView 实例数量？
- [ ] 返回是否 goBack？
- [ ] 是否有 about:blank 策略？

**性能**

- [ ] 是否有 Tab 级预热？
- [ ] Bridge 是否全量注入？
- [ ] URL 切换是否有遮罩？
- [ ] 同 URL 是否复用？

**稳定性**

- [ ] 子资源失败是否误杀整页？
- [ ] 错误重试是否 detach Web？

**可观测**

- [ ] 是否有分段耗时埋点？
- [ ] 能否区分 HTML vs 原生耗时？

---

## 迁移优先级

| 级别 | 内容 |
|------|------|
| **P0** | 返回逻辑、子资源误报、错误 UI 不卸载 Web |
| **P1** | Overlay 单 WebView、Tab 预热、Bridge 分档、切换遮罩 |
| **P2** | 加载监控、真机社区域名验证、测试 Tab 收敛 |

---

## AI 比对提示词

```
阅读 docs/DIWEB-OPTIMIZATION-REFERENCE.md（或 .cursor/skills/harmony-flutter-diweb/），
对照本仓库 HarmonyOS + Flutter 代码：

1. 架构差异表（Overlay/WebView 数量/返回/Channel）
2. 缺失优化项及是否适用于我们业务
3. P0/P1/P2 迁移清单 + 涉及文件
4. 风险与上线检查项

业务前提：社区二级页为远程 H5、URL 各不相同、单 WebView、返回直接关 Overlay。
```

---

## 完整文档

更详细的代码索引、反模式、上线检查见：

`.cursor/skills/harmony-flutter-diweb/reference.md`
