/** 本地 H5 页面 rawfile 路径常量 */
export class DIWebH5Path {
  static readonly DEMO: string = 'diweb/demo.html'
  static readonly MALL_DETAIL: string = 'diweb/mall/detail.html'
  static readonly CAR_DETAIL: string = 'diweb/car/detail.html'
  static readonly SERVICE_DETAIL: string = 'diweb/service/detail.html'
  static readonly MINE_PROFILE: string = 'diweb/mine/profile.html'
}

/**
 * 将 rawfile 相对路径转为 Resource（$rawfile 需编译期字面量）
 */
export function resolveRawfile(path: string): Resource {
  switch (path) {
    case DIWebH5Path.DEMO:
      return $rawfile('diweb/demo.html')
    case DIWebH5Path.MALL_DETAIL:
      return $rawfile('diweb/mall/detail.html')
    case DIWebH5Path.CAR_DETAIL:
      return $rawfile('diweb/car/detail.html')
    case DIWebH5Path.SERVICE_DETAIL:
      return $rawfile('diweb/service/detail.html')
    case DIWebH5Path.MINE_PROFILE:
      return $rawfile('diweb/mine/profile.html')
    default:
      return $rawfile('diweb/demo.html')
  }
}

/** 规范化 rawfile 路径 */
export function normalizeRawfilePath(url: string): string {
  if (url.startsWith('resource://rawfile/')) {
    return url.substring('resource://rawfile/'.length)
  }
  if (url.startsWith('rawfile://')) {
    return url.substring('rawfile://'.length)
  }
  return url
}
