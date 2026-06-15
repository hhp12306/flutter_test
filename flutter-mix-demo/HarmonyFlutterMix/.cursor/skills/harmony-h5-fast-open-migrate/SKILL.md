---
name: harmony-h5-fast-open-migrate
description: >-
  将 HarmonyFlutterMix Demo 的 H5 快速打开优化迁移到公司 dilink-harmony 项目。
  覆盖 WebView 预热池、about:blank 占位加载、Bridge 分档注入、Overlay 秒开、加载监控、错误过滤、E2E 追踪。
  在用户提到公司 H5 慢、WebView 优化、Flutter 跳 H5、WebPageBridge 性能迁移、dilink WebView 时使用。
type: project
---

# H5 快速打开 — 公司项目迁移 Skill

## 使用方式（明天带 Demo 进公司项目时）

1. **打开本 Demo 仓库**作参照，在公司项目 Cursor 中 `@` 引用本 skill
2. 先读 [demo-patterns.md](demo-patterns.md) 对照 Demo 关键代码
3. 按下方「迁移优先级」逐项比对公司代码，输出差异表后再改
4. 每改一项用 HiLog 验证（见「验收标准」）

## 业务边界（与公司项目对齐）

| 项 | Demo | 公司 dilink（默认保留） |
|----|------|------------------------|
| 路由栈 | `router.push` 可叠多层 H5 | **保留多层 WebPageBridge** |
| multi 内退 | Demo 默认 false | 公司 **multi=true** 场景保留 Web 内后退 |
| Overlay | `useOverlay=true` 可选 | 仅 **multi=false / 社区帖** 等场景试点 |
| WebView | 路由模式每页独立 Controller | **WebViewPool acquire/release** 应对多页 |

**不要**在公司项目里默认改成单 WebView Overlay 全局替换 push，除非业务确认。

---

## 优化项总览（按「快速打开」价值排序）

### A. 加载稳定性（本次会话已验证，P0）

| 优化 | 作用 | Demo 文件 |
|------|------|-----------|
| **about:blank 占位 src** | Web 初始 src 不写 demo.html，避免历史栈多一层 | `diweb/DIWeb.ets` `DIWEB_BLANK_SRC` |
| **scheduleInitialLoad** | attach 时若在 blank 阶段则等待，不抢先 loadUrl | `DIWeb.ets` |
| **blankPlaceholderDone** | blank 完成后只 load 一次 | `DIWeb.ets` |
| **targetPageLoaded** | 目标页已成功 onPageEnd 后忽略迟到 blank 事件 | `DIWeb.ets` |
| **DIWebPage 忽略 blank** | E2E/遮罩不以 about:blank 当作加载成功 | `pages/DIWebPage.ets` |

**理想日志（单次 loadPage）**：
```
scheduleInitialLoad wait blank placeholder
onPageEnd blank -> loadTargetUrl (afterBlankReady)
onPageBegin/End 真实 UAT URL
```

### B. 原生侧耗时削减（P1，Demo 已有）

| 优化 | 预期收益 | Demo 文件 |
|------|---------|-----------|
| **WebViewPool 预热** | 冷启动 Controller 150–250ms → 复用后更低 | `WebViewPool.ets`, `Index.ets` prewarm(2) |
| **Bridge 分档注入** | community 6–11ms vs full 30–60ms | `BridgeProfile.ets`, `DIWebBridgeScript.ets` |
| **按 scene 选 profile** | 社区帖用 community，商城/服务用对应档 | `BridgeConfig.profileForScene()` |
| **子资源错误过滤** | favicon 404 不误报整页失败 | `DIWeb.ets` `shouldIgnoreWebError()` |
| **pendingNavigation 遮罩** | URL 切换时全屏 Loading，无旧页闪烁 | `DIWebOverlay.ets`, `DIWebPage.ets` |

### C. 秒开路径（P1–P2，Overlay 试点）

| 优化 | 作用 | Demo 文件 |
|------|------|-----------|
| **Index 层 DIWebOverlay 常驻** | 打开 H5 不走 push，显隐 ~1ms | `Index.ets`, `DIWebOverlay.ets` |
| **DIWebSession 单 Controller** | 全 App 一个 WebviewController 复用 | `DIWebSession.ets` |
| **Tab 激活 prewarmWeb** | 发现 Tab 激活时引擎已 attach | `DiscoverTab` → `prewarmWeb()` |
| **ensureDisplayReady 缓存秒开** | 同 URL 再次打开 ~5ms 复用 | `DIWeb.ets` |
| **onActive/onInactive** | Overlay 隐藏时暂停 Web 渲染 | `DIWebController.ets` |

