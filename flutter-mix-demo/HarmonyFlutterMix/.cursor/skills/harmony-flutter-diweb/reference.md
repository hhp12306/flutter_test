# DIWeb 优化方案 — 完整参考文档

> 来源：`HarmonyFlutterMix` Demo 项目  
> 用途：供 AI 或工程师对照公司 HarmonyOS + Flutter 混合项目做架构/性能比对  
> 平台：HarmonyOS ArkTS + `@ohos/flutter_ohos`

---

## 1. 业务场景

### 1.1 产品形态

- **主 Tab**：发现（Flutter 社区首页）、商城、爱车、服务、我的（Demo 另有测试 Tab）
- **社区二级页**：全部为远程 H5
- **打开方式**：Flutter 列表点击 → `MethodChannel.openH5` → 原生 Overlay 展示 H5
- **关闭方式**：导航栏返回 / Bridge `close` → **直接隐藏 Overlay**，回到 Flutter，**不**走 WebView 历史后退
- **刷新**：关闭 H5 后 Flutter 列表**不需要** reload

### 1.2 性能预期（务必对齐产品）

| 能力 | 能否做到 | 说明 |
|------|----------|------|
| Overlay 弹出 | ✅ ~0ms | 纯原生显隐 |
| Bridge 注入 | ✅ ~6–11ms | community 档 |
| 预热后本地 H5 首开 | ✅ ~55ms | rawfile |
| 同 URL 重复进入 | ✅ ~5ms | 缓存秒开 |
| 不同帖子 URL 首开 | ⚠️ 300–800ms+ | 受网络/HTML 主导，预热帮不上忙 |
| 每个帖子都秒开 | ❌ | URL 不同无法普遍缓存 |

---

## 2. 架构设计

### 2.1 为什么用 Overlay 而不是 router.pushUrl

| 方案 | 问题 | Overlay 方案 |
|------|------|--------------|
| 每次 push DIWebPage | WebView 反复创建/销毁，冷启动慢 | Index 层常驻一个 Web |
| Web 内 goBack | 可能退到 about:blank 占位页 | 直接 `closeOverlay` |
| 多 WebView 实例 | 内存高、Cookie 分散 | 单例 `DIWebSession.sharedController` |

### 2.2 组件关系

```
Index.ets
├── Tabs (BarMode.Fixed)
│   ├── DiscoverTab → prewarmWeb + FlutterPage
│   ├── MallTab / CarTab / ServiceTab / MineTab
│   └── TestTab (调试用，上线可移)
└── DIWebOverlay (visibility 控制，Stack 全屏覆盖)
    └── DIWeb (useSharedController=true)
        └── Web(src='about:blank', controller=shared)
```

### 2.3 打开/关闭时序

**打开 H5：**

1. `DIWebLoadMonitor.markClick`
2. `DIWebSession.openInOverlay(params)` → `overlayApplyFn` 更新 url/title/bridge
3. `AppStorage.set('diwebOverlayVisible', true)`
4. `DIWebOverlay.onVisibleChanged` → `markOverlayVisible`
5. 若 URL 变化：`pendingNavigation=true`，遮罩 Loading
6. `DIWeb.loadTargetUrl` → `webCtrl.loadPage`
7. `onPageBegin` → `onPageEnd` → `injectBridgeScript`
8. `clearPendingNavigation` → `markOverlayContentVisible` → 用户可见

**关闭 H5：**

1. `DIWebRouter.back()` → `session.closeOverlay()`
2. `AppStorage.set('diwebOverlayVisible', false)`
3. `webCtrl.onInactive()`，Web **保留**在内存

---

## 3. 优化项详解

### 3.1 单 WebView 会话（DIWebSession）

**文件**：`diweb/DIWebSession.ets`

要点：

- `sharedController: DIWebController` 全局唯一
- `openInOverlay` / `closeOverlay` 通过 `AppStorage` key `diwebOverlayVisible` 控制显隐
- `lastOverlayUrl` / `lastOverlayTitle` 用于判断 loadMode
- `prewarmWeb(source)` 在 Tab 激活时调用，记录 `prewarmSource` / `prewarmTime`

