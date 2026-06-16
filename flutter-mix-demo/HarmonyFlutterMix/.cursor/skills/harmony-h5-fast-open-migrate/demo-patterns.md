# Demo 关键代码模式（迁移对照）

> 路径均相对 `HarmonyFlutterMix/entry/src/main/ets/`

---

## §1 about:blank 单次加载（P0，必迁）

**问题**：Web 默认 src 与 loadUrl 竞态 → 只显示 blank 或重复 load 两次。

**Demo 方案**：

```typescript
// DIWeb.ets
const DIWEB_BLANK_SRC = 'about:blank'

// Web 组件
Web({ src: DIWEB_BLANK_SRC, controller: this.webCtrl.webController })

.onControllerAttached(() => {
  this.controllerReady = true
  this.scheduleInitialLoad('onControllerAttached')  // 不直接 loadUrl
})

// blank onPageEnd 后 load 一次
if (isBlankPageUrl(pageUrl)) {
  if (this.targetPageLoaded) { /* SKIP 迟到 blank */ }
  else {
    this.blankPlaceholderDone = true
    this.loadedUrl = ''
    if (this.controllerReady && this.url.length > 0) {
      this.loadTargetUrl(this.url, 'afterBlankReady')
    }
  }
}

// 真实 URL onPageEnd
if (!isBlankPageUrl(pageUrl)) {
  this.targetPageLoaded = true
  this.webCtrl.injectBridgeScript(this.bridgeProfile)
}

private scheduleInitialLoad(trigger: string): void {
  if (!this.controllerReady || this.url.length === 0 || this.targetPageLoaded) return
  if (this.blankPlaceholderDone || !this.webCtrl.isOnBlankPage()) {
    this.loadTargetUrl(this.url, trigger)
    return
  }
  // wait blank onPageEnd
}
```

**WebPageBridge 侧**：

```typescript
// DIWebPage.ets — blank 不算加载成功
onPageEnd: (pageUrl) => {
  if (isBlankPageUrl(pageUrl)) return  // placeholder
  WebFlowTracer.end('✅ 公司路由链路成功')
}
```

---

## §2 WebViewPool（P1，公司多层栈）

```typescript
// Index.ets — App 启动预热
WebViewPool.getInstance().prewarm(2)

// WebPageBridge — 打开时（公司侧需接入，Demo DIWebPage 尚未接入）
const ctrl = WebViewPool.getInstance().acquire() ?? new DIWebController()
DIWeb({ externalController: ctrl, useSharedController: false, ... })

// aboutToDisappear — 回收
WebViewPool.getInstance().release(ctrl)
```

池参数：`DEFAULT_MAX_SIZE = 3`，与多层 H5 栈上限对齐。

---

## §3 Bridge 分档注入（P1）

```typescript
// 路由传参
params[RouterKeys.BRIDGE_PROFILE] = String(bridgeProfile)

// 按场景默认
BridgeConfig.profileForScene(scene)  // community | mall | service | full

// onPageEnd 非 blank 时注入
this.webCtrl.injectBridgeScript(this.bridgeProfile)
```

community 档仅注入帖子详情所需 API，脚本体积约为 full 的 1/5。

---

## §4 子资源错误过滤（P1）

```typescript
// DIWeb.ets shouldIgnoreWebError
// - code -32 忽略
// - 页面已 loadedUrl 且非主文档 URL → 忽略
// - favicon.ico 404 不弹错误页

private handleWebError(code, info, requestUrl): void {
  if (this.shouldIgnoreWebError(code, requestUrl)) return
  this.errorMessage = `[${code}] ${info}`
}
```

---

## §5 Overlay 秒开（P2，multi=false 试点）

```
Flutter openH5 (useOverlay=true)
  → RouterManager.openOverlay
  → DIWebSession.openInOverlay(params)
  → AppStorage diwebOverlayVisible = true
  → DIWebOverlay.applyRouteParams (pendingNavigation=true)
  → DIWeb loadTargetUrl
  → onPageEnd → clearPendingNavigation → onActive
```

**pendingNavigation**：URL 切换时 `opacity=0` + 全屏 Loading，避免看到上一帖内容。

**返回**：`RouterManager.back()` → `closeOverlay()`，不 pop 路由栈。

---

## §6 预热时机

| 时机 | Demo | 建议公司 |
|------|------|---------|
| App 启动 | `EntryAbility` initializeWebEngine + preconnect；`Index` prewarm WebViewPool(2) | 同上 |
| 发现 Tab 显示 | `prewarmWeb` → preconnect + onActive | 社区 Tab onShown |
| Overlay Host | `DIWebOverlay.aboutToAppear` bind | Index build 即挂载 |

---

## §7 可观测性

### WebFlowTracer（E2E）

```typescript
WebFlowTracer.begin(`openH5 url=${url}`)
WebFlowTracer.step('RouterManager', 'branch=WebPageBridge')
WebFlowTracer.end('✅ 公司路由链路成功')
```

HiLog：`hilog | grep DIWeb-E2E`

### DIWebLoadMonitor（分段耗时 + 内存）

关键字段：`clickToBeginMs`, `pageLoadMs`, `pageRenderMs`, `bridgeInjectMs`, `displayReadyMs`,
`memoryPssKbClick`, `memoryPssKbEnd`, `memoryPssDeltaKb`, `webViewPoolSize`

HiLog：`hilog | grep DIWeb-Monitor`

