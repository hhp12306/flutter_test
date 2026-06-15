import { DIWebBridgeProfile } from '../../../../diweb/DIWebTypes'
import { DIWEB_COMMUNITY_API_LIST } from '../../../../diweb/DIWebBridgeScript'
import { DIWEB_ENTERPRISE_API_LIST } from '../../../../diweb/DIWebBridgeApis'

/** Bridge 注入分档（对齐公司 BridgeProfile） */
export enum BridgeProfile {
  COMMUNITY = 'community',
  MALL = 'mall',
  SERVICE = 'service',
  FULL = 'full'
}

const MALL_API_LIST: string[] = [
  'getAppInfo', 'close', 'setTitle', 'toast',
  'showLoading', 'hideLoading', 'scanCode', 'getLocation'
]

const SERVICE_API_LIST: string[] = [
  'getAppInfo', 'close', 'setTitle', 'toast',
  'showLoading', 'hideLoading', 'getLocation', 'openMap', 'callPhone'
]

/**
 * Bridge 配置管理（按业务场景分档注入）
 */
export class BridgeConfig {
  static getMethods(profile: BridgeProfile): string[] {
    switch (profile) {
      case BridgeProfile.COMMUNITY:
        return DIWEB_COMMUNITY_API_LIST
      case BridgeProfile.MALL:
        return MALL_API_LIST
      case BridgeProfile.SERVICE:
        return SERVICE_API_LIST
      case BridgeProfile.FULL:
        return DIWEB_ENTERPRISE_API_LIST
      default:
        return DIWEB_ENTERPRISE_API_LIST
    }
  }

  static getScriptSizeEstimate(profile: BridgeProfile): number {
    const baseSize = 100
    const methodSize = 50
    return baseSize + BridgeConfig.getMethods(profile).length * methodSize
  }

  static profileForScene(scene: string): BridgeProfile {
    if (scene === 'mall' || scene === '商城') {
      return BridgeProfile.MALL
    }
    if (scene === 'service' || scene === '服务') {
      return BridgeProfile.SERVICE
    }
    if (scene === 'community' || scene === 'Flutter社区') {
      return BridgeProfile.COMMUNITY
    }
    return BridgeProfile.FULL
  }

  static toDIWebProfile(profile: BridgeProfile): DIWebBridgeProfile {
    if (profile === BridgeProfile.FULL) {
      return 'full'
    }
    return 'community'
  }

  static parse(value: string | undefined, fallback: BridgeProfile = BridgeProfile.FULL): BridgeProfile {
    if (value === BridgeProfile.COMMUNITY || value === 'community') {
      return BridgeProfile.COMMUNITY
    }
    if (value === BridgeProfile.MALL || value === 'mall') {
      return BridgeProfile.MALL
    }
    if (value === BridgeProfile.SERVICE || value === 'service') {
      return BridgeProfile.SERVICE
    }
    if (value === BridgeProfile.FULL || value === 'full') {
      return BridgeProfile.FULL
    }
    return fallback
  }
}