```typescript
// DiscoverTab 激活时
DIWebSession.getInstance().prewarmWeb('社区Tab')
```

**比对检查**：

- [ ] 是否存在多个 WebviewController 实例？
- [ ] 隐藏 H5 时是否 destroy Web 组件？
- [ ] 是否有 about:blank 占位策略？

### 3.2 Overlay 路由与遮罩（DIWebOverlay）

**文件**：`diweb/DIWebOverlay.ets`

要点：

- `applyRouteParams`：比较 prevUrl / bridgeProfile
  - URL 不同 → `pendingNavigation=true`
  - 同 URL 但 title 或 bridge 变化 → `forceReloadTick++` + `pendingNavigation=true`
- `handleBack`：只调 `DIWebRouter.back()`，**不调** `web.goBack()`
- Web 在 `pendingNavigation` 时 `opacity=0`，上层 Stack Loading
- `hostVisible: visible && !pendingNavigation` 避免遮罩期间误触发缓存复用

**比对检查**：

- [ ] 返回是否误用 Web 历史栈？
- [ ] URL 切换是否有旧页闪烁？
- [ ] 同 URL 换 Bridge 是否会 stale 旧脚本？

### 3.3 Bridge 按需注入

**文件**：`diweb/DIWebBridgeScript.ets`、`diweb/DIWebTypes.ets`

| profile | API 数量 | 脚本体积 | 用途 |
|---------|----------|----------|------|
| `community` | 4 | ~1592 B | 社区 H5 生产 |
| `full` | 93 | ~10583 B | 压测/对比 |

community API 列表：

```typescript
['getAppInfo', 'close', 'setTitle', 'toast']
```

注入时机：`onPageEnd`（非 about:blank）→ `webCtrl.injectBridgeScript(profile)`

Flutter 侧默认 community：

```typescript
// DIWebChannelPlugin.ets
const bridgeProfile = profileArg === 'full' ? 'full' : 'community'
DIWebRouter.open(url, { title, source: 'Flutter社区', bridgeProfile })
```

**比对检查**：

- [ ] Bridge 是否全量注入公司 90+ API？
- [ ] 能否按页面/业务线分 profile？
- [ ] H5 SDK 是否依赖未注入的 API？

### 3.4 WebView 预热

**触发点**：

- `DiscoverTab.aboutToAppear` / `onActiveChanged` → `prewarmWeb('社区Tab')`
- `TestTab` 手动预热（调试）

**原理**：Overlay 内 Web 组件已 attach 在 `about:blank`，预热调用 `sharedController.onActive()` 唤醒引擎。

**限制**：

- 不能预热远程 HTML 内容
- `overlayHostNotReady` 时效果有限（Web 尚未 bind）
- 重复预热会打 `REPEAT` 日志，无害

**比对检查**：

- [ ] 是否在用户进社区 Tab 时提前初始化 Web？
- [ ] 预热是否等到第一次点 H5 才做？

### 3.5 稳定性：错误处理

**文件**：`diweb/DIWeb.ets` → `handleWebError` / `shouldIgnoreWebError`

**问题背景**：第三方 H5 埋点/子资源失败（如 `-100 ERR_CONNECTION_CLOSED`、`-32 ERR_BLOCKED_BY_ORB`）在主文档加载完成后仍触发 `onErrorReceive`，导致整页显示「加载失败」。

**策略**：

1. `code === -32` → 一律忽略
2. 主文档已 loaded（`loadedUrl` 非空且 `!isLoading`）→ 忽略
3. `requestUrl` 与主文档 URL 不是同一 document → 忽略（子资源）
4. 仅主文档加载阶段失败 → 显示 Stack 浮层错误 UI + 重试

**关键**：错误 UI 是 Web 上方的 Stack 浮层，**不能** `if (error) { /* 不渲染 Web */ }`，否则 Web detach 后重试崩溃。

**比对检查**：

- [ ] 子资源失败是否误杀整页？
- [ ] 错误重试是否报 WebviewController 未关联？
- [ ] HTTP 4xx 是否只在主文档加载时处理？

