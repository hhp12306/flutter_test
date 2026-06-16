# 给 AI 的提示词模板（公司迁移用）

明天在公司项目 Cursor 里，**先 @ 引用**：

- `@harmony-h5-fast-open-migrate/SKILL.md`
- `@harmony-h5-fast-open-migrate/demo-patterns.md`
- `@HarmonyFlutterMix`（整个 Demo 仓库，或具体文件）

然后按阶段复制下面提示词。**不要一次让 AI 全改**，分 P0 → P1 → 验收。

---

## 阶段 0：环境说明（第一条消息建议带上）

```
我在做 dilink-harmony 的 H5 打开性能优化。

参照仓库：HarmonyFlutterMix Demo（已真机验证）
目标仓库：当前公司项目（dilink-harmony-auto）

业务约束（必须遵守）：
1. 保留 router.push 多层 WebPageBridge 栈，不要默认改成单 WebView Overlay
2. 保留 multi=true 场景的 Web 内后退
3. 只迁移 Demo 已验证的优化，不要额外加需求外的功能
4. 先输出差异表，我确认后再改代码

请先读 @harmony-h5-fast-open-migrate/SKILL.md 和 demo-patterns.md，
对照公司项目的 WebPageBridge / WebContainer / RouterManager / EntryAbility，
输出「优化项 | Demo有 | 公司有 | 差异 | 优先级」表格，不要改代码。
```

---

## 阶段 1：P0 稳定性（about:blank 单次加载）

```
按 Demo 的 P0 方案，把 about:blank 占位 + scheduleInitialLoad + 三态标志
迁移到公司 WebContainer/DiWeb 层。

参照 Demo 文件：
- entry/src/main/ets/diweb/DIWeb.ets（DIWEB_BLANK_SRC、blankPlaceholderDone、targetPageLoaded）
- entry/src/main/ets/pages/DIWebPage.ets（blank onPageEnd 不算成功）

要求：
1. 每次打开 H5 仅 1 次 loadPage/loadUrl
2. WebPageBridge 的 E2E/成功回调不在 about:blank 时触发
3. 最小 diff，匹配公司现有命名和结构
4. 列出改动文件和 HiLog 验收关键词

不要改 WebViewPool、Overlay、prefetch，本轮只做 P0。
```

---

## 阶段 2：P1 三层预热（引擎 + 预连接 + 预取）

```
按 Demo 迁移 WebEnginePrewarm（P1）：

参照：
- entry/src/main/ets/diweb/WebEnginePrewarm.ets
- entry/src/main/ets/entryability/EntryAbility.ets（onCreate）
- entry/src/main/ets/diweb/DIWebSession.ets（prewarmWeb 里 preconnect + prefetchPage）
- entry/src/main/ets/diweb/DIWebController.ets（prefetchPage 封装）

公司侧：
1. EntryAbility.onCreate → initializeWebEngine + preconnect（URL 去 #，30s 冷却）
2. 社区 Tab 显示时 → preconnect + prefetchPage（完整 URL 含 #，60s 冷却）
3. prefetch 必须在已 attach Web 的 Controller 上调用
4. 生产 URL 用公司社区 H5 入口，不要用 Demo UAT 写死

验收 HiLog：DIWeb-Prewarm 出现 initializeWebEngine OK、preconnect OK、prefetchPage called ok
```

---

## 阶段 3：P1 WebViewPool（公司必做，Demo 未完全接）

```
按 Demo 迁移 WebViewPool，并在公司 WebPageBridge 接入 acquire/release：

参照：
- entry/src/main/ets/common/core/components/web/WebViewPool.ets
- entry/src/main/ets/pages/Index.ets（prewarm(2)）

要求：
1. App 启动 prewarm(2)，maxSize=3
2. WebPageBridge 打开时 acquire()，无则 new
3. aboutToDisappear 时 release()
4. 与多层 push 栈兼容

注意：Demo 的 DIWebPage 尚未 acquire，公司要补上这一步。
```

---

## 阶段 4：P1 监控（耗时 + 内存）

```
按 Demo 迁移加载监控与内存监控：

参照：
- entry/src/main/ets/diweb/DIWebLoadMonitor.ets（分段耗时 + memoryPssKbClick/End/Delta）
- entry/src/main/ets/diweb/DIWebMemoryMonitor.ets（hidebug + taskpool，禁止主线程 getPss）
- entry/src/main/ets/pages/mine/WebLoadMonitorPage.ets（实时 PSS + 每条记录 Δ）
- entry/src/main/ets/common/core/utils/WebFlowTracer.ets

要求：
1. markClick 时异步采 PSS；markReady 时采完成 PSS 并算 Delta
2. HiLog 输出 REPORT 内存 行
3. 若公司已有 WebLoadMonitor，合并字段，不要重复造两套 UI
4. getPss 必须走 taskpool 异步线程
```

---

## 阶段 5：P1 Bridge 分档 + 错误过滤

```
按 Demo 迁移：

1. Bridge 分档：BridgeProfile / bridgeProfile 路由传参，社区帖用 community
   参照 BridgeProfile.ets、DIWebBridgeScript.ets、RouterManager.ets

2. 子资源错误过滤：favicon 404 不弹整页错误
   参照 DIWeb.ets shouldIgnoreWebError

不要改 multi 后退逻辑。
```

---

## 阶段 6：P2 Overlay 试点（可选，需你确认）

```
仅对 multi=false / 社区帖详情 试点 Overlay 秒开：

参照 DIWebOverlay.ets、DIWebSession.ets、RouterManager.openOverlay

要求 useOverlay 开关，默认仍走 push；A/B 对比 displayReadyMs。
需我确认场景后再做。
```

---

## 阶段 7：验收（让 AI 帮你对日志）

```
我跑了真机，请对照 Demo 验收标准分析这段 HiLog：

[粘贴 DIWeb-Prewarm + DIWeb-E2E + DIWeb-Monitor 日志]

检查：
1. 是否仅 1 次 loadPage trigger=afterBlankReady
2. 是否有 #13 END 成功且 URL 非 blank
3. prefetch/preconnect 是否生效
4. REPORT 耗时与 REPORT 内存是否合理
5. 有无需要修的 WARN（忽略 favicon 404、WebViewPool onActive failed）
```

---

## 常见问题：怎么 @ 文件

| 目的 | Cursor 操作 |
|------|------------|
| 引用整个 skill | `@.cursor/skills/harmony-h5-fast-open-migrate/SKILL.md` |
| 引用 Demo 某文件 | `@HarmonyFlutterMix/entry/src/main/ets/diweb/DIWeb.ets` |
| 引用公司文件 | `@dilink/.../WebPageBridge.ets`（按实际路径） |
| 禁止 AI 乱改 | 提示词里写「最小 diff」「不要改 multi」「先差异表」 |

---

## 一句话版（赶时间用）

```
按 @harmony-h5-fast-open-migrate 把 Demo H5 快速打开优化迁到公司项目：
P0 blank单次加载 → P1 preconnect+prefetch+WebViewPool acquire/release+监控内存。
保留多层 push 和 multi=true。先差异表再改代码，参照 HarmonyFlutterMix 同名文件。
```
