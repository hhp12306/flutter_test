# HarmonyFlutterMix — Flutter跳转H5性能优化完整方案

> **文档版本**: v2.0  
> **最后更新**: 2026-06-15  
> **适用项目**: HarmonyFlutterMix（HarmonyOS + Flutter 混合 Demo）  
> **对照项目**: dilink-harmony-auto（比亚迪鸿蒙 App）  
> **Cursor Skill**: `.cursor/skills/harmony-flutter-diweb/SKILL.md`

---

## 一、项目架构全景分析

### 1.1 完整调用链路（6 层架构）

```
Flutter 点击 H5 链接
  ↓ (MethodChannel: com.example.harmonyfluttermix/diweb)
DIWebChannelPlugin.handleMethodCall('openH5')
  ↓ (params: url / title / bridgeProfile?)
DIWebRouter.open(url, { source, bridgeProfile, useOverlay: true })
  ↓ (DIWebLoadMonitor.markClick + resolveLoadMode)
DIWebSession.openInOverlay(params)
  ↓ (overlayApplyFn → AppStorage[diwebOverlayVisible=true])
DIWebOverlay.applyRouteParams
  ↓ (pendingNavigation / forceReloadTick / bridgeProfile)
DIWeb.loadTargetUrl → Web.onPageBegin/onPageEnd
  ↓ (injectBridgeScript + markOverlayContentVisible)
用户可见 H5 内容
```

**原生 Tab 入口（非 Flutter）**：

```
商城/爱车/服务 Tab 点击
  → DIWebRouter.open(url, { source, title })  // 未传 bridgeProfile 时默认 full
  → 同上 Overlay 链路
```

### 1.2 关键模块职责矩阵

| 模块 | 文件路径 | 核心职责 | 性能影响点 |
|------|---------|---------|-----------|
| **Index** | `pages/Index.ets` | Tab 框架、Overlay zIndex、物理返回 | ⭐⭐⭐⭐⭐ 架构基础 |
| **DIWebChannelPlugin** | `plugins/DIWebChannelPlugin.ets` | Flutter 通道，默认 community | ⭐⭐ 入口 |
| **DIWebRouter** | `diweb/DIWebRouter.ets` | open/back、loadMode、fallback pushUrl | ⭐⭐ 路由极轻 |
| **DIWebSession** | `diweb/DIWebSession.ets` | 单例 Controller、预热、Overlay 显隐 | ⭐⭐⭐⭐⭐ 核心 |
| **DIWebOverlay** | `diweb/DIWebOverlay.ets` | 导航栏、遮罩、返回、Bridge 档位 | ⭐⭐⭐⭐ UI+生命周期 |
| **DIWeb** | `diweb/DIWeb.ets` | Web 封装、加载、错误过滤、缓存复用 | ⭐⭐⭐⭐⭐ 加载核心 |
| **DIWebController** | `diweb/DIWebController.ets` | loadUrl、onActive/onInactive、Bridge 注入 | ⭐⭐⭐⭐ |
| **DIWebBridgeScript** | `diweb/DIWebBridgeScript.ets` | community/full 脚本生成 | ⭐⭐⭐ Bridge |
| **DIWebJsBridge** | `diweb/DIWebJsBridge.ets` | javaScriptProxy + 内置 handler | ⭐⭐⭐ |
| **DIWebLoadMonitor** | `diweb/DIWebLoadMonitor.ets` | 分段耗时、REPORT 汇总 | ⭐⭐ 可观测 |
| **DiscoverTab** | `pages/tabs/DiscoverTab.ets` | Flutter 嵌入 + 预热触发 | ⭐⭐⭐⭐ 预热时机 |

### 1.3 WebView 组件层级结构

```typescript
Index (Stack)
├── DIWebOverlay (zIndex: overlayVisible ? 1000 : 0)
│   ├── Custom NavBar (返回 → DIWebRouter.back)
│   └── Stack (pendingNavigation 遮罩)
│       ├── DIWeb (opacity: pendingNavigation ? 0 : 1)
│       │   ├── Progress (顶部进度条)
│       │   └── Stack
│       │       ├── Web(src='about:blank', controller=shared)
│       │       │   └── javaScriptProxy: DIWebBridge { call, callAsync }
│       │       ├── Loading 浮层 (isLoading)
│       │       └── Error 浮层 (errorMessage, 不卸载 Web)
│       └── Loading 遮罩 (pendingNavigation)
└── Tabs (发现/商城/爱车/服务/测试/我的)
    └── DiscoverTab → FlutterPage
```