### 3.6 加载监控

**文件**：`diweb/DIWebLoadMonitor.ets`、`pages/mine/WebLoadMonitorPage.ets`

**记录字段**：

- `overlayVisibleMs`、`clickToBeginMs`、`pageRenderMs`、`pageLoadMs`
- `bridgeInjectMs`、`displayReadyMs`（用户可见 = 遮罩消失）
- `bridgeProfile`、`bridgeScriptBytes`、`prewarmUsed`、`loadMode`

**loadMode 判定**（`DIWebRouter.resolveLoadMode`）：

| 条件 | mode |
|------|------|
| 无 lastUrl | 首次加载 |
| url === lastUrl && title 相同 | 缓存秒开 |
| url === lastUrl && title 不同 | 同URL重载 |
| url !== lastUrl | 切换加载 |

**HiLog 示例**：

```
DIWeb/MONITOR: #1 REPORT OK | source=Flutter社区 mode=首次加载 bridge=community prewarm=true
DIWeb/MONITOR: #1 REPORT 耗时 | 可见=55ms HTML=52ms 渲染=28ms Bridge=7ms Overlay=1ms 总计=54ms
```

**已知坑**：HiLog 格式化 `%d` 可能导致数值为空，统一用 `%{public}s` + `String(n)`。

**比对检查**：

- [ ] 是否有端到端耗时埋点？
- [ ] 「可见」是否等价为 pageEnd（应包含遮罩/Bridge）？
- [ ] 能否区分网络 vs 原生耗时？

### 3.7 Tab 与 Flutter 集成

**Index.ets**：

- 五/六 Tab，`BarMode.Fixed`（勿用 Scrollable，否则只显示一个 Tab）
- 底层 `DIWebOverlay()` 常驻

**DiscoverTab.ets**：

- `FlutterEntry` + `DiscoverFlutterConfigurator`
- Tab 激活 → prewarm + Flutter onPageShow/onPageHide

**DIWebChannelPlugin**：

- Channel：`com.example.harmonyfluttermix/diweb`
- Methods：`openH5`、`openTestPage`

---

## 4. 实测数据（Demo 模拟器）

| # | 场景 | mode | 可见 | HTML | Bridge | Overlay |
|---|------|------|------|------|--------|---------|
| 1 | 本地 Demo 首开 | 首次加载 | 55ms | 52ms | 7ms | 1ms |
| 2 | 本地同 URL 再开 | 缓存秒开 | 5ms | 0 | 0 | 1ms |
| 3 | 本地换 full Bridge | 同URL重载 | 35ms | 32ms | 6ms | 1ms |
| 4 | 远程百度 | 切换加载 | 547ms | 546ms | 6ms | 1ms |

**结论**：

- 原生 + Bridge 占比 < 2%（远程场景）
- 预热 + Overlay 对本地/复用场景收益大
- 帖子业务以「切换加载」为主，性能瓶颈在 H5/CDN

---

## 5. 与公司项目比对清单

### 5.1 架构层

| # | 检查项 | Demo 做法 | 公司项目记录 |
|---|--------|-----------|--------------|
| A1 | H5 容器形态 | Index Overlay 常驻 | |
| A2 | WebView 实例数 | 1（sharedController） | |
| A3 | 返回策略 | closeOverlay，非 goBack | |
| A4 | Flutter 打开 H5 | MethodChannel → Router | |
| A5 | 占位页 | about:blank | |
| A6 | Tab 与 H5 关系 | 发现=Flutter，二级=H5 | |

### 5.2 性能层

| # | 检查项 | Demo 做法 | 公司项目记录 |
|---|--------|-----------|--------------|
| P1 | WebView 预热时机 | 进社区 Tab | |
| P2 | Bridge 分档 | community / full | |
| P3 | URL 切换遮罩 | pendingNavigation | |
| P4 | 同 URL 缓存复用 | ensureDisplayReady + markCacheReuse | |
| P5 | 同 URL 换 Bridge 重载 | forceReloadTick | |

### 5.3 稳定性层

