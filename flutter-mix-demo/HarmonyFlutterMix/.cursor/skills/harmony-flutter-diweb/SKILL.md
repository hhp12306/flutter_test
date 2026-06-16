---
name: harmony-flutter-diweb-optimization
description: >-
  HarmonyFlutterMix Demo — Flutter跳转H5性能优化参考方案。单WebView Overlay常驻、预热、Bridge分档、加载监控、稳定性修复。
  用于与公司 dilink 项目做架构比对、迁移评估、性能排查，或用户提到 Harmony Flutter H5、WebView预热、JSBridge、Overlay秒开时。
type: project
---

# HarmonyFlutterMix — Flutter跳转H5性能优化

## 何时使用

用户要把 Demo 方案迁移到公司项目，或让 AI **对照现有实现做深度分析**时：

1. 先读完整文档：[harmony-flutter-diweb-optimization-analysis.md](harmony-flutter-diweb-optimization-analysis.md)
2. 按「架构比对清单」逐项检查目标项目代码
3. 输出差异表：已有优化 / 缺失优化 / 需改造 / 不适用
4. 按优先级给出迁移或继续优化建议

## 业务前提（比对前先确认）

| 约定 | Demo 现状 |
|------|-----------|
| 发现 Tab | 嵌入 Flutter 社区首页 |
| 二级页 | 远程 H5，Flutter 经 MethodChannel 传 URL |
| 返回 | **直接关 Overlay 回 Flutter**，不走 Web 内后退 |
| URL | 帖子/详情 URL **各不相同** |
| WebView | **全 App 共用一个**（Index 层 `DIWebOverlay` 常驻） |
| 关 H5 后 | Flutter **不需要刷新** |
| multi 后退 | **不支持**（与 dilink `multi=true` 不同） |

**与公司项目关系**：

- **默认路径**：与公司一致 `router.push WebPageBridge`，每页独立 Controller + WebViewPool
- **优化路径**：`useOverlay=true` 时走 `DIWebOverlay` 单 WebView（Demo 方案，可 A/B 对比）

## 核心架构（公司镜像 7 层，默认）

```
Flutter openH5
  → NavigateService.toWebview
  → CoreUtils.navigateToWebview（场景 flag 判断）
  → RouterManager.routerToWebPageBridge
  → DiNavigation.build(WebPageBridge).navigation()
  → WebPageBridge（JsBridgeApi + ActionJsApi + WebViewPool）
  → WebContainer → DIWeb
```

**Overlay 优化路径**：`useOverlay=true` → `DIWebSession.openInOverlay` → `DIWebOverlay`

**关键文件**（相对 `entry/src/main/ets/`）：

| 模块 | 文件 | 对齐公司 |
|------|------|---------|
| Flutter 入口 | `service/flutter_bridge/services/NavigateService.ets` | NavigateService |
| 场景路由 | `common/core/components/utils/CoreUtils.ets` | CoreUtils |
| 路由 | `common/core/router/RouterManager.ets` | RouterManager |
| H5 页面 | `common/core/components/page/WebPageBridge.ets` | WebPageBridge |
| Web 容器 | `common/core/components/web/WebContainer.ets` | WebContainer |
| Bridge | `common/core/components/web/JsBridgeApi.ets` | JsBridgeApi |
| 预热池 | `common/core/components/web/WebViewPool.ets` | WebViewPool |
| 引擎层 | `diweb/*` | DiWeb 底层 |
| Overlay 优化 | `diweb/DIWebOverlay.ets` | Demo 独有 |

## 已实施优化（Demo 现状，2026-06 真机验证）

| 优化项 | 状态 | 实测收益 |
|--------|------|---------|
| about:blank 单次加载 | ✅ 已验证 | 消除 blank 竞态 / 双 load |
| initializeWebEngine + preconnect | ✅ 已验证 | 启动即预连 |
| prefetchPage | ✅ 已验证 | 同帖 1314ms→480ms，换帖 205ms |
| WebViewPool prewarm(2) | ✅ Index | 池内 2 个 Controller |
| WebViewPool acquire/release | ❌ DIWebPage 未接 | 公司 WebPageBridge 必接 |
| Bridge 分档 community/full | ✅ 已实施 | community 1–11ms |
| DIWebLoadMonitor 分段耗时 | ✅ 已实施 | HiLog `#N REPORT` |
| **DIWebMemoryMonitor 内存** | ✅ 本次新增 | PSS Δ + 监控页实时 |
| Index Overlay 单 WebView | ✅ 已实施 | Overlay ~0–1ms |
| 子资源错误过滤 | ✅ 已实施 | favicon 404 忽略 |
| 同 URL 缓存秒开 | ✅ 已实施 | ~5ms |

