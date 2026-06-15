import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { DIWebPageOptions, DIWebBridgeProfile } from './DIWebTypes'
import { DIWebLog, DIWebLogTag, DIWebNavTrace } from './DIWebLog'
import { DIWebSession } from './DIWebSession'
import { RouterManager, WebBridgeOptions } from '../common/core/router/RouterManager'
import { BridgeConfig, BridgeProfile } from '../common/core/components/web/BridgeProfile'
import { RouterType } from '../common/core/router/DiNavigation'
import { WebFlowTracer } from '../common/core/utils/WebFlowTracer'

/** DIWeb 页面路由参数（Overlay / 兼容） */
export interface DIWebRouteParams {
  url: string
  title?: string
  showNavBar?: boolean
  showProgress?: boolean
  bridgeProfile?: DIWebBridgeProfile
}

/**
 * DIWeb 路由门面：默认走公司路由链 RouterManager → WebPageBridge
 * useOverlay=true 时走 Overlay 优化路径
 */
export class DIWebRouter {
  private static readonly PAGE_PATH: string = 'pages/DIWebPage'

  static open(url: string, options?: DIWebPageOptions): void {
    WebFlowTracer.begin(`openH5 url=${url}`)
    const bridgeProfile = DIWebRouter.resolveBridgeProfile(options)
    const webOptions: WebBridgeOptions = {
      url: url,
      title: options?.title ?? '',
      showTitle: options?.showNavBar ?? true,
      showProgress: options?.showProgress ?? true,
      source: options?.source ?? '未知',
      scene: options?.source ?? '',
      bridgeProfile: bridgeProfile,
      useOverlay: options?.useOverlay === true,
      routeType: RouterType.PUSH_PATH
    }
    DIWebLog.infoT(DIWebLogTag.ROUTER,
      'DIWebRouter.open -> RouterManager url=%{public}s useOverlay=%{public}s bridge=%{public}s',
      url, String(webOptions.useOverlay), bridgeProfile)
    RouterManager.routerToWebPageBridge(webOptions)
  }

  static back(): void {
    RouterManager.back()
  }

  static replace(url: string, options?: DIWebPageOptions): void {
    const bridgeProfile = DIWebRouter.resolveBridgeProfile(options)
    RouterManager.routerToWebPageBridge({
      url: url,
      title: options?.title ?? '',
      showTitle: options?.showNavBar ?? true,
      showProgress: options?.showProgress ?? true,
      source: options?.source ?? '未知',
      bridgeProfile: bridgeProfile,
      useOverlay: options?.useOverlay === true,
      routeType: RouterType.REPLACE
    })
  }

  /** @deprecated 独立页 fallback，请使用 WebPageBridge */
  static pushLegacyPage(params: DIWebRouteParams): void {
    const navId = DIWebNavTrace.begin('pushLegacy', params.url)
    router.pushUrl({ url: 'pages/DIWebPage', params: params })
      .then(() => DIWebNavTrace.end(navId, 'legacy_push_ok'))
      .catch((err: Error) => {
        DIWebNavTrace.end(navId, `legacy_push_fail:${err.message}`)
        promptAction.showToast({ message: `页面打开失败: ${err.message}`, duration: 3000 })
      })
  }

  private static resolveBridgeProfile(options?: DIWebPageOptions): BridgeProfile {
    if (options?.bridgeProfile === 'full') {
      return BridgeProfile.FULL
    }
    if (options?.bridgeProfile === 'community') {
      return BridgeProfile.COMMUNITY
    }
    return BridgeConfig.profileForScene(options?.source ?? '')
  }
}
