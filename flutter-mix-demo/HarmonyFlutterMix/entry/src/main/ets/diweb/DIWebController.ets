import { webview } from '@kit.ArkWeb'
import {
  DIWebJsBridge,
  DIWebJsBridgeConfig,
  DIWebBridgeProxy
} from './DIWebJsBridge'
import { getBridgeScriptForProfile, getBridgeScriptSizeForProfile } from './DIWebBridgeScript'
import { DIWebBridgeHandler, DIWebBridgeProfile } from './DIWebTypes'
import { DIWebLog, DIWebLogTag } from './DIWebLog'

/**
 * DIWeb 控制器：封装 WebviewController 与 JSBridge 操作
 */
export class DIWebController {
  readonly webController: webview.WebviewController = new webview.WebviewController()
  private jsBridge: DIWebJsBridge = new DIWebJsBridge()
  private bridgeProxy: DIWebBridgeProxy = this.jsBridge.createProxy()
  private bridgeInjected: boolean = false

  get bridge(): DIWebJsBridge {
    return this.jsBridge
  }

  get bridgeProxyObject(): DIWebBridgeProxy {
    return this.bridgeProxy
  }

  /** 配置 JSBridge 回调 */
  configureBridge(config: DIWebJsBridgeConfig): void {
    DIWebLog.debug('configureBridge')
    this.jsBridge.updateConfig(config)
  }

  /** 注册自定义 Bridge 方法 */
  registerHandler(method: string, handler: DIWebBridgeHandler): void {
    DIWebLog.debug('registerHandler: %{public}s', method)
    this.jsBridge.register(method, handler)
  }

  /** 预取页面资源（主资源+子资源，不执行 JS；需 Web 组件已 attach，缓存约 5 分钟） */
  prefetchPage(url: string, trigger: string = 'unknown'): boolean {
    const urlDesc = url || '(empty)'
    DIWebLog.infoT(DIWebLogTag.VIEW, 'prefetchPage trigger=%{public}s url=%{public}s',
      trigger, urlDesc)
    try {
      this.webController.prefetchPage(url)
      DIWebLog.infoT(DIWebLogTag.VIEW, 'prefetchPage called ok trigger=%{public}s url=%{public}s',
        trigger, urlDesc)
      return true
    } catch (e) {
      const err = e as Error
      DIWebLog.warnT(DIWebLogTag.VIEW, 'prefetchPage failed trigger=%{public}s url=%{public}s err=%{public}s',
        trigger, urlDesc, err.message ?? String(e))
      return false
    }
  }

  /** 加载页面，支持 http(s) 与 rawfile Resource */
  loadPage(url: string | Resource, trigger: string = 'unknown'): void {
    this.bridgeInjected = false
    const urlDesc = typeof url === 'string' ? url : '[Resource/rawfile]'
    DIWebLog.infoT(DIWebLogTag.VIEW, 'loadPage trigger=%{public}s url=%{public}s canGoBackBefore=%{public}s',
      trigger, urlDesc, String(this.canGoBack()))
    try {
      this.webController.loadUrl(url)
      DIWebLog.infoT(DIWebLogTag.VIEW, 'loadPage called ok trigger=%{public}s url=%{public}s',
        trigger, urlDesc)
    } catch (e) {
      const err = e as Error
      DIWebLog.errorT(DIWebLogTag.VIEW, 'loadPage failed trigger=%{public}s url=%{public}s err=%{public}s',
        trigger, urlDesc, err.message ?? String(e))
    }
  }

  /** Web 内后退，返回是否已处理 */
  goBack(): boolean {
    try {
      const canBack = this.webController.accessBackward()
      DIWebLog.infoT(DIWebLogTag.VIEW, 'goBack check canGoBack=%{public}s', String(canBack))
      if (canBack) {
        this.webController.backward()
        DIWebLog.infoT(DIWebLogTag.VIEW, 'goBack web backward done')
        return true
      }
    } catch (e) {
      DIWebLog.warnT(DIWebLogTag.VIEW, 'goBack failed: %{public}s', String(e))
    }
    return false
  }

