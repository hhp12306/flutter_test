import { DIWebController } from '../../../../diweb/DIWebController'
import { DIWebJsBridgeConfig } from '../../../../diweb/DIWebTypes'
import { DIWebLog, DIWebLogTag } from '../../../../diweb/DIWebLog'
import { BridgeProfile, BridgeConfig } from './BridgeProfile'

const BRIDGE_NAME: string = 'EnterpriseBridge'

/**
 * 主 Bridge API 注入（对齐公司 JsBridgeApi，每页新建实例）
 */
export class JsBridgeApi {
  private controller: DIWebController | null = null
  private profile: BridgeProfile = BridgeProfile.FULL

  init(context: Context, controller: DIWebController,
    config?: DIWebJsBridgeConfig, profile: BridgeProfile = BridgeProfile.FULL): void {
    this.controller = controller
    this.profile = profile
    const methods = BridgeConfig.getMethods(profile)
    controller.configureBridge(config ?? {})
    DIWebLog.infoT(DIWebLogTag.BRIDGE,
      'JsBridgeApi.init profile=%{public}s methods=%{public}s bridgeName=%{public}s',
      profile, String(methods.length), BRIDGE_NAME)
  }

  getBridgeName(): string {
    return BRIDGE_NAME
  }

  getProfile(): BridgeProfile {
    return this.profile
  }

  addJsApiObj(controller: DIWebController, bridgeName: string = BRIDGE_NAME): void {
    DIWebLog.infoT(DIWebLogTag.BRIDGE,
      'JsBridgeApi.addJsApiObj name=%{public}s profile=%{public}s', bridgeName, this.profile)
    this.controller = controller
  }
}
