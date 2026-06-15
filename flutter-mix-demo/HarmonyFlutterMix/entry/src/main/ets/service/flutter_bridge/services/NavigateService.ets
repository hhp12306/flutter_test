import { CoreUtils, WebNavigateParams } from '../../../common/core/components/utils/CoreUtils'
import { WebFlowTracer } from '../../../common/core/utils/WebFlowTracer'
import { DIWebLog, DIWebLogTag } from '../../../diweb/DIWebLog'

const CHANNEL_NAME: string = 'com.example.harmonyfluttermix/diweb'

export interface ChannelResponseResult {
  success: boolean
  code: number
  message: string
  data?: Object
}

/**
 * Flutter 导航服务（对齐公司 NavigateService.toWebview）
 */
export class NavigateService {
  private static instance: NavigateService | null = null

  static getInstance(): NavigateService {
    if (NavigateService.instance === null) {
      NavigateService.instance = new NavigateService()
    }
    return NavigateService.instance
  }

  async toWebview(_context: Context, params: Map<string, Object>): Promise<ChannelResponseResult> {
    return new Promise((resolve) => {
      const data = this.handleMapData(params)
      const appNeedLogin = Number(params.get('appNeedLogin')) || 0
      DIWebLog.infoT(DIWebLogTag.CHANNEL,
        'NavigateService.toWebview url=%{public}s scene=%{public}s useOverlay=%{public}s',
        String(data.url ?? ''), String(data.scene ?? ''), String(data.useOverlay ?? false))

      CoreUtils.needLogin(appNeedLogin, () => {
        CoreUtils.navigateToWebview(data, () => {
          resolve(this.createSuccessResponse(true))
        }, (msg: string) => {
          resolve(this.createErrorResponse('NAVIGATE_ERROR', msg))
        })
      })
    })
  }

  toWebviewFromRecord(data: WebNavigateParams,
    onSuccess?: () => void, onError?: (msg: string) => void): void {
    WebFlowTracer.step('NavigateService', `Flutter通道 scene=${data.scene ?? ''}`)
    CoreUtils.navigateToWebview(data, onSuccess, onError)
  }

  private handleMapData(params: Map<string, Object>): WebNavigateParams {
    const navParams: WebNavigateParams = {
      url: String(params.get('url') ?? ''),
      title: String(params.get('title') ?? ''),
      scene: String(params.get('scene') ?? 'community'),
      source: String(params.get('source') ?? 'Flutter社区'),
      showNavigation: params.get('showNavigation') !== false
    }
    const bridgeProfile = params.get('bridgeProfile')
    if (bridgeProfile !== undefined && bridgeProfile !== null) {
      navParams.bridgeProfile = String(bridgeProfile)
    }
    const useOverlay = params.get('useOverlay')
    if (useOverlay === true) {
      navParams.useOverlay = true
    }
    const multi = params.get('multi')
    if (multi === true) {
      navParams.multi = true
    }
    return navParams
  }

  private createSuccessResponse(data?: Object): ChannelResponseResult {
    return { success: true, code: 0, message: 'success', data: data }
  }

  private createErrorResponse(code: string, message: string): ChannelResponseResult {
    return { success: false, code: -1, message: `${code}: ${message}` }
  }

  getChannelName(): string {
    return CHANNEL_NAME
  }
}