  canGoBack(): boolean {
    try {
      return this.webController.accessBackward()
    } catch (_e) {
      return false
    }
  }

  getCurrentUrl(): string {
    try {
      return this.webController.getUrl()
    } catch (_e) {
      return ''
    }
  }

  isOnBlankPage(): boolean {
    const current = this.getCurrentUrl()
    return current.length === 0 || current.includes('about:blank')
  }

  reload(): void {
    DIWebLog.infoT(DIWebLogTag.VIEW, 'reload')
    try {
      this.webController.refresh()
    } catch (e) {
      DIWebLog.errorT(DIWebLogTag.VIEW, 'reload failed: %{public}s', String(e))
    }
  }

  /** Overlay 再次显示时唤醒 Web 渲染 */
  onActive(): void {
    try {
      this.webController.onActive()
      DIWebLog.infoT(DIWebLogTag.VIEW, 'onActive called ok')
    } catch (e) {
      DIWebLog.warnT(DIWebLogTag.VIEW, 'onActive failed: %{public}s', String(e))
    }
  }

  /** Overlay 隐藏时暂停 Web，避免后台占用 */
  onInactive(): void {
    try {
      this.webController.onInactive()
      DIWebLog.infoT(DIWebLogTag.VIEW, 'onInactive called ok')
    } catch (e) {
      DIWebLog.warnT(DIWebLogTag.VIEW, 'onInactive failed: %{public}s', String(e))
    }
  }

  /** 向 H5 执行 JS */
  async runJavaScript(script: string): Promise<string> {
    return await this.webController.runJavaScript(script)
  }

  /** 向 H5 派发事件 */
  async dispatchEvent(event: string, data?: Object): Promise<void> {
    const dataJson = JSON.stringify(data ?? {})
    const script =
      `window.DIWeb && window.DIWeb._dispatchEvent(${JSON.stringify(event)}, ${dataJson});`
    await this.runJavaScript(script)
  }

  /** 页面加载完成后注入 H5 Bridge 脚本，返回注入耗时（ms） */
  async injectBridgeScript(profile: DIWebBridgeProfile = 'full'): Promise<number> {
    if (this.bridgeInjected) {
      DIWebLog.warnT(DIWebLogTag.BRIDGE,
        'injectBridgeScript SKIP alreadyInjected profile=%{public}s webUrl=%{public}s',
        profile, this.getCurrentUrl() || '(empty)')
      return 0
    }
    try {
      const scriptSize = getBridgeScriptSizeForProfile(profile)
      DIWebLog.infoT(DIWebLogTag.BRIDGE,
        'injectBridgeScript START profile=%{public}s scriptSize=%{public}s webUrl=%{public}s',
        profile, String(scriptSize), this.getCurrentUrl() || '(empty)')
      const startMs = Date.now()
      await this.runJavaScript(getBridgeScriptForProfile(profile))
      const costMs = Date.now() - startMs
      this.bridgeInjected = true
      DIWebLog.infoT(DIWebLogTag.BRIDGE,
        'injectBridgeScript OK profile=%{public}s cost=%{public}s ms webUrl=%{public}s',
        profile, String(costMs), this.getCurrentUrl() || '(empty)')
      return costMs
    } catch (e) {
      DIWebLog.errorT(DIWebLogTag.BRIDGE,
        'injectBridgeScript FAIL profile=%{public}s webUrl=%{public}s err=%{public}s',
        profile, this.getCurrentUrl() || '(empty)', String(e))
      return -1
    }
  }

  resetBridgeInjected(): void {
    DIWebLog.debugT(DIWebLogTag.BRIDGE, 'resetBridgeInjected webUrl=%{public}s',
      this.getCurrentUrl() || '(empty)')
    this.bridgeInjected = false
  }
}
