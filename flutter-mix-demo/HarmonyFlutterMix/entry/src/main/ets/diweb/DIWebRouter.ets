import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { DIWebPageOptions, DIWebBridgeProfile } from './DIWebTypes'
import { DIWebLog, DIWebLogTag, DIWebNavTrace } from './DIWebLog'
import { DIWebLoadMonitor } from './DIWebLoadMonitor'
import { DIWebSession } from './DIWebSession'

/** DIWeb 页面路由参数 */
export interface DIWebRouteParams {
  url: string
  title?: string
  showNavBar?: boolean
  showProgress?: boolean
  bridgeProfile?: DIWebBridgeProfile
}

/**
 * DIWeb 路由工具：统一打开 H5 二级页面
 */
export class DIWebRouter {
  private static readonly PAGE_PATH: string = 'pages/DIWebPage'

  /** 打开 H5 页面 */
  static open(url: string, options?: DIWebPageOptions): void {
    const session = DIWebSession.getInstance()
    const navId = DIWebNavTrace.begin('open',
      `url=${url} source=${options?.source ?? '未知'} title=${options?.title ?? ''}`)
    const useOverlay = options?.useOverlay !== false
    DIWebNavTrace.step(navId, 'state',
      `useOverlay=${String(useOverlay)} overlayHostReady=${String(session.isOverlayHostReady())}` +
      ` overlayVisible=${String(session.isOverlayVisible())} pageActive=${String(session.isPageActive())}` +
      ` webCanGoBack=${String(session.getSharedController().canGoBack())}`)
    const title = options?.title ?? ''
    const bridgeProfile: DIWebBridgeProfile = options?.bridgeProfile ?? 'full'
    const loadMode = DIWebRouter.resolveLoadMode(url, title, session)
    const prewarmAgeMs = session.isPrewarmed() ? (Date.now() - session.getPrewarmTime()) : -1
    DIWebLog.infoT(DIWebLogTag.ROUTER,
      'open url=%{public}s source=%{public}s bridge=%{public}s useOverlay=%{public}s loadMode=%{public}s prewarm=%{public}s prewarmSource=%{public}s prewarmAgeMs=%{public}s',
      url, options?.source ?? '未知', bridgeProfile, String(useOverlay), loadMode,
      String(session.isPrewarmed()), session.getPrewarmSource() || '-', String(prewarmAgeMs))
    DIWebLog.infoT(DIWebLogTag.ROUTER, 'open sessionSnapshot %{public}s', session.getDiagnosticSummary())
    DIWebLoadMonitor.markClick(url, title, options?.source ?? '未知', loadMode, bridgeProfile,
      session.isPrewarmed())
    const params: DIWebRouteParams = {
      url: url,
      title: title,
      showNavBar: options?.showNavBar ?? true,
      showProgress: options?.showProgress ?? true,
      bridgeProfile: bridgeProfile
    }
    session.setCurrentBridgeProfile(bridgeProfile)
    if (useOverlay && session.openInOverlay(params, navId)) {
      DIWebNavTrace.end(navId, 'handled_by_overlay')
      return
    }
    if (session.tryNavigate(params, navId)) {
      DIWebNavTrace.end(navId, 'handled_by_active_page')
      return
    }
    DIWebNavTrace.step(navId, 'router.pushUrl', DIWebRouter.PAGE_PATH)
    DIWebLog.infoT(DIWebLogTag.ROUTER, 'fallback pushUrl path=%{public}s', DIWebRouter.PAGE_PATH)
    router.pushUrl({ url: DIWebRouter.PAGE_PATH, params: params })
      .then(() => {
        DIWebNavTrace.end(navId, 'pushUrl_success')
        DIWebLog.infoT(DIWebLogTag.ROUTER, 'pushUrl success')
      })
      .catch((err: Error) => {
        DIWebNavTrace.end(navId, `pushUrl_failed:${err.message ?? String(err)}`)
        DIWebLog.errorT(DIWebLogTag.ROUTER, 'pushUrl failed: %{public}s', err.message ?? String(err))
        promptAction.showToast({ message: `页面打开失败: ${err.message}`, duration: 3000 })
      })
  }

  /** 关闭当前 H5 页面（优先隐藏 Overlay，否则 router.back） */
  static back(): void {
    const session = DIWebSession.getInstance()
    const navId = DIWebNavTrace.begin('back',
      `overlayVisible=${String(session.isOverlayVisible())} webCanGoBack=${String(session.getSharedController().canGoBack())}`)
    if (session.closeOverlay(navId)) {
      DIWebNavTrace.end(navId, 'overlay_closed')
      return
    }
    DIWebNavTrace.step(navId, 'router.back', '')
    DIWebLog.infoT(DIWebLogTag.ROUTER, 'fallback router.back')
    router.back()
    DIWebNavTrace.end(navId, 'router_back_called')
  }

  /** 替换当前页面为 H5 页面 */
  static replace(url: string, options?: DIWebPageOptions): void {
    const session = DIWebSession.getInstance()
    const navId = DIWebNavTrace.begin('replace', `url=${url}`)
    const params: DIWebRouteParams = {
      url: url,
      title: options?.title ?? '',
      showNavBar: options?.showNavBar ?? true,
      showProgress: options?.showProgress ?? true,
      bridgeProfile: options?.bridgeProfile ?? 'full'
    }
    const useOverlay = options?.useOverlay !== false
    if (useOverlay && session.openInOverlay(params, navId)) {
      DIWebNavTrace.end(navId, 'handled_by_overlay')
      return
    }
    if (session.tryNavigate(params, navId)) {
      DIWebNavTrace.end(navId, 'handled_by_active_page')
      return
    }
    DIWebNavTrace.step(navId, 'router.replaceUrl', DIWebRouter.PAGE_PATH)
    router.replaceUrl({ url: DIWebRouter.PAGE_PATH, params: params })
      .catch((err: Error) => {
        DIWebNavTrace.end(navId, `replace_failed:${err.message ?? String(err)}`)
        DIWebLog.errorT(DIWebLogTag.ROUTER, 'replace failed: %{public}s', err.message ?? String(err))
      })
  }

  private static resolveLoadMode(url: string, title: string, session: DIWebSession): string {
    const lastUrl = session.getLastOverlayUrl()
    if (lastUrl.length === 0) {
      return '首次加载'
    }
    if (url === lastUrl) {
      return title === session.getLastOverlayTitle() ? '缓存秒开' : '同URL重载'
    }
    return '切换加载'
  }
}
