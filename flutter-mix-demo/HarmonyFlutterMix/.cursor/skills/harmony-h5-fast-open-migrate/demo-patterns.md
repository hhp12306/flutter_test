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
| App 启动 | `Index` prewarm WebViewPool(2) | 同上 |
| 发现 Tab 显示 | `prewarmWeb('DiscoverTab')` | 社区 Tab onShown |
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

### DIWebLoadMonitor（分段耗时）

关键字段：`clickToBeginMs`, `pageLoadMs`, `bridgeInjectMs`, `displayReadyMs`

HiLog：`hilog | grep DIWeb-Monitor`

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

## §9 公司迁移时不要照搬

| Demo 行为 | 公司可能不同 |
|-----------|-------------|
| 默认 multi=false | 保留 multi=true 的 Web 内后退 |
| Overlay 为优化主路径 | 公司主路径仍是 push 多层 |
| DIWebPage 不用 WebViewPool | 公司应对 WebPageBridge 接 acquire/release |
| TestTab 调试入口 | 生产隐藏 |