### 1.4 与公司项目（dilink）架构对照

| 维度 | HarmonyFlutterMix (Demo) | dilink-harmony-auto (公司) |
|------|--------------------------|---------------------------|
| H5 容器 | Index `DIWebOverlay` 常驻 | `WebPageBridge` 每次 router.push |
| WebView 实例 | 1 个 `DIWebSession.sharedController` | 每页新建 `JsApiWebController` |
| 显隐方式 | AppStorage ~1ms | 路由 push 35–60ms |
| 返回 | `closeOverlay`，非 goBack | router.back + 可选 Web 内后退 |
| Bridge | JS 注入 + javaScriptProxy，分档 | JsBridgeApi 90+ + ActionJsApi 全量 |
| 预热 | `prewarmWeb` 进社区 Tab | 无（方案建议 WebViewPool） |
| 特殊路由 | 无 | CoreUtils 10+ 场景分支 |
| multi 后退 | 不支持 | `multi=true` 支持 |

---

## 二、性能瓶颈深度诊断

### 2.1 WebView 实例管理 — ✅ 已优化

**Demo 现状**：

- Index 层 `DIWebOverlay` 常驻，`Visibility.Hidden` 不销毁
- `DIWebSession.getSharedController()` 全局复用
- Web 初始 `src='about:blank'`，`loadUrl` 加载目标页
- `DiscoverTab` 激活时 `prewarmWeb('社区Tab')`

**实测**（模拟器，预热=true）：

```
本地 H5 首开（预热后）≈ 55ms
├── Overlay 显隐 ≈ 0–1ms
├── pageBegin（Web 引擎已唤醒）≈ 24ms
├── pageEnd（HTML 渲染）≈ 28ms
├── Bridge 注入 community ≈ 6–11ms
└── 遮罩消失 ≈ 1–2ms

同 URL 再开 ≈ 5ms（缓存秒开，无 reload）
```

**公司项目差距**：公司每次新建 WebView，冷启动预估 150–250ms；Demo 已通过 Overlay 消除此项。

### 2.2 Bridge 注入 — ✅ 已分档，⚠️ 部分入口未用 community

**Demo 注入策略**：

```typescript
// DIWebBridgeScript.ets
DIWEB_COMMUNITY_API_LIST = ['getAppInfo', 'close', 'setTitle', 'toast']  // ~1592B
DIWEB_ENTERPRISE_API_LIST = 93 APIs                                      // ~10583B

// DIWeb.ets onPageEnd
this.webCtrl.injectBridgeScript(this.bridgeProfile)  // runJavaScript 注入
```

**同时存在 javaScriptProxy**（`DIWeb.ets` line 152-157）：

```typescript
.javaScriptProxy({
  object: this.webCtrl.bridgeProxyObject,
  name: 'DIWebBridge',
  methodList: ['call', 'callAsync'],
  controller: this.webCtrl.webController
})
```

注入脚本负责创建 `window.DIWeb` + `window.EnterpriseBridge` 包装；实际调用走原生 Proxy。

**问题（Demo 内部）**：

| 入口 | bridgeProfile | 问题 |
|------|---------------|------|
| Flutter `openH5` | 默认 `community` | ✅ 正确 |
| `DIWebRouter.open` 默认值 | `'full'` | ⚠️ 未显式传参时走全量 |
| 商城 `MallTab` | 未传 | ⚠️ 走 full |
| 爱车 `CarTab` | 未传 | ⚠️ 走 full |
| 服务 `ServiceTab` | 未传 | ⚠️ 走 full |
| 测试 `TestTab` | 手动指定 | ✅ 对比测试用 |

**性能影响**：full 档注入仍仅 ~30ms 量级（Demo 压测），但脚本大 6 倍，维护成本高。

### 2.3 URL 加载流程 — ✅ 遮罩已实施

```typescript
// DIWebOverlay.applyRouteParams
if (!sameUrl) {
  this.pendingNavigation = true  // Web opacity=0 + 全屏 Loading
}

// DIWebOverlay.onPageEnd → clearPendingNavigation
DIWebLoadMonitor.markOverlayContentVisible()  // 用户可见时刻
```

**远程 H5 瓶颈**（不可通过原生消除）：

