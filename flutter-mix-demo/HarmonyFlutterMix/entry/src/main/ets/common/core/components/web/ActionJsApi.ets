import { DIWebController } from '../../../../diweb/DIWebController'
import { DIWebLog, DIWebLogTag } from '../../../../diweb/DIWebLog'
import { BridgeProfile, BridgeConfig } from './BridgeProfile'

/** ActionJsApi 动态方法（模拟公司 action 代理） */
export const ActionJsMethodList: string[] = [
  'trackEvent', 'share', 'openCamera', 'chooseImage'
]

export const UserActionJsMethodList: string[] = [
  'reportClick', 'reportExposure'
]

/**
 * 用户行为 Bridge（对齐公司 ActionJsApi，第二路 javaScriptProxy）
 */
export class ActionJsApi {
  private controller: DIWebController | null = null
  private profile: BridgeProfile = BridgeProfile.FULL

  init(context: Context, controller: DIWebController, profile: BridgeProfile = BridgeProfile.FULL): void {
    this.controller = controller
    this.profile = profile
    const baseMethods = [...ActionJsMethodList, ...UserActionJsMethodList]
    const profileMethods = BridgeConfig.getMethods(profile)
    DIWebLog.infoT(DIWebLogTag.BRIDGE,
      'ActionJsApi.init profile=%{public}s actionMethods=%{public}s profileMethods=%{public}s',
      profile, String(baseMethods.length), String(profileMethods.length))
  }

  getMethodList(profile: BridgeProfile): string[] {
    if (profile === BridgeProfile.FULL) {
      return [...ActionJsMethodList, ...UserActionJsMethodList]
    }
    return ActionJsMethodList
  }

  registerToController(controller: DIWebController, profile: BridgeProfile): void {
    this.controller = controller
    const methods = this.getMethodList(profile)
    DIWebLog.infoT(DIWebLogTag.BRIDGE,
      'ActionJsApi.registerJavaScriptProxy name=action methods=%{public}s', String(methods.length))
  }
}
