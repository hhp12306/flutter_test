---
name: harmony-flutter-diweb
description: >-
  HarmonyOS + Flutter 混合 App 中 DIWeb H5 容器优化方案（单 WebView Overlay、预热、Bridge 按需注入、加载监控、稳定性修复）。
  用于对照公司项目做架构比对、迁移评估、性能排查，或用户提到 Harmony Flutter H5、WebView 预热、JSBridge、Overlay 秒开时。
---

# Harmony Flutter DIWeb 优化方案

## 何时使用

用户要把 Demo 方案迁移到公司项目，或让 AI **读取后对照现有实现**时：

1. 先读 [reference.md](reference.md) 全文
2. 按「比对清单」逐项检查公司代码
3. 输出差异表：已有 / 缺失 / 需改造 / 不适用

## 业务前提（比对前先确认）

| 约定 | Demo 假设 |
|------|-----------|
| 发现 Tab | 嵌入 Flutter 社区首页 |
| 二级页 | 远程 H5，Flutter 经 MethodChannel 传 URL |
| 返回 | **直接关 Overlay 回 Flutter**，不走 Web 内后退 |
| URL | 帖子/详情 URL **各不相同** |
| WebView | **全 App 共用一个**（Index 层常驻） |
| 关 H5 后 | Flutter **不需要刷新** |

若公司项目前提不同，部分优化（如缓存秒开、单 WebView）可能不适用。

## 核心架构（5 层）

```
Flutter openH5
  → DIWebChannelPlugin (MethodChannel)
  → DIWebRouter.open (默认 useOverlay=true)
  → DIWebSession.openInOverlay (AppStorage 显隐)
  → DIWebOverlay (常驻，Visibility.Hidden 不销毁)
  → DIWeb + DIWebController (共享 WebviewController)
```

**关键文件**（相对 `entry/src/main/ets/`）：

| 模块 | 文件 |
|------|------|
| 入口 | `pages/Index.ets`（`DIWebOverlay()` 常驻 + `BarMode.Fixed`） |
| Overlay | `diweb/DIWebOverlay.ets` |
| 会话 | `diweb/DIWebSession.ets` |
| 路由 | `diweb/DIWebRouter.ets` |
| Web 组件 | `diweb/DIWeb.ets` |
| Bridge | `diweb/DIWebBridgeScript.ets` |
| Flutter 通道 | `plugins/DIWebChannelPlugin.ets` |
| 预热触发 | `pages/tabs/DiscoverTab.ets` |
| 监控 | `diweb/DIWebLoadMonitor.ets` |

## 七大优化点（比对重点）

### 1. Index 层常驻 Overlay 单 WebView

- `DIWebOverlay` 用 `Visibility.Hidden` 隐藏，**不销毁** Web 组件
- `DIWebSession.sharedController` 全局复用 `WebviewController`
- Web 初始 `src='about:blank'`，避免 demo 页进历史栈
- 返回：`DIWebRouter.back()` → `closeOverlay()`，**不调用** `web.goBack()`

### 2. WebView 预热

- 进入发现 Tab 时 `DIWebSession.prewarmWeb('社区Tab')`
- 仅 `onActive()` 唤醒引擎；Overlay 内 Web 已 attach 在 `about:blank`
- 效果：省 WebView 冷启动（约几十～百 ms），**不能**缩短远程 HTML 网络时间

### 3. Bridge 按需注入（community / full）

- `community`：4 API（getAppInfo/close/setTitle/toast），约 1.6KB
- `full`：93 API 压测档，约 10.5KB
- Flutter `openH5` 默认 `bridgeProfile: 'community'`
- 同 URL 切换 Bridge 档位：`forceReloadTick++` 强制重载

### 4. URL 切换遮罩（pendingNavigation）

- 换 URL 时 `pendingNavigation=true`，Web `opacity=0` + 全屏 Loading
- `onPageEnd` 后 `clearPendingNavigation` → `markOverlayContentVisible`
- 避免旧页闪烁

### 5. 子资源错误不误报整页失败

`DIWeb.handleWebError` 忽略：

- `code === -32`（ERR_BLOCKED_BY_ORB）
- 主文档已加载完成（`!isLoading && loadedUrl` 非空）
- 失败 URL 与主文档 URL 不一致（埋点/子资源）

**错误 UI 必须是 Stack 浮层**，不能条件卸载 Web 组件（否则重试报 `WebviewController must be associated with a Web component`）。

### 6. 加载监控（可移植）

- `DIWebLoadMonitor`：CLICK → overlayVisible → pageBegin → pageEnd → bridgeInject → contentVisible
- 四种 `loadMode`：首次加载 / 切换加载 / 同URL重载 / 缓存秒开
- HiLog tag `DIWeb/MONITOR`，搜 `#N REPORT` 看汇总
- **注意**：HiLog 数值用 `%{public}s` + `String()`，不要用 `%d`

### 7. Flutter MethodChannel 对接

```dart
// channel: com.example.harmonyfluttermix/diweb
await channel.invokeMethod('openH5', {
  'url': url,
  'title': title,
  'bridgeProfile': 'community', // 可选，默认 community
});
```

## 比对输出模板

对照公司项目后，按此格式回复：

```markdown
## 架构比对
| 项 | Demo | 公司项目 | 建议 |
|----|------|----------|------|

## 性能预期
| 场景 | Demo 实测 | 公司现状 | 差距原因 |

## 迁移优先级
1. P0（稳定性/阻塞上线）
2. P1（性能体感）
3. P2（可观测性）

## 不适用项
（业务前提不同导致的）
```

## 实测基准（Demo 模拟器，预热=true）

| 场景 | loadMode | 可见耗时 |
|------|----------|----------|
| 本地 Demo 首开 | 首次加载 | ~55ms |
| 同 URL 再开 | 缓存秒开 | ~5ms |
| 同 URL 换 Bridge | 同URL重载 | ~35ms |
| 远程百度 | 切换加载 | ~547ms（HTML ~546ms，原生 ~8ms） |

**上线判断**：原生链路 ms 级可接受；远程帖子首开 300–800ms 正常；不能指望每个不同 URL 都 5ms 秒开。

## 详细文档

完整设计、代码片段、反模式、上线检查项见 [reference.md](reference.md)。
