import promptAction from '@ohos.promptAction'
import { RouterManager, WebBridgeOptions } from '../../router/RouterManager'
import { BridgeConfig, BridgeProfile } from '../web/BridgeProfile'
import { DIWebLog, DIWebLogTag } from '../../../../diweb/DIWebLog'
import { WebFlowTracer } from '../../utils/WebFlowTracer'

/** CoreUtils.navigateToWebview 入参 */
export interface WebNavigateParams {
  url: string
  title?: string
  source?: string
  scene?: string
  bridgeProfile?: string
  useOverlay?: boolean
  multi?: boolean
  showNavigation?: boolean
}

/**
 * URL 参数解析（模拟公司 CommonUtil.getUrlParams）
 */
function getUrlParams(url: string): Record<string, string> {
  const result: Record<string, string> = {}
  const queryIndex = url.indexOf('?')
  if (queryIndex < 0) {
    return result
  }
  const query = url.substring(queryIndex + 1)
  const pairs = query.split('&')
  pairs.forEach((pair: string) => {
    const eq = pair.indexOf('=')
    if (eq > 0) {
      const key = decodeURIComponent(pair.substring(0, eq))
      const value = decodeURIComponent(pair.substring(eq + 1))
      result[key] = value
    }
  })
  return result
}

/**
 * 场景路由工具（对齐公司 CoreUtils.navigateToWebview）
 */
export class CoreUtils {
  static navigateToWebview(
    data: WebNavigateParams,
    onSuccess?: () => void,
    onError?: (msg: string) => void
  ): void {
    WebFlowTracer.begin(`openH5 url=${data.url}`)
    const url: string = data.url ?? ''
    const title: string = data.title ?? ''
    const scene: string = data.scene ?? ''
    const showNavigation: boolean = data.showNavigation !== false
    const useOverlay: boolean = data.useOverlay === true
    const multi: boolean = data.multi === true
    const fallbackProfile: BridgeProfile = BridgeConfig.profileForScene(scene || (data.source ?? ''))
    const bridgeProfile: BridgeProfile = BridgeConfig.parse(data.bridgeProfile ?? '', fallbackProfile)

    if (url.length === 0) {
      onError?.('url is required')
      return
    }

    let decodedUrl: string = url
    try {
      decodedUrl = decodeURIComponent(url).replace(/&amp;/g, '&')
    } catch (_e) {
      decodedUrl = url
    }

    const urlParams = getUrlParams(decodedUrl)
    const flag = urlParams['flag'] ?? ''

    DIWebLog.infoT(DIWebLogTag.ROUTER,
      'CoreUtils.navigateToWebview url=%{public}s scene=%{public}s flag=%{public}s useOverlay=%{public}s',
      decodedUrl, scene, flag, String(useOverlay))

    WebFlowTracer.step('CoreUtils', `flag=${flag || '-'} bridge=${bridgeProfile} overlay=${String(useOverlay)}`)

    if (flag === 'invite' || flag === 'recommendationOfficer') {
      promptAction.showToast({ message: '邀请有礼场景(模拟，不走 WebPageBridge)', duration: 2000 })
      onSuccess?.()
      return
    }

    if (urlParams['forApp'] === 'generateCode') {
      promptAction.showToast({ message: '网联商城特殊场景(模拟)', duration: 2000 })
      onSuccess?.()
      return
    }

    if (flag === 'officer') {
      promptAction.showToast({ message: '腾势共创官场景(模拟)', duration: 2000 })
      onSuccess?.()
      return
    }

    const options: WebBridgeOptions = {
      url: decodedUrl,
      title: title,
      showTitle: showNavigation,
      scene: scene,
      source: data.source ?? scene,
      bridgeProfile: bridgeProfile,
      multi: multi,
      useOverlay: useOverlay,
      showProgress: true
    }

    try {
      RouterManager.routerToWebPageBridge(options)
      onSuccess?.()
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e)
      DIWebLog.errorT(DIWebLogTag.ROUTER, 'CoreUtils.navigateToWebview failed: %{public}s', msg)
      onError?.(msg)
    }
  }

  static needLogin(appNeedLogin: number, callback: () => void): void {
    if (appNeedLogin === 1) {
      DIWebLog.infoT(DIWebLogTag.ROUTER, 'CoreUtils.needLogin check (mock pass)')
    }
    callback()
  }
}