```
百度远程测试 #4：可见 547ms
├── HTML 网络+解析：546ms (99%)
└── 原生+Bridge：8ms (1%)
```

帖子 URL 各不相同 → 多数为「切换加载」，无法普遍「缓存秒开」。

### 2.4 路由开销 — ✅ 已最小化

```typescript
// DIWebSession.openInOverlay
AppStorage.set(DIWEB_OVERLAY_VISIBLE_KEY, true)  // ~0–1ms
this.overlayApplyFn(params)                       // 同步更新 State
```

**fallback**（仅 Overlay 未就绪或 `useOverlay=false`）：

```typescript
router.pushUrl({ url: 'pages/DIWebPage', params })  // 调试/兜底
```

公司项目每次走 `DiNavigation.build(WEB_BRIDGE).navigation()`，开销 35–60ms；Demo 已规避。

### 2.5 错误处理 — ✅ 已修复

```typescript
// DIWeb.ets shouldIgnoreWebError
- code === -32 (ERR_BLOCKED_BY_ORB) → 忽略
- 主文档已 loaded → 忽略子资源错误
- requestUrl 非主文档 → 忽略

// 错误 UI：Stack 浮层，Web 组件始终挂载
```

---

## 三、关键代码深度剖析

### 3.1 Flutter 通道入口

```typescript
// DIWebChannelPlugin.ets
case 'openH5': {
  const bridgeProfile = profileArg === 'full' ? 'full' : 'community'
  DIWebRouter.open(url, {
    title: title ?? '',
    source: 'Flutter社区',
    bridgeProfile: bridgeProfile
  })
}
```

### 3.2 路由与 loadMode 判定

```typescript
// DIWebRouter.ets resolveLoadMode
无 lastUrl        → '首次加载'
url === lastUrl && title 相同 → '缓存秒开'
url === lastUrl && title 不同 → '同URL重载'
url !== lastUrl   → '切换加载'
```

### 3.3 Overlay 路由参数应用

```typescript
// DIWebOverlay.ets applyRouteParams
sameUrl && bridgeChanged → forceReloadTick++ + pendingNavigation
!sameUrl                  → pendingNavigation=true
sameUrl && visible        → onOverlayShow()（可能 markCacheReuse）
```

### 3.4 缓存秒开逻辑

```typescript
// DIWeb.ets ensureDisplayReady
if (this.loadedUrl.length > 0 && this.errorMessage.length === 0) {
  if (trigger.startsWith('loadSkip:') || trigger.startsWith('hostVisible')) {
    DIWebLoadMonitor.markCacheReuse()
  }
}
```

### 3.5 加载监控时序

```
markClick
  → markOverlayVisible (onVisibleChanged)
  → markPageBegin (skip about:blank)
  → markPageEnd
  → markReady (bridgeInject 完成)
  → markOverlayContentVisible (遮罩消失，写入 displayReadyTime)
```

**注意**：`displayReadyMs` = 用户真正可见，不是 pageEnd。

---

## 四、Demo 项目继续优化方案（分阶段）

> 本节针对 **HarmonyFlutterMix 自身**，在公司文档对照基础上补齐剩余收益。

### 阶段一：P1 立即可做（风险低）

#### 4.1 统一默认 Bridge 为 community

**修改** `diweb/DIWebRouter.ets`：

```typescript
// 改前
const bridgeProfile: DIWebBridgeProfile = options?.bridgeProfile ?? 'full'

// 改后
const bridgeProfile: DIWebBridgeProfile = options?.bridgeProfile ?? 'community'
```

**修改** `diweb/DIWebOverlay.ets`：

```typescript
@State bridgeProfile: string = 'community'  // 改前 'full'
```

**修改各 Tab 显式传档**：

```typescript
// MallTab.ets
DIWebRouter.open(url, { title, source: '商城', bridgeProfile: 'community' })

// CarTab / ServiceTab 同理
```

**预期收益**：商城/爱车/服务入口 Bridge 脚本 10.5KB → 1.6KB；注入时间略降，一致性提升。

#### 4.2 提前预热时机

**现状**：仅 `DiscoverTab` 激活时 `prewarmWeb`。

**问题**：用户首次从商城 Tab 打开 H5，若未进过发现 Tab，预热未生效。

**建议**：