### D. 可观测性（迁移必带，P1）

| 工具 | HiLog Tag | 文件 |
|------|-----------|------|
| 全链路 E2E | `DIWeb-E2E` | `WebFlowTracer.ets` |
| 分段耗时 REPORT | `DIWeb-Monitor` | `DIWebLoadMonitor.ets` |
| 视图/加载 | `DIWeb-View` | `DIWeb.ets`, `DIWebController.ets` |

---

## 迁移工作流

### Step 1：架构比对（只读，先不改代码）

在公司项目搜索并对照：

```
WebPageBridge / WebContainer / JsBridgeApi / RouterManager
WebviewController / loadUrl / onPageEnd / injectBridge
```

输出表格：

```markdown
| 优化项 | Demo 有 | 公司有 | 差异 | 优先级 |
```

### Step 2：P0 稳定性（所有 Web 页受益）

1. 移植 `about:blank` + `scheduleInitialLoad` + 三态标志（见 demo-patterns.md §1）
2. WebPageBridge / WebContainer 的 onPageEnd **不要**在 blank 时标记成功
3. 真机验证：HiLog 过滤 `DIWeb-View`，确认 **每次打开仅 1 次 loadPage**

### Step 3：P1 公司路由加速（保留多层栈）

1. **WebViewPool**：`Index.aboutToAppear` prewarm；`WebPageBridge.aboutToDisappear` release
2. **WebPageBridge** 创建 Web 时 `acquire()` 池化 Controller，无则 new
3. **Bridge 分档**：`RouterManager` 传 `bridgeProfile`，`onPageEnd` 按档注入
4. **shouldIgnoreWebError**：忽略子资源 404、非主文档错误
5. 接入 **DIWebLoadMonitor** + **WebFlowTracer**

### Step 4：P2 Overlay 试点（可选，multi=false 场景）

1. Index 加 `DIWebOverlay` + `DIWebSession`
2. `CoreUtils.navigateToWebview` 加 `useOverlay` 开关
3. A/B：同 URL 对比 push vs Overlay 的 `displayReadyMs`

### Step 5：验收

| 检查 | 标准 |
|------|------|
| 单次 load | 每次打开 H5 仅 1 次 `loadPage trigger=afterBlankReady`（或 onUrlChanged） |
| E2E | `DIWeb-E2E` 出现 `[END] ✅` 且 onPageEnd 为真实 URL |
| 多层栈 | 连续 push 3 个帖子，返回 3 次回到 Tab |
| Bridge | community 帖 `injectBridgeScript` < 15ms |
| 误报 | favicon 404 不触发错误页 |

---

## 与公司项目的映射表

| Demo（HarmonyFlutterMix） | 公司（dilink-harmony-auto） |
|---------------------------|----------------------------|
| `pages/DIWebPage.ets` | `WebPageBridge` 路由页 |
| `RouterManager.routerToWebPageBridge` | 同名或等价 RouterManager |
| `DiNavigation` → `pages/DIWebPage` | `DiNavigation` → WebPageBridge 注册页 |
| `DIWeb.ets` | DiWeb / Web 封装层 |
| `WebViewPool.ets` | JsApiWebController 池 / 公司 P1 方案 |
| `DIWebOverlay.ets` | 新增（公司暂无则新建） |
| `BridgeProfile.COMMUNITY` | 社区场景 Bridge 白名单 |

---

## 给 Agent 的输出要求

迁移分析或实施完成后，必须输出：

1. **差异表**（已有 / 缺失 / 不适用）
2. **改动文件清单**（公司项目路径）
3. **风险点**（multi=true、特殊路由、权限）
4. **验证步骤**（HiLog 过滤词 + 操作路径）
5. **不要做的项**（除非用户明确要求）

---

## 参考

- Demo 代码细节：[demo-patterns.md](demo-patterns.md)
- 完整架构分析：`../harmony-flutter-diweb/harmony-flutter-diweb-optimization-analysis.md`
- Demo 测试入口：`entry/.../pages/tabs/TestTab.ets` + `H5TestUrls.ets`
