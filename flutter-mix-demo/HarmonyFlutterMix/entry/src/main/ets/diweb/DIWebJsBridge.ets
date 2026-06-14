import {
  DIWebBridgeHandler,
  DIWebBridgeResponse,
  DIWebJsBridgeConfig
} from './DIWebTypes'
import { registerEnterpriseBridgeApis, DIWEB_ENTERPRISE_API_LIST } from './DIWebBridgeApis'
import { buildBridgeInjectScript } from './DIWebBridgeScript'
import { DIWebLog } from './DIWebLog'

export { DIWebJsBridgeConfig } from './DIWebTypes'
export { buildBridgeInjectScript as DIWEB_BRIDGE_INJECT_SCRIPT_BUILDER } from './DIWebBridgeScript'

/** H5 侧 Bridge 注入脚本（含大量 JSAPI 包装，用于压测注入耗时） */
export const DIWEB_BRIDGE_INJECT_SCRIPT: string = buildBridgeInjectScript()

/**
 * 注入到 Web 的 JSBridge 代理对象，供 javaScriptProxy 注册
 */
export class DIWebBridgeProxy {
  private bridge: DIWebJsBridge

  constructor(bridge: DIWebJsBridge) {
    this.bridge = bridge
  }

  call(method: string, paramsJson: string): string {
    return this.bridge.handleCall(method, paramsJson)
  }

  callAsync(method: string, paramsJson: string): Promise<string> {
    return this.bridge.handleCallAsync(method, paramsJson)
  }
}

/**
 * DIWeb JSBridge 核心：管理内置方法与自定义方法分发
 */
export class DIWebJsBridge {
  private handlers: Map<string, DIWebBridgeHandler> = new Map()
  private config: DIWebJsBridgeConfig = {}

  constructor(config?: DIWebJsBridgeConfig) {
    if (config) {
      this.config = config
    }
    this.registerBuiltinHandlers()
  }

  updateConfig(config: DIWebJsBridgeConfig): void {
    this.config = config
  }

  /** 注册自定义 Bridge 方法 */
  register(method: string, handler: DIWebBridgeHandler): void {
    this.handlers.set(method, handler)
  }

  unregister(method: string): void {
    this.handlers.delete(method)
  }

  createProxy(): DIWebBridgeProxy {
    return new DIWebBridgeProxy(this)
  }

  handleCall(method: string, paramsJson: string): string {
    DIWebLog.debug('Bridge call sync: method=%{public}s, params=%{public}s', method, paramsJson)
    try {
      const params = this.parseParams(paramsJson)
      const result = this.dispatchSync(method, params)
      return JSON.stringify(this.success(result))
    } catch (err) {
      return JSON.stringify(this.fail(err))
    }
  }

  async handleCallAsync(method: string, paramsJson: string): Promise<string> {
    try {
      const params = this.parseParams(paramsJson)
      const result = await this.dispatchAsync(method, params)
      return JSON.stringify(this.success(result))
    } catch (err) {
      return JSON.stringify(this.fail(err))
    }
  }

  private registerBuiltinHandlers(): void {
    registerEnterpriseBridgeApis(this, this.config)
    DIWebLog.info('Bridge registered %{public}s APIs', String(DIWEB_ENTERPRISE_API_LIST.length))
  }

  private parseParams(paramsJson: string): Record<string, Object> {
    if (!paramsJson || paramsJson.length === 0) {
      return {}
    }
    try {
      return JSON.parse(paramsJson) as Record<string, Object>
    } catch (_e) {
      return {}
    }
  }

  private dispatchSync(method: string, params: Record<string, Object>): Object {
    const handler = this.handlers.get(method)
    if (!handler) {
      throw new Error(`Bridge method not found: ${method}`)
    }
    const result = handler(params)
    if (result instanceof Promise) {
      throw new Error(`Method "${method}" is async, use callAsync instead`)
    }
    return result
  }

  private async dispatchAsync(method: string, params: Record<string, Object>): Promise<Object> {
    const handler = this.handlers.get(method)
    if (!handler) {
      throw new Error(`Bridge method not found: ${method}`)
    }
    return await handler(params)
  }

  private success(data?: Object): DIWebBridgeResponse {
    return { code: 0, message: 'success', data: data }
  }

  private fail(err: Object): DIWebBridgeResponse {
    const message = err instanceof Error ? err.message : JSON.stringify(err)
    return { code: -1, message: message }
  }
}
