import { webview } from '@kit.ArkWeb'
import { H5TestUrls } from '../common/core/components/web/H5TestUrls'
import { DIWebLog, DIWebLogTag } from './DIWebLog'
import { DIWebController } from './DIWebController'

const DEFAULT_PRECONNECT_SOCKETS: number = 2
/** 同一入口 URL 预连接冷却，避免 Tab 切换时频繁调用 */
const PRECONNECT_COOLDOWN_MS: number = 30_000
/** 同一 URL 预取冷却（系统缓存 5 分钟，避免重复下载） */
const PREFETCH_COOLDOWN_MS: number = 60_000

/**
 * 官方 Web 引擎预热：initializeWebEngine + prepareForPageLoad（DNS + Socket 预连接，不拉资源）
 */
export class WebEnginePrewarm {
  private static engineInitialized: boolean = false
  private static lastPreconnectUrl: string = ''
  private static lastPreconnectTime: number = 0
  private static lastPrefetchUrl: string = ''
  private static lastPrefetchTime: number = 0

  /** App 启动调用一次即可 */
  static initializeEngine(source: string): void {
    if (WebEnginePrewarm.engineInitialized) {
      DIWebLog.infoT(DIWebLogTag.PREWARM,
        'initializeWebEngine SKIP already done source=%{public}s', source)
      return
    }
    try {
      webview.WebviewController.initializeWebEngine()
      WebEnginePrewarm.engineInitialized = true
      DIWebLog.infoT(DIWebLogTag.PREWARM, 'initializeWebEngine OK source=%{public}s', source)
    } catch (e) {
      DIWebLog.warnT(DIWebLogTag.PREWARM,
        'initializeWebEngine failed source=%{public}s err=%{public}s', source, String(e))
    }
  }

  /** 预连接入口 URL（去掉 # 及前端路由，仅 origin+path） */
  static stripHash(url: string): string {
    const hashIndex = url.indexOf('#')
    return hashIndex >= 0 ? url.substring(0, hashIndex) : url
  }

  static preconnect(url: string, source: string, numSockets: number = DEFAULT_PRECONNECT_SOCKETS): void {
    WebEnginePrewarm.initializeEngine(source)
    const entryUrl = WebEnginePrewarm.stripHash(url)
    if (!entryUrl.startsWith('http://') && !entryUrl.startsWith('https://')) {
      DIWebLog.warnT(DIWebLogTag.PREWARM,
        'preconnect SKIP invalid url=%{public}s source=%{public}s', url, source)
      return
    }
    const socketCount = Math.max(1, Math.min(6, numSockets))
    const now = Date.now()
    if (entryUrl === WebEnginePrewarm.lastPreconnectUrl &&
      now - WebEnginePrewarm.lastPreconnectTime < PRECONNECT_COOLDOWN_MS) {
      DIWebLog.infoT(DIWebLogTag.PREWARM,
        'preconnect SKIP cooldown url=%{public}s source=%{public}s', entryUrl, source)
      return
    }
    try {
      webview.WebviewController.prepareForPageLoad(entryUrl, true, socketCount)
      WebEnginePrewarm.lastPreconnectUrl = entryUrl
      WebEnginePrewarm.lastPreconnectTime = now
      DIWebLog.infoT(DIWebLogTag.PREWARM,
        'preconnect OK url=%{public}s sockets=%{public}s source=%{public}s',
        entryUrl, String(socketCount), source)
    } catch (e) {
      DIWebLog.warnT(DIWebLogTag.PREWARM,
        'preconnect failed url=%{public}s source=%{public}s err=%{public}s',
        entryUrl, source, String(e))
    }
  }

  /** Demo 社区 UAT 默认 H5 入口 */
  static preconnectCommunityDefault(source: string): void {
    WebEnginePrewarm.preconnect(H5TestUrls.UAT_BASE, source)
  }

  /**
   * 预取页面（prefetchPage）：下载主/子资源，不执行 JS。
   * 必须在已 attach Web 组件的 Controller 上调用；缓存约 5 分钟。
   * SPA 可传完整 URL（含 # 路由）。
   */
  static prefetchPage(controller: DIWebController, url: string, source: string): void {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      DIWebLog.warnT(DIWebLogTag.PREWARM,
        'prefetchPage SKIP invalid url=%{public}s source=%{public}s', url, source)
      return
    }
    const now = Date.now()
    if (url === WebEnginePrewarm.lastPrefetchUrl &&
      now - WebEnginePrewarm.lastPrefetchTime < PREFETCH_COOLDOWN_MS) {
      DIWebLog.infoT(DIWebLogTag.PREWARM,
        'prefetchPage SKIP cooldown url=%{public}s source=%{public}s', url, source)
      return
    }
    if (controller.prefetchPage(url, source)) {
      WebEnginePrewarm.lastPrefetchUrl = url
      WebEnginePrewarm.lastPrefetchTime = now
    }
  }

  /** 预取 Demo 默认社区帖子（UAT，含 hash） */
  static prefetchCommunityDefaultPost(controller: DIWebController, source: string): void {
    WebEnginePrewarm.prefetchPage(controller, H5TestUrls.PREFETCH_POST_URL, source)
  }
}