```typescript
// Index.ets aboutToAppear
aboutToAppear(): void {
  DIWebSession.initOverlayStorage()
  // Overlay 组件 aboutToAppear 会 bindOverlayHost，延迟一帧后预热更稳
  setTimeout(() => {
    DIWebSession.getInstance().prewarmWeb('Index启动')
  }, 0)
}
```

或保留 DiscoverTab 预热 + Index 作为兜底双保险。

**预期收益**：非发现 Tab 首次开 H5 节省 WebView 冷启动 ~30–80ms。

#### 4.3 减少双层 Loading

**现状**：`DIWebOverlay.pendingNavigation` Loading + `DIWeb.isLoading` Loading 可能叠加。

**建议**：Overlay 层 `pendingNavigation` 时，`DIWeb.showProgress=false` 且跳过内部 Loading（已通过 `showProgress && !pendingNavigation` 部分处理，可进一步在 `isLoading` 浮层加 `!pendingNavigation` 条件）。

**预期收益**：UI 更干净，非性能数值。

### 阶段二：P2 中等改动

#### 4.4 扩展 Bridge 档位（对齐公司方案）

**新建** `diweb/DIWebBridgeProfiles.ets`（或扩展 `DIWebTypes.ets`）：

```typescript
export type DIWebBridgeProfile = 'community' | 'mall' | 'service' | 'full'

export const DIWEB_MALL_API_LIST = [
  'getAppInfo', 'close', 'setTitle', 'toast',
  'showLoading', 'hideLoading', 'scanCode'  // 按商城 H5 实际清单
]
```

各 Tab 传对应 profile，便于与公司 `BridgeProfile` 概念一一映射。

#### 4.5 community 极简注入（可选）

community 档已用 javaScriptProxy，可考虑注入脚本仅写：

```javascript
window.DIWeb = { call: ..., _injected: true, _profile: 'community' };
window.EnterpriseBridge = { getAppInfo: ..., close: ..., ... };  // 4 个
```

去掉 `getApiList`、事件系统等非必要代码，再压缩 ~200–500B。

**预期收益**：1–3ms，边际收益小。

#### 4.6 已知社区域名 DNS 预热（若 URL 域固定）

若社区 H5 统一域名（如 `community.example.com`），可在 `prewarmWeb` 后对已知域名做一次 HEAD/预连接（需 ArkWeb API 支持或应用层 HTTP 预热）。

**预期收益**：远程 HTML 可能减少 20–50ms（视网络），需真机验证。

### 阶段三：P3 需 H5/产品配合

| 优化 | 负责方 | 说明 |
|------|--------|------|
| H5 骨架屏 | H5 团队 | 网络 500ms 时原生无法加速首屏感知 |
| CDN/SSR | 后端 | 减小 HTML TTFB |
| 帖子 URL 预加载 | 产品+Flutter | 列表可见时 prefetch 下一页（慎用流量） |
| 移除 TestTab | 工程 | 上线前收敛调试入口 |

---

## 五、公司项目迁移指南（Demo → dilink）

### 5.1 可直接移植

| Demo 模块 | 移植到公司 | 改造量 |
|-----------|-----------|--------|
| `DIWebLoadMonitor` | 任意 Web 容器 | 低，改 log tag |
| `shouldIgnoreWebError` 逻辑 | `WebContainer` / `DiWeb` | 低 |
| `pendingNavigation` 遮罩 | `WebContainer.ets` | 低 |
| Bridge 分档概念 | 新建 `BridgeProfile.ets` | 中，对接 JsBridgeApi |
| Overlay 方案 | 仅 `multi=false` 场景 | 高 |

### 5.2 公司优先实施（不等 Overlay）

参考公司 skill 文档 P1：

1. **WebViewPool** — 最接近 Demo 收益且不改路由架构
2. **Bridge 分档** — community 档对齐 Demo 4 API
3. **URL 遮罩** — 移植 Demo `pendingNavigation`
4. **DIWebLoadMonitor** — 用同一套 REPORT 格式对比优化前后

### 5.3 性能对比预期（公司侧）

| 指标 | 公司当前预估 | +P1 优化后 | Demo 已实现 |
|------|-------------|-----------|------------|
| WebView 冷启动 | 150–250ms | 30–50ms (Pool) | ~55ms (Overlay) |
| Bridge 注入 | 30–60ms | 6–15ms | 6–11ms |
| 路由开销 | 35–60ms | 不变 | ~1ms |
| 原生总开销 | 215–370ms | 71–125ms | 8–60ms |