```
#1 REPORT 耗时 | 可见=480ms HTML=474ms 渲染=206ms ...
#1 REPORT 内存 | 点击PSS=180.5 MB 完成PSS=192.3 MB Δ=+11.8 MB pool=2
```

---

## §8 本次会话修复的问题对照

| 症状 | 根因 | 修复 |
|------|------|------|
| pushUrl 失败 | 路由页 `pages/WebPageBridge` 未注册 | 改 `pages/DIWebPage` |
| 只显示 blank | loadUrl 与 blank 竞态 | scheduleInitialLoad + afterBlankReady |
| E2E 误报成功 | blank onPageEnd 触发 END | DIWebPage 忽略 blank |
| 重复 load 两次 | attach 与 afterBlankReady 双发 | 三态标志 + 仅 blank 后发 load |
| onActive failed | 预热时 Controller 未 attach Web | 无害 WARN，可延后 onActive |

---

## §9 官方 Web 引擎预连接（P1）

```typescript
// WebEnginePrewarm.ets
import { webview } from '@kit.ArkWeb'

// App 启动一次
webview.WebviewController.initializeWebEngine()

// 预连接：URL 去掉 # 前端路由，仅 origin+path
const entryUrl = url.split('#')[0]
webview.WebviewController.prepareForPageLoad(entryUrl, true, 2)  // sockets 1-6
```

**调用时机**：

| 时机 | Demo | 公司建议 |
|------|------|---------|
| App 启动 | `EntryAbility.onCreate` | 同上 |
| 社区 Tab 显示 | `DIWebSession.prewarmWeb` | 发现 Tab onShown |

**注意**：

- 只做 DNS + Socket，**不下载 HTML/JS**
- 与 WebViewPool **叠加**，不替代
- 同一 URL 建议 30s 冷却，避免频繁调用
- 公司生产环境将 `H5TestUrls.UAT_BASE` 换成真实社区 H5 入口

**HiLog 验收**：`hilog | grep DIWeb-Prewarm`

```
initializeWebEngine OK source=EntryAbility
preconnect OK url=https://common-cache-h5-uat.../index.html sockets=2
prefetchPage called ok trigger=社区Tab url=...pid=2406463
```

---

## §11 prefetchPage 页面预取（P1）

与 `prepareForPageLoad` 对比：

| API | 层级 | 需要 attach Web | 作用 |
|-----|------|----------------|------|
| `prepareForPageLoad` | 静态 | 否 | 仅 DNS + Socket |
| `prefetchPage` | 实例方法 | **是** | 下载主/子资源，不执行 JS，缓存约 5 分钟 |

```typescript
// 必须在已绑定 Web 组件的 Controller 上调用
this.webviewController.prefetchPage(
  'https://common-cache-h5-dev.bydauto.com/mpaas/.../index.html#/pages/community/imgDetail/index?type=2&pid=24847'
)
```

**Demo 调用时机**：

| 时机 | 来源 |
|------|------|
| Overlay blank 完成后 | `DIWeb.ets` `overlayBlankReady` |
| 发现 Tab prewarmWeb | `DIWebSession.prewarmWeb` |

**公司迁移**：在 WebPageBridge 的 Web `onPageEnd`（非 blank）时，对预测的下一跳 URL 调用 `prefetchPage`；或由 Flutter 列表曝光时传入 URL。

默认预取 URL：`H5TestUrls.PREFETCH_POST_URL`（公司改为 dev 域名即可）。

---

## §10 公司迁移时不要照搬

| Demo 行为 | 公司可能不同 |
|-----------|-------------|
| 默认 multi=false | 保留 multi=true 的 Web 内后退 |
| Overlay 为优化主路径 | 公司主路径仍是 push 多层 |
| DIWebPage 不用 WebViewPool | 公司应对 WebPageBridge 接 acquire/release |
| TestTab 调试入口 | 生产隐藏 |

---

## §12 内存监控（P1，2026-06 新增）

### DIWebMemoryMonitor.ets

```typescript
import { hidebug } from '@kit.PerformanceAnalysisKit'
import { taskpool } from '@kit.ArkTS'

@Concurrent
function readMemorySnapshotTask(): MemoryTaskResult {
  return {
    pssKb: Number(hidebug.getPss()),
    privateDirtyKb: Number(hidebug.getPrivateDirty()),
    sharedDirtyKb: Number(hidebug.getSharedDirty()),
    nativeHeapKb: Math.round(Number(hidebug.getNativeHeapAllocatedSize()) / 1024),
    timestamp: Date.now()
  }
}
// DIWebMemoryMonitor.readSnapshotAsync(callback)
```

**注意**：`getPss` 必须走 **taskpool**，禁止主线程。

### DIWebLoadMonitor 集成

| 时机 | 行为 |
|------|------|
| markClick | 异步采 memoryPssKbClick + webViewPoolSize |
| markReady | 异步采 memoryPssKbEnd，算 memoryPssDeltaKb |
| logReport | `REPORT 内存 \| 点击PSS=... 完成PSS=... Δ=... pool=...` |

### WebLoadMonitorPage

- 顶部：实时 PSS / Private / Shared / Native堆，2s 刷新
- 每条记录：`PSS 180MB → 192MB  Δ +12MB  池 2`

PSS 为**进程级**（含 Flutter + 所有 WebView），深链叠层时实时 PSS 会升高。
