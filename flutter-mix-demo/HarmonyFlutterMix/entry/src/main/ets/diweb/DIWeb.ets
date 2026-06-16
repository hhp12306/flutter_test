import { DIWebController } from './DIWebController'
import { DIWEB_LOCAL_DEMO_URL, DIWebBridgeProfile } from './DIWebTypes'
import { DIWebLog, DIWebLogTag } from './DIWebLog'
import { DIWebLoadMonitor } from './DIWebLoadMonitor'
import { normalizeRawfilePath, resolveRawfile } from './DIWebRawfile'
import { DIWebSession } from './DIWebSession'
import { WebEnginePrewarm } from './WebEnginePrewarm'

/** Web 占位 src：避免默认 demo.html 写入历史栈导致返回多一层 */
const DIWEB_BLANK_SRC: string = 'about:blank'

function isBlankPageUrl(url: string): boolean {
  return url.length === 0 || url.includes('about:blank')
}

/**
 * DIWeb 组件：封装 HarmonyOS Web 组件，内置 JSBridge
 */
@Component
export struct DIWeb {
  @Prop @Watch('onUrlChanged') url: string = DIWEB_LOCAL_DEMO_URL
  @Prop showProgress: boolean = true
  @Prop useSharedController: boolean = true
  @Prop externalController: DIWebController | null = null
  @Prop @Watch('onHostVisibleChanged') hostVisible: boolean = true
  @Prop @Watch('onForceReloadTickChanged') forceReloadTick: number = 0
  @Prop bridgeProfile: DIWebBridgeProfile = 'full'
  @Prop javaScriptAccess: boolean = true
  @Prop domStorageAccess: boolean = true
  onControllerReady?: (controller: DIWebController) => void
  onTitleChange?: (title: string) => void
  onPageBegin?: (url: string) => void
  onPageEnd?: (url: string) => void
  onError?: (description: string) => void

  @State private progress: number = 0
  @State private isLoading: boolean = true
  @State private errorMessage: string = ''
  private ownedController: DIWebController = new DIWebController()
  private webCtrl: DIWebController = this.ownedController
  private loadedUrl: string = ''
  private controllerReady: boolean = false
  private pendingLoadTrigger: string = ''
  /** about:blank 占位页是否已完成（用于 attach 与 blank 完成竞态） */
  private blankPlaceholderDone: boolean = false
  /** 目标 URL 是否已成功 onPageEnd */
  private targetPageLoaded: boolean = false

  aboutToAppear(): void {
    if (this.externalController !== null) {
      this.webCtrl = this.externalController
    } else {
      this.webCtrl = this.useSharedController
        ? DIWebSession.getInstance().getSharedController()
        : this.ownedController
    }
    DIWebLog.infoT(DIWebLogTag.VIEW,
      'aboutToAppear url=%{public}s bridge=%{public}s shared=%{public}s loadedUrl=%{public}s',
      this.url || '(empty)', this.bridgeProfile, String(this.useSharedController), this.loadedUrl || '(empty)')
    this.webCtrl.configureBridge({
      onTitleChange: (title: string) => {
        DIWebLog.debug('onTitleChange: %{public}s', title)
        if (this.onTitleChange) {
          this.onTitleChange(title)
        }
      }
    })
    if (this.onControllerReady) {
      this.onControllerReady(this.webCtrl)
    }
  }

  onUrlChanged(): void {
    DIWebLog.infoT(DIWebLogTag.VIEW, 'onUrlChanged url=%{public}s ready=%{public}s loadedUrl=%{public}s hostVisible=%{public}s',
      this.url || '(empty)', String(this.controllerReady), this.loadedUrl || '(empty)', String(this.hostVisible))
    if (this.controllerReady) {
      this.targetPageLoaded = false
      this.blankPlaceholderDone = false
      this.loadedUrl = ''
      this.isLoading = true
      this.loadTargetUrl(this.url, 'onUrlChanged')
    }
  }

  onHostVisibleChanged(): void {
    DIWebLog.infoT(DIWebLogTag.VIEW,
      'onHostVisibleChanged hostVisible=%{public}s url=%{public}s loadedUrl=%{public}s isLoading=%{public}s ready=%{public}s',
      String(this.hostVisible), this.url || '(empty)', this.loadedUrl || '(empty)',
      String(this.isLoading), String(this.controllerReady))
    if (this.hostVisible) {
      this.ensureDisplayReady('hostVisible=true')
    } else {
      this.webCtrl.onInactive()
    }
  }

