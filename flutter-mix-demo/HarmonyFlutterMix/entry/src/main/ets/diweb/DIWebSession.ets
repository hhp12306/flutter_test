import { DIWebController } from './DIWebController'
import { DIWebRouteParams } from './DIWebRouter'
import { DIWebBridgeProfile } from './DIWebTypes'
import { DIWebLog, DIWebLogTag, DIWebNavTrace } from './DIWebLog'

/** DIWebPage / Overlay 路由更新回调 */
export type DIWebRouteApplyFn = (params: DIWebRouteParams) => void

/** AppStorage key：Overlay 是否可见 */
export const DIWEB_OVERLAY_VISIBLE_KEY: string = 'diwebOverlayVisible'

/**
 * WebView 单例会话：Index Overlay 常驻 + 复用 WebviewController
 */
export class DIWebSession {
  private static instance: DIWebSession | null = null
  private readonly sharedController: DIWebController = new DIWebController()
  private overlayApplyFn: DIWebRouteApplyFn | null = null
  private overlayHostReady: boolean = false
  private pageApplyFn: DIWebRouteApplyFn | null = null
  private pageActive: boolean = false
  private lastOverlayUrl: string = ''
  private lastOverlayTitle: string = ''
  private prewarmSource: string = ''
  private prewarmTime: number = 0
  private prewarmed: boolean = false
  private currentBridgeProfile: DIWebBridgeProfile = 'full'

  getLastOverlayUrl(): string {
    return this.lastOverlayUrl
  }

  getLastOverlayTitle(): string {
    return this.lastOverlayTitle
  }

  static getInstance(): DIWebSession {
    if (DIWebSession.instance === null) {
      DIWebSession.instance = new DIWebSession()
    }
    return DIWebSession.instance
  }

  static initOverlayStorage(): void {
    if (!AppStorage.has(DIWEB_OVERLAY_VISIBLE_KEY)) {
      AppStorage.setOrCreate(DIWEB_OVERLAY_VISIBLE_KEY, false)
    }
  }

  getSharedController(): DIWebController {
    return this.sharedController
  }

  /** 社区 Tab 激活时预热 WebView 引擎（Overlay 内 about:blank 已挂载） */
  prewarmWeb(source: string): void {
    const overlayReady = this.isOverlayHostReady()
    const overlayVisible = this.isOverlayVisible()
    const webUrl = this.sharedController.getCurrentUrl()
    const onBlank = this.sharedController.isOnBlankPage()
    const prevSource = this.prewarmSource
    const prevTime = this.prewarmTime
    const now = Date.now()
    this.prewarmSource = source
    this.prewarmTime = now
    this.prewarmed = true
    DIWebLog.infoT(DIWebLogTag.PREWARM,
      'prewarmWeb BEGIN source=%{public}s overlayReady=%{public}s overlayVisible=%{public}s webUrl=%{public}s onBlank=%{public}s canGoBack=%{public}s',
      source, String(overlayReady), String(overlayVisible), webUrl || '(empty)',
      String(onBlank), String(this.sharedController.canGoBack()))
    if (prevTime > 0) {
      DIWebLog.infoT(DIWebLogTag.PREWARM,
        'prewarmWeb REPEAT prevSource=%{public}s prevAgeMs=%{public}s -> source=%{public}s',
        prevSource || '(none)', String(now - prevTime), source)
    }
    if (!overlayReady) {
      DIWebLog.warnT(DIWebLogTag.PREWARM,
        'prewarmWeb overlayHostNotReady: Web 组件可能尚未 attach，预热效果可能有限')
    }
    if (overlayVisible) {
      DIWebLog.warnT(DIWebLogTag.PREWARM,
        'prewarmWeb overlayVisible=true: 当前 H5 正在显示，onActive 可能与 Overlay 生命周期冲突')
    }
    try {
      this.sharedController.onActive()
      DIWebLog.infoT(DIWebLogTag.PREWARM, 'prewarmWeb onActive ok source=%{public}s', source)
    } catch (e) {
      DIWebLog.warnT(DIWebLogTag.PREWARM, 'prewarmWeb onActive failed source=%{public}s err=%{public}s',
        source, String(e))
    }
    DIWebLog.infoT(DIWebLogTag.PREWARM, 'prewarmWeb END source=%{public}s time=%{public}s',
      source, String(this.prewarmTime))
  }

  /** 供日志/诊断输出当前会话快照 */
  getDiagnosticSummary(): string {
    return `prewarm=${this.prewarmed} source=${this.prewarmSource || '-'} ` +
      `overlayReady=${this.isOverlayHostReady()} overlayVisible=${this.isOverlayVisible()} ` +
      `bridge=${this.currentBridgeProfile} lastUrl=${this.lastOverlayUrl || '-'} ` +
      `webUrl=${this.sharedController.getCurrentUrl() || 'about:blank'}`
  }

  isPrewarmed(): boolean {
    return this.prewarmed
  }

  getPrewarmSource(): string {
    return this.prewarmSource
  }

  getPrewarmTime(): number {
    return this.prewarmTime
  }