| # | 检查项 | Demo 做法 | 公司项目记录 |
|---|--------|-----------|--------------|
| S1 | 子资源错误过滤 | shouldIgnoreWebError | |
| S2 | 错误 UI 不卸载 Web | Stack 浮层 | |
| S3 | ORB/埋点错误 | code -32 忽略 | |
| S4 | 主文档 vs 子资源 URL 区分 | isSameDocumentUrl | |

### 5.4 可观测性

| # | 检查项 | Demo 做法 | 公司项目记录 |
|---|--------|-----------|--------------|
| O1 | 分段耗时日志 | DIWebLoadMonitor STEP/REPORT | |
| O2 | loadMode 分类 | 四种 mode | |
| O3 | prewarm 标记 | prewarmUsed 字段 | |
| O4 | 调试页 | WebLoadMonitorPage / TestTab | |

---

## 6. 迁移建议（优先级）

### P0 — 上线阻塞

1. 返回逻辑：确保关 H5 不 goBack 到 blank
2. 子资源误报：避免埋点失败导致整页错误
3. 错误重试：Web 组件不可条件卸载

### P1 — 体感提升

1. Index Overlay + 单 WebView
2. 发现 Tab 预热
3. community 精简 Bridge（按 H5 实际 API 清单配置）
4. URL 切换遮罩

### P2 — 可观测 / 调试

1. 移植 DIWebLoadMonitor
2. 真机 + 真实社区域名压测
3. 测试 Tab 移入「我的-开发者选项」或移除

---

## 7. 反模式（避免）

| 反模式 | 后果 |
|--------|------|
| 每次打开 push 新 WebView 页 | 冷启动 200ms+ |
| H5 返回走 web.goBack() | 退到 about:blank |
| 全量 Bridge 注入所有页面 | 脚本大、维护难（虽注入仅 ms 级） |
| 任何 onError 都显示失败页 | 第三方埋点误杀 |
| 错误时卸载 Web 组件 | 重试崩溃 |
| Tab 用 BarMode.Scrollable 且 Tab 多 | 只显示第一个 Tab |
| 用 HiLog %d 打 long 数值 | 日志为空 |

---

## 8. 上线前检查

- [ ] 真机测试 3–5 个真实社区帖子 URL
- [ ] 弱网（4G）P95 可见耗时 < 1s
- [ ] 登录态 / Cookie 同域验证（单 WebView）
- [ ] Flutter openH5 默认 bridgeProfile=community
- [ ] 确认 H5 依赖 API 已在 community 清单内
- [ ] 移除或隐藏 TestTab /  verbose MONITOR 日志（按需）

---

## 9. 关键代码索引

| 行为 | 文件 | 函数/位置 |
|------|------|-----------|
| Overlay 常驻 | Index.ets | `DIWebOverlay()` |
| 打开 H5 | DIWebRouter.ets | `open()` |
| 关闭 H5 | DIWebRouter.ets | `back()` → `closeOverlay()` |
| 预热 | DIWebSession.ets | `prewarmWeb()` |
| 遮罩 | DIWebOverlay.ets | `pendingNavigation` |
| Bridge 注入 | DIWeb.ets | `onPageEnd` → `injectBridgeScript` |
| 错误过滤 | DIWeb.ets | `shouldIgnoreWebError()` |
| Flutter 通道 | DIWebChannelPlugin.ets | `openH5` case |
| 监控归档 | DIWebLoadMonitor.ets | `markReady` / `logReport` |

---

## 10. AI 比对任务提示词（可直接复制）

```
请阅读 DIWeb 优化参考文档，并对照当前 HarmonyOS 项目代码：

1. 列出架构差异（Overlay/多 WebView/router 栈/返回逻辑）
2. 列出缺失的优化项（预热、Bridge 分档、错误过滤、监控）
3. 标注哪些优化适用于我们的业务（社区 H5 URL 各不相同、单 WebView）
4. 给出 P0/P1/P2 迁移任务清单和预估改动文件
5. 若已有类似实现，说明 Demo 方案是否更优及原因

输出格式：差异表 + 迁移清单 + 风险项
```