  onForceReloadTickChanged(): void {
    if (this.forceReloadTick <= 0 || !this.controllerReady) {
      return
    }
    DIWebLog.infoT(DIWebLogTag.VIEW,
      'onForceReloadTickChanged tick=%{public}d url=%{public}s loadedUrl=%{public}s',
      String(this.forceReloadTick), this.url || '(empty)', this.loadedUrl || '(empty)')
    this.targetPageLoaded = false
    this.blankPlaceholderDone = false
    this.loadedUrl = ''
    this.isLoading = true
    this.loadTargetUrl(this.url, 'forceReload')
  }

  /** Overlay 再次显示：唤醒 Web；若实际停在 about:blank 则强制重载 */
  private ensureDisplayReady(trigger: string): void {
    const webUrl = this.webCtrl.getCurrentUrl()
    DIWebLog.infoT(DIWebLogTag.VIEW,
      'ensureDisplayReady trigger=%{public}s loadedUrl=%{public}s webUrl=%{public}s isLoading=%{public}s',
      trigger, this.loadedUrl || '(empty)', webUrl || '(empty)', String(this.isLoading))
    if (!this.controllerReady) {
      DIWebLog.warnT(DIWebLogTag.VIEW, 'ensureDisplayReady skip: controller not ready')
      return
    }
    if (this.loadedUrl.length > 0 && this.webCtrl.isOnBlankPage()) {
      DIWebLog.warnT(DIWebLogTag.VIEW,
        'ensureDisplayReady blank mismatch forceReload loadedUrl=%{public}s webUrl=%{public}s',
        this.loadedUrl, webUrl || '(empty)')
      this.loadedUrl = ''
      this.isLoading = true
      this.loadTargetUrl(this.url, 'blankMismatch')
      return
    }
    this.webCtrl.onActive()
    if (this.isLoading) {
      DIWebLog.infoT(DIWebLogTag.VIEW, 'ensureDisplayReady skip reuse: page still loading')
      return
    }
    if (this.loadedUrl.length > 0 && this.errorMessage.length === 0) {
      this.isLoading = false
      DIWebLog.infoT(DIWebLogTag.VIEW, 'ensureDisplayReady reuse cached page loadedUrl=%{public}s webUrl=%{public}s',
        this.loadedUrl, webUrl || '(empty)')
      if (trigger.startsWith('loadSkip:') || trigger.startsWith('hostVisible')) {
        DIWebLoadMonitor.markCacheReuse()
      }
    }
  }