**公司迁移主 skill**：`.cursor/skills/harmony-h5-fast-open-migrate/`（含 [ai-prompt-template.md](../harmony-h5-fast-open-migrate/ai-prompt-template.md)）

## Demo 仍可优化项（对照公司文档后的差距）

| 优化项 | 现状问题 | 建议 | 优先级 |
|--------|---------|------|--------|
| 默认 Bridge 档位 | `DIWebRouter` 默认 `full`；商城/爱车/服务未传 profile | 默认改 `community`，各 Tab 按场景传档 | P1 |
| 预热时机 | 仅 `DiscoverTab` 激活时预热 | `Index.aboutToAppear` 提前预热，覆盖非发现 Tab 入口 | P1 |
| Bridge 档位扩展 | 仅 community/full | 增加 `mall`/`service` 档（对齐公司方案） | P2 |
| 远程 HTML | 占可见耗时 95%+ | H5 骨架屏/CDN/SSR，原生无法单独解决 | P2 |
| 测试 Tab | 上线暴露调试入口 | 移入「我的」或移除 | P2 |
| DIWebPage fallback | `useOverlay=false` 仍走 router | 保留作调试，生产路径只用 Overlay | P3 |

## 性能对比（Demo 实测 vs 公司预估）

| 指标 | Demo 实测 | 公司项目预估 | Demo 优势 |
|------|----------|-------------|----------|
| WebView 冷启动 | ~55ms（预热后首开） | 150–250ms | Overlay 常驻 |
| Bridge 注入 | 6–11ms (community) | 30–60ms (90+ API) | 分档注入 |
| 路由/显隐 | ~1ms (Overlay) | 35–60ms (push) | 无路由栈 |
| 远程 HTML | 300–800ms+ | 300–800ms+ | 相同瓶颈 |
| **原生总开销** | **~8–60ms** | **215–370ms** | **约 3–5 倍** |

## 与公司项目比对输出模板

```markdown
## 架构比对
| 项 | Demo (DIWeb) | 公司 (dilink) | 建议 |

## 性能预期
| 场景 | Demo 实测 | 公司现状 | 迁移收益 |

## 迁移优先级
- P0：稳定性（错误过滤、Web 不 detach）
- P1：预热池/单 WebView、Bridge 分档、URL 遮罩
- P2：Overlay 混合方案（仅 multi=false 场景）
- P3：全量 Overlay 重构

## 不适用项
（multi=true、特殊场景路由等）
```

## 实施路线图（公司侧参考）

**Week 1 (P1)**：WebView 预热池 + Bridge 分档 + URL 遮罩 + 移植 DIWebLoadMonitor  
**Week 2**：真机 3–5 个真实 H5 URL + Bridge API 清单梳理  
**Week 3 (可选)**：multi=false 场景 Overlay 混合方案

## 关键代码索引

| 行为 | 文件 | 位置 |
|------|------|------|
| Overlay 常驻 | Index.ets | `DIWebOverlay()` + zIndex |
| Flutter 入口 | DIWebChannelPlugin.ets | `openH5` case |
| 打开 H5 | DIWebRouter.ets | `open()` |
| 关闭 H5 | DIWebRouter.ets | `back()` → `closeOverlay()` |
| 预热 | DIWebSession.ets | `prewarmWeb()` |
| 遮罩 | DIWebOverlay.ets | `pendingNavigation` |
| Bridge 注入 | DIWeb.ets | `onPageEnd` → `injectBridgeScript` |
| 错误过滤 | DIWeb.ets | `shouldIgnoreWebError()` |
| 监控 REPORT | DIWebLoadMonitor.ets | `logReport()` |
| 内存监控 | DIWebMemoryMonitor.ets | `readSnapshotAsync()` |
| 监控 UI | WebLoadMonitorPage.ets | 实时 PSS + 记录 Δ |

## 详细文档

完整架构剖析、WebView 层级、瓶颈诊断、分阶段方案、FAQ 见：  
[harmony-flutter-diweb-optimization-analysis.md](harmony-flutter-diweb-optimization-analysis.md)
