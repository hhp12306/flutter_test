import router from '@ohos.router'
import { DiNavigation, CommonBuilderName, RouterType } from './DiNavigation'
import { RouterKeys } from './RouterKeys'
import { BridgeProfile, BridgeConfig } from '../components/web/BridgeProfile'
import { DIWebSession } from '../../../diweb/DIWebSession'
import { DIWebLoadMonitor } from '../../../diweb/DIWebLoadMonitor'
import { DIWebLog, DIWebLogTag, DIWebNavTrace } from '../../../diweb/DIWebLog'
import { DIWebRouteParams } from '../../../diweb/DIWebRouter'
import { WebViewPool } from '../components/web/WebViewPool'
import { WebFlowTracer } from '../utils/WebFlowTracer'

/** WebPageBridge 路由入参（对齐公司 WebBridgeOptions） */
export interface WebBridgeOptions {
  url: string
  title?: string
  showTitle?: boolean
  showProgress?: boolean
  scene?: string
  source?: string
  bridgeProfile?: BridgeProfile
  multi?: boolean
  /** false=公司路由模式(默认); true=Demo Overlay 优化模式 */
  useOverlay?: boolean
  needEncodeParams?: boolean
  routeType?: RouterType
}

/**
 * 路由管理（对齐公司 RouterManager）
 */
export class RouterManager {
  static routerToWebPageBridge(options: WebBridgeOptions): void {
    const session = DIWebSession.getInstance()
    const navId = DIWebNavTrace.begin('routerToWebPageBridge',
      `url=${options.url} scene=${options.scene ?? ''} useOverlay=${String(options.useOverlay ?? false)}`)
    const useOverlay = options.useOverlay === true
    const bridgeProfile = options.bridgeProfile ??
      BridgeConfig.profileForScene(options.scene ?? options.source ?? '')
    const diProfile = BridgeConfig.toDIWebProfile(bridgeProfile)

    DIWebNavTrace.step(navId, 'state',
      `useOverlay=${String(useOverlay)} overlayReady=${String(session.isOverlayHostReady())}` +
      ` bridge=${bridgeProfile} multi=${String(options.multi ?? false)}`)

    if (useOverlay) {
      WebFlowTracer.step('RouterManager', 'branch=Overlay')
      RouterManager.openOverlay(options, bridgeProfile, diProfile, navId)
      return
    }

    WebFlowTracer.step('RouterManager', `branch=WebPageBridge push bridge=${bridgeProfile} pool=${String(WebViewPool.getInstance().getPoolSize())}`)

    const loadMode = '路由加载'
    DIWebLoadMonitor.markClick(options.url, options.title ?? '', options.source ?? '未知',
      loadMode, diProfile, WebViewPool.getInstance().getPoolSize() > 0)
    session.setCurrentBridgeProfile(diProfile)

    const params: Record<string, Object> = {}
    params[RouterKeys.URL] = options.url
    params[RouterKeys.TITLE] = options.title ?? ''
    params[RouterKeys.SHOW_TITLE] = options.showTitle ?? true
    params[RouterKeys.SHOW_PROGRESS] = options.showProgress ?? true
    params[RouterKeys.SCENE] = options.scene ?? ''
    params[RouterKeys.SOURCE] = options.source ?? ''
    params[RouterKeys.BRIDGE_PROFILE] = String(bridgeProfile)
    params[RouterKeys.MULTI] = options.multi ?? false
    params[RouterKeys.NEED_ENCODE_PARAMS] = options.needEncodeParams ?? true

    DIWebLog.infoT(DIWebLogTag.ROUTER,
      'routerToWebPageBridge PUSH url=%{public}s bridge=%{public}s source=%{public}s',
      options.url, bridgeProfile, options.source ?? '')

    DiNavigation.getInstance()
      .build(CommonBuilderName.WEB_BRIDGE)
      .withRouterType(options.routeType ?? RouterType.PUSH_PATH)
      .withParams(params)
      .navigation()

    DIWebNavTrace.end(navId, 'pushUrl_dispatched')
  }

  private static openOverlay(options: WebBridgeOptions, bridgeProfile: BridgeProfile,
    diProfile: 'community' | 'full', navId: number): void {
    const session = DIWebSession.getInstance()
    const params: DIWebRouteParams = {
      url: options.url,
      title: options.title ?? '',
      showNavBar: options.showTitle ?? true,
      showProgress: options.showProgress ?? true,
      bridgeProfile: diProfile
    }
    const loadMode = session.getLastOverlayUrl().length === 0 ? '首次加载' : '切换加载'
    DIWebLoadMonitor.markClick(options.url, options.title ?? '', options.source ?? 'Overlay',
      loadMode, diProfile, session.isPrewarmed())
    session.setCurrentBridgeProfile(diProfile)
    if (session.openInOverlay(params, navId)) {
      WebFlowTracer.step('RouterManager', 'Overlay openInOverlay OK')
      WebFlowTracer.end('Overlay visible')
      DIWebNavTrace.end(navId, 'handled_by_overlay')
      return
    }
    DIWebLog.warnT(DIWebLogTag.ROUTER, 'openOverlay failed, fallback push WebPageBridge')
    options.useOverlay = false
    RouterManager.routerToWebPageBridge(options)
  }

  static back(): void {
    const session = DIWebSession.getInstance()
    const navId = DIWebNavTrace.begin('back',
      `overlayVisible=${String(session.isOverlayVisible())}`)
    if (session.closeOverlay(navId)) {
      DIWebNavTrace.end(navId, 'overlay_closed')
      return
    }
    DIWebNavTrace.step(navId, 'router.back', '')
    router.back()
    DIWebNavTrace.end(navId, 'router_back')
  }
}