  build() {
    Column() {
      if (this.showProgress && this.isLoading) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color('#007AFF')
      }

      Stack({ alignContent: Alignment.Center }) {
        Web({
          src: DIWEB_BLANK_SRC,
          controller: this.webCtrl.webController
        })
          .width('100%')
          .height('100%')
          .javaScriptAccess(this.javaScriptAccess)
          .domStorageAccess(this.domStorageAccess)
          .databaseAccess(true)
          .fileAccess(true)
          .imageAccess(true)
          .onlineImageAccess(true)
          .mixedMode(MixedMode.All)
          .cacheMode(CacheMode.Default)
          .zoomAccess(false)
          .javaScriptProxy({
            object: this.webCtrl.bridgeProxyObject,
            name: 'DIWebBridge',
            methodList: ['call', 'callAsync'],
            controller: this.webCtrl.webController
          })
          .onControllerAttached(() => {
            DIWebLog.infoT(DIWebLogTag.VIEW, 'onControllerAttached url=%{public}s blankSrc=%{public}s',
              this.url || '(empty)', DIWEB_BLANK_SRC)
            this.controllerReady = true
            if (this.url && this.url.length > 0) {
              this.isLoading = true
              this.scheduleInitialLoad('onControllerAttached')
            } else {
              this.isLoading = false
            }
          })
          .onProgressChange((event) => {
            if (event) {
              this.progress = event.newProgress
              if (event.newProgress % 25 === 0 || event.newProgress === 100) {
                DIWebLog.debug('onProgressChange: %{public}s', String(event.newProgress))
              }
            }
          })
          .onPageBegin((event) => {
            const pageUrl = event?.url ?? 'unknown'
            DIWebLog.infoT(DIWebLogTag.VIEW, 'onPageBegin url=%{public}s canGoBack=%{public}s trigger=%{public}s',
              pageUrl, String(this.webCtrl.canGoBack()), this.pendingLoadTrigger)
            DIWebLoadMonitor.markPageBegin(pageUrl)
            this.webCtrl.resetBridgeInjected()
            this.isLoading = true
            this.errorMessage = ''
            if (this.onPageBegin && event) {
              this.onPageBegin(event.url)
            }
          })
          .onPageEnd((event) => {
            const pageUrl = event?.url ?? 'unknown'
            if (isBlankPageUrl(pageUrl)) {
              if (this.targetPageLoaded) {
                DIWebLog.infoT(DIWebLogTag.VIEW, 'onPageEnd blank SKIP: target already loaded')
              } else {
                this.blankPlaceholderDone = true
                this.loadedUrl = ''
                DIWebLog.infoT(DIWebLogTag.VIEW, 'onPageEnd blank page -> placeholder done')
                if (this.controllerReady && this.url.length > 0) {
                  DIWebLog.infoT(DIWebLogTag.VIEW,
                    'onPageEnd blank -> loadTargetUrl url=%{public}s', this.url)
                  this.loadTargetUrl(this.url, 'afterBlankReady')
                } else if (this.controllerReady && this.useSharedController && this.url.length === 0) {
                  WebEnginePrewarm.prefetchCommunityDefaultPost(this.webCtrl, 'overlayBlankReady')
                }
              }
            }
            DIWebLog.infoT(DIWebLogTag.VIEW,
              'onPageEnd url=%{public}s bridge=%{public}s canGoBack=%{public}s loadedUrl=%{public}s',
              pageUrl, this.bridgeProfile, String(this.webCtrl.canGoBack()), this.loadedUrl || '(empty)')
            if (!isBlankPageUrl(pageUrl)) {
              this.targetPageLoaded = true
              DIWebLoadMonitor.markPageEnd(pageUrl)
              this.isLoading = false
              DIWebLog.infoT(DIWebLogTag.BRIDGE,
                'onPageEnd -> injectBridge profile=%{public}s pageUrl=%{public}s',
                this.bridgeProfile, pageUrl)
              this.webCtrl.injectBridgeScript(this.bridgeProfile).then((injectMs: number) => {
                if (injectMs >= 0) {
                  DIWebLog.infoT(DIWebLogTag.BRIDGE,
                    'onPageEnd inject done profile=%{public}s injectMs=%{public}s pageUrl=%{public}s',
                    this.bridgeProfile, String(injectMs), pageUrl)
                  DIWebLoadMonitor.markReady(injectMs, true)
                } else {
                  DIWebLog.errorT(DIWebLogTag.BRIDGE,
                    'onPageEnd inject failed profile=%{public}s pageUrl=%{public}s',
                    this.bridgeProfile, pageUrl)
                  DIWebLoadMonitor.markReady(0, false, 'Bridge 注入失败')
                }
              })
            } else {
              this.isLoading = false
            }
            if (this.onPageEnd && event) {
              this.onPageEnd(event.url)
            }
          })
          .onTitleReceive((event) => {
            DIWebLog.debug('onTitleReceive: %{public}s', event?.title ?? '')
            if (event && this.onTitleChange) {
              this.onTitleChange(event.title)
            }
          })
          .onErrorReceive((event) => {
            if (event) {
              const requestUrl = event.request ? event.request.getRequestUrl() : ''
              this.handleWebError(event.error.getErrorCode(), event.error.getErrorInfo(), requestUrl)
            }
          })
          .onHttpErrorReceive((event) => {
            if (event) {
              const status = event.response.getResponseCode()
              const reqUrl = event.request.getRequestUrl()
              DIWebLog.warnT(DIWebLogTag.VIEW, 'onHttpErrorReceive status=%{public}s url=%{public}s isLoading=%{public}s',
                String(status), reqUrl, String(this.isLoading))
              if (status >= 400 && this.isLoading && this.loadedUrl.length === 0) {
                this.handleWebError(status, `HTTP ${status}`, reqUrl)
              }
            }
          })

        if (this.isLoading) {
          Column({ space: 12 }) {
            LoadingProgress()
              .width(40)
              .height(40)
              .color('#007AFF')
            Text('加载中...')
              .fontSize(14)
              .fontColor('#999999')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#FFFFFF')
        }

        if (this.errorMessage.length > 0) {
          Column({ space: 8 }) {
            Text('页面加载失败')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor('#888888')
            Button('重试')
              .onClick(() => {
                DIWebLog.infoT(DIWebLogTag.VIEW, 'retry clicked url=%{public}s controllerReady=%{public}s',
                  this.url || '(empty)', String(this.controllerReady))
                this.errorMessage = ''
                this.loadedUrl = ''
                this.isLoading = true
                if (this.controllerReady) {
                  this.loadTargetUrl(this.url, 'retry')
                }
              })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .padding(24)
          .backgroundColor('#FFFFFF')
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  /** 主文档失败才展示错误层；子资源 / 页面加载完成后的错误仅打日志 */
  private handleWebError(code: number, info: string, requestUrl: string): void {
    DIWebLog.warnT(DIWebLogTag.VIEW,
      'handleWebError code=%{public}s info=%{public}s requestUrl=%{public}s isLoading=%{public}s loadedUrl=%{public}s',
      String(code), info, requestUrl || '(empty)', String(this.isLoading), this.loadedUrl || '(empty)')
    if (this.shouldIgnoreWebError(code, requestUrl)) {
      DIWebLog.infoT(DIWebLogTag.VIEW, 'handleWebError IGNORE code=%{public}s requestUrl=%{public}s',
        String(code), requestUrl || '(empty)')
      return
    }
    this.isLoading = false
    this.errorMessage = `[${code}] ${info}`
    DIWebLog.errorT(DIWebLogTag.VIEW, 'handleWebError FATAL code=%{public}s info=%{public}s', String(code), info)
    DIWebLoadMonitor.markFailed(this.errorMessage)
    if (this.onError) {
      this.onError(this.errorMessage)
    }
  }

  private shouldIgnoreWebError(code: number, requestUrl: string): boolean {
    if (code === -32) {
      return true
    }
    if (!this.isLoading && this.loadedUrl.length > 0) {
      return true
    }
    const target = this.normalizeUrl(this.loadedUrl.length > 0 ? this.loadedUrl : this.url)
    const failed = this.normalizeUrl(requestUrl)
    if (target.length > 0 && failed.length > 0 && !this.isSameDocumentUrl(target, failed)) {
      return true
    }
    return false
  }

  private normalizeUrl(url: string): string {
    return url.replace(/\/+$/, '').toLowerCase()
  }

  private isSameDocumentUrl(a: string, b: string): boolean {
    if (a === b) {
      return true
    }
    return a.endsWith(b) || b.endsWith(a)
  }

  /** 首次加载：等 blank 占位完成后再 loadUrl，避免与 onControllerAttached 双发 */
  private scheduleInitialLoad(trigger: string): void {
    if (!this.controllerReady || this.url.length === 0 || this.targetPageLoaded) {
      return
    }
    if (this.blankPlaceholderDone || !this.webCtrl.isOnBlankPage()) {
      this.loadTargetUrl(this.url, trigger)
      return
    }
    DIWebLog.infoT(DIWebLogTag.VIEW,
      'scheduleInitialLoad wait blank placeholder trigger=%{public}s', trigger)
  }

  private loadTargetUrl(url: string, trigger: string): void {
    const effectiveUrl = (url && url.length > 0) ? url : DIWEB_LOCAL_DEMO_URL
    if (effectiveUrl === this.loadedUrl) {
      DIWebLog.infoT(DIWebLogTag.VIEW, 'loadTargetUrl SKIP same url=%{public}s trigger=%{public}s -> ensureDisplayReady',
        effectiveUrl, trigger)
      this.ensureDisplayReady(`loadSkip:${trigger}`)
      return
    }
    this.pendingLoadTrigger = trigger
    DIWebLog.infoT(DIWebLogTag.VIEW,
      'loadTargetUrl START input=%{public}s effective=%{public}s prevLoaded=%{public}s trigger=%{public}s canGoBack=%{public}s',
      url || '(empty)', effectiveUrl, this.loadedUrl || '(empty)', trigger,
      String(this.webCtrl.canGoBack()))
    this.loadedUrl = effectiveUrl
    this.isLoading = true
    this.webCtrl.loadPage(this.resolveUrl(effectiveUrl), trigger)
  }

  private resolveUrl(url: string): string | Resource {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      DIWebLog.info('resolveUrl -> remote: %{public}s', url)
      return url
    }
    const path = normalizeRawfilePath(url)
    DIWebLog.info('resolveUrl -> local rawfile: %{public}s', path)
    return resolveRawfile(path)
  }
}