  setCurrentBridgeProfile(profile: DIWebBridgeProfile): void {
    const prev = this.currentBridgeProfile
    this.currentBridgeProfile = profile
    if (prev !== profile) {
      DIWebLog.infoT(DIWebLogTag.BRIDGE, 'setBridgeProfile %{public}s -> %{public}s', prev, profile)
    }
  }

  getCurrentBridgeProfile(): DIWebBridgeProfile {
    return this.currentBridgeProfile
  }

  bindOverlayHost(applyFn: DIWebRouteApplyFn): void {
    this.overlayApplyFn = applyFn
    this.overlayHostReady = true
    DIWebLog.infoT(DIWebLogTag.SESSION, 'bindOverlayHost hostReady=true')
  }

  unbindOverlayHost(): void {
    this.overlayApplyFn = null
    this.overlayHostReady = false
    DIWebLog.infoT(DIWebLogTag.SESSION, 'unbindOverlayHost hostReady=false')
  }

  isOverlayHostReady(): boolean {
    return this.overlayHostReady && this.overlayApplyFn !== null
  }

  /** 在 Index Overlay 中打开 H5，Web 容器不销毁 */
  openInOverlay(params: DIWebRouteParams, navId: number = 0): boolean {
    if (!this.isOverlayHostReady() || this.overlayApplyFn === null) {
      if (navId > 0) {
        DIWebNavTrace.step(navId, 'openInOverlay_skip', 'overlayHostNotReady')
      }
      DIWebLog.warnT(DIWebLogTag.SESSION, 'openInOverlay skip: hostNotReady')
      return false
    }
    const wasVisible = this.isOverlayVisible()
    const sameUrl = params.url === this.lastOverlayUrl
    if (navId > 0) {
      DIWebNavTrace.step(navId, 'openInOverlay',
        `wasVisible=${String(wasVisible)} sameUrl=${String(sameUrl)} lastUrl=${this.lastOverlayUrl} -> ${params.url}`)
    }
    DIWebLog.infoT(DIWebLogTag.SESSION,
      'openInOverlay url=%{public}s title=%{public}s bridge=%{public}s wasVisible=%{public}s sameUrl=%{public}s reopen=%{public}s webCanGoBack=%{public}s',
      params.url, params.title ?? '', params.bridgeProfile ?? 'full', String(wasVisible), String(sameUrl),
      String(!wasVisible && sameUrl), String(this.sharedController.canGoBack()))
    if (params.bridgeProfile) {
      this.currentBridgeProfile = params.bridgeProfile
    }
    this.overlayApplyFn(params)
    this.lastOverlayUrl = params.url
    this.lastOverlayTitle = params.title ?? ''
    AppStorage.set(DIWEB_OVERLAY_VISIBLE_KEY, true)
    return true
  }

  closeOverlay(navId: number = 0): boolean {
    const visible = AppStorage.get<boolean>(DIWEB_OVERLAY_VISIBLE_KEY) ?? false
    if (!visible) {
      if (navId > 0) {
        DIWebNavTrace.step(navId, 'closeOverlay_skip', 'notVisible')
      }
      return false
    }
    if (navId > 0) {
      DIWebNavTrace.step(navId, 'closeOverlay', `lastUrl=${this.lastOverlayUrl}`)
    }
    AppStorage.set(DIWEB_OVERLAY_VISIBLE_KEY, false)
    DIWebLog.infoT(DIWebLogTag.SESSION, 'closeOverlay lastUrl=%{public}s webCanGoBack=%{public}s',
      this.lastOverlayUrl, String(this.sharedController.canGoBack()))
    return true
  }

  isOverlayVisible(): boolean {
    return AppStorage.get<boolean>(DIWEB_OVERLAY_VISIBLE_KEY) ?? false
  }

  isPageActive(): boolean {
    return this.pageActive && this.pageApplyFn !== null
  }

  bindPage(applyFn: DIWebRouteApplyFn): void {
    this.pageApplyFn = applyFn
    this.pageActive = true
    DIWebLog.infoT(DIWebLogTag.SESSION, 'bindPage pageActive=true')
  }

  unbindPage(): void {
    this.pageApplyFn = null
    this.pageActive = false
    DIWebLog.infoT(DIWebLogTag.SESSION, 'unbindPage pageActive=false')
  }

  /** DIWebPage 已在前台时原地换 URL（router 栈 fallback） */
  tryNavigate(params: DIWebRouteParams, navId: number = 0): boolean {
    if (!this.isPageActive() || this.pageApplyFn === null) {
      if (navId > 0) {
        DIWebNavTrace.step(navId, 'tryNavigate_skip', 'pageNotActive')
      }
      return false
    }
    if (navId > 0) {
      DIWebNavTrace.step(navId, 'tryNavigate', params.url)
    }
    DIWebLog.infoT(DIWebLogTag.SESSION, 'tryNavigate reuse url=%{public}s title=%{public}s',
      params.url, params.title ?? '')
    this.pageApplyFn(params)
    return true
  }
}