---

## 六、实测数据与监控

### 6.1 Demo 四组基准

| # | 场景 | loadMode | 可见 | HTML | Bridge |
|---|------|----------|------|------|--------|
| 1 | 本地 Demo 首开 | 首次加载 | 55ms | 52ms | 7ms |
| 2 | 本地同 URL 再开 | 缓存秒开 | 5ms | 0 | 0 |
| 3 | 本地换 full Bridge | 同URL重载 | 35ms | 32ms | 6ms |
| 4 | 远程百度 | 切换加载 | 547ms | 546ms | 6ms |

### 6.2 HiLog 过滤

```
tag: DIWeb/MONITOR
关键词: #1 REPORT | STEP | SUMMARY
```

### 6.3 监控页

`pages/mine/WebLoadMonitorPage.ets` — 我的 Tab 入口查看历史 RECORD。

---

## 七、全真模拟文件清单（Demo 复制到公司对照用）

**P0 必读**：

```
entry/src/main/ets/pages/Index.ets
entry/src/main/ets/diweb/DIWebOverlay.ets
entry/src/main/ets/diweb/DIWebSession.ets
entry/src/main/ets/diweb/DIWebRouter.ets
entry/src/main/ets/diweb/DIWeb.ets
entry/src/main/ets/diweb/DIWebController.ets
entry/src/main/ets/plugins/DIWebChannelPlugin.ets
```

**P1 优化参考**：

```
entry/src/main/ets/diweb/DIWebBridgeScript.ets
entry/src/main/ets/diweb/DIWebLoadMonitor.ets
entry/src/main/ets/pages/tabs/DiscoverTab.ets
entry/src/main/ets/diweb/DIWebTypes.ets
```

---

## 八、FAQ

### Q1: Demo 为什么不建议公司全量改 Overlay？

公司支持 `multi=true` Web 内后退；Demo 直接 `closeOverlay`，无法退 Web history。建议 **multi=false 场景** 试点 Overlay，其余保持路由 + WebViewPool。

### Q2: Demo 预热和 WebViewPool 哪个好？

- Demo：**单实例常驻** + `onActive()`，最简单，内存 1 份 WebView
- 公司：**WebViewPool** 更适合现有「每页新建」架构，改动小于 Overlay 重构

### Q3: 为什么远程 H5 还是慢？

HTML 网络加载占 95%+；预热、Overlay、Bridge 只优化原生部分（Demo 实测 ~8ms）。

### Q4: 缓存秒开能用于帖子列表吗？

不能普遍使用。帖子 URL 各不相同，多数是「切换加载」；仅「同一 URL 重复进入」才 ~5ms。

### Q5: 商城 Tab 没传 bridgeProfile 有影响吗？

有。当前走 `full` 93 API 注入，应用 P1 改为 `community` 或新增 `mall` 档。

---

## 九、实施路线图

### Demo 自身（1 周）

| 天 | 任务 |
|----|------|
| D1 | 默认 bridgeProfile 改 community；各 Tab 显式传档 |
| D2 | Index 提前预热；验证非发现 Tab 首开耗时 |
| D3 | 双层 Loading 收敛；TestTab 移入我的 |
| D4–5 | 真机 + 真实社区域名 3–5 URL |
| D6–7 | 可选 mall/service Bridge 档 |

### 公司迁移（参考公司 skill Week 1–3）

Week 1: WebViewPool + Bridge 分档 + URL 遮罩 + Monitor  
Week 2: 真机回归 + API 清单  
Week 3: Overlay 混合方案评估

---

## 十、附录：比对 AI 提示词

```
阅读 .cursor/skills/harmony-flutter-diweb/ 下 SKILL.md 与
harmony-flutter-diweb-optimization-analysis.md，
对照本仓库（HarmonyFlutterMix 或 dilink）代码：

1. 架构差异表（Overlay vs WebPageBridge、WebView 实例、返回逻辑）
2. Demo 已实施 vs 目标项目缺失项
3. Demo 仍可优化项（P1/P2）是否值得做
4. 公司项目 P1 迁移清单 + 涉及文件
5. 远程 H5 瓶颈说明与 H5 侧建议

业务前提：社区 H5 URL 各不相同；Demo 不支持 multi 后退。
```

---

**文档版本**: v2.0  
**维护**: HarmonyFlutterMix DIWeb 模块
