/**
 * DIWeb 公共类型定义
 */

/** JSBridge 方法处理器，params 为 H5 传入的 JSON 对象 */
export type DIWebBridgeHandler = (params: Record<string, Object>) => Object | Promise<Object>

/** Bridge 注入档位：community=社区精简，full=全量压测 */
export type DIWebBridgeProfile = 'community' | 'full'

/** DIWeb 页面打开参数 */
export interface DIWebPageOptions {
  /** 页面标题，为空时取 H5 document.title */
  title?: string
  /** 是否显示顶部导航栏，默认 true */
  showNavBar?: boolean
  /** 是否显示加载进度条，默认 true */
  showProgress?: boolean
  /** 调用来源，用于 Web 加载监控 */
  source?: string
  /** 是否使用 Index 常驻 Overlay，默认 true；独立测试页请设 false */
  useOverlay?: boolean
  /** Bridge 注入档位，社区 H5 建议 community */
  bridgeProfile?: DIWebBridgeProfile
}
export interface DIWebOptions {
  /** 是否允许 JS 执行，默认 true */
  javaScriptAccess?: boolean
  /** 是否允许 DOM 存储，默认 true */
  domStorageAccess?: boolean
  /** 是否显示加载进度条，默认 true */
  showProgress?: boolean
}

/** JSBridge 统一响应结构 */
export interface DIWebBridgeResponse {
  code: number
  message: string
  data?: Object
}

/** JSBridge 运行时配置 */
export interface DIWebJsBridgeConfig {
  onTitleChange?: (title: string) => void
  onClose?: () => void
}

/** 内置 Bridge 方法名（保留常用别名） */
export class DIWebBridgeMethod {
  static readonly GET_APP_INFO: string = 'getAppInfo'
  static readonly CLOSE: string = 'close'
  static readonly SET_TITLE: string = 'setTitle'
  static readonly TOAST: string = 'toast'
}

/** 本地 Demo 页 rawfile 路径（配合 $rawfile / loadUrl 使用） */
export const DIWEB_LOCAL_DEMO_URL: string = 'diweb/demo.html'
