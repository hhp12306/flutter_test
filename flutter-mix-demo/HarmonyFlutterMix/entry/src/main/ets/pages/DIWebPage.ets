import router from '@ohos.router'
import { DIWeb } from '../diweb/DIWeb'
import { DIWebController } from '../diweb/DIWebController'
import { BridgeConfig, BridgeProfile } from '../common/core/components/web/BridgeProfile'
import { JsBridgeApi } from '../common/core/components/web/JsBridgeApi'
import { ActionJsApi } from '../common/core/components/web/ActionJsApi'
import { WebCallHandler } from '../common/core/components/web/WebCallHandler'
import { RouterManager } from '../common/core/router/RouterManager'
import { RouterKeys } from '../common/core/router/RouterKeys'
import { DIWEB_LOCAL_DEMO_URL } from '../diweb/DIWebTypes'
import { DIWebLog, DIWebLogTag } from '../diweb/DIWebLog'
import { WebFlowTracer } from '../common/core/utils/WebFlowTracer'

/**
 * 公司 WebPageBridge 路由页（注册路径 pages/DIWebPage，日志标识 WebPageBridge）
 */
@Entry
@Component
struct DIWebPage {
  @State url: string = DIWEB_LOCAL_DEMO_URL
  @State title: string = ''
  @State showNavBar: boolean = true
  @State showProgress: boolean = true
  @State bridgeProfile: BridgeProfile = BridgeProfile.FULL
  @State pendingNavigation: boolean = false
  private webCtrl: DIWebController | null = null
  private handler: WebCallHandler = new WebCallHandler()
  private jsApi: JsBridgeApi = new JsBridgeApi()
  private actionApi: ActionJsApi = new ActionJsApi()
  private bridgeInited: boolean = false

  private isBlankPageUrl(url: string): boolean {
    return url.length === 0 || url.includes('about:blank')
  }

  aboutToAppear(): void {
    DIWebLog.infoT(DIWebLogTag.PAGE, 'WebPageBridge.@Entry aboutToAppear (pages/DIWebPage)')
    WebFlowTracer.step('WebPageBridge', '@Entry aboutToAppear pages/DIWebPage')

    const params = router.getParams() as Record<string, Object>
    DIWebLog.infoT(DIWebLogTag.PAGE, 'WebPageBridge params=%{public}s', JSON.stringify(params ?? {}))
    this.applyParams(params)
    this.handler.supportMulti(params[RouterKeys.MULTI] === true)
    this.pendingNavigation = this.url.length > 0
    WebFlowTracer.step('WebPageBridge', 'controller=DIWeb独立实例(useSharedController=false)')
  }

  aboutToDisappear(): void {
    DIWebLog.infoT(DIWebLogTag.PAGE, 'WebPageBridge.@Entry aboutToDisappear')
    this.webCtrl = null
    this.bridgeInited = false
  }

  private applyParams(params: Record<string, Object>): void {
    if (!params || Object.keys(params).length === 0) {
      return
    }
    const rawUrl = String(params[RouterKeys.URL] ?? '')
    this.url = rawUrl.length > 0 ? rawUrl : DIWEB_LOCAL_DEMO_URL
    if (!this.url.startsWith('http://') && !this.url.startsWith('https://')) {
      try {
        this.url = decodeURIComponent(this.url).replace(/&amp;/g, '&')
      } catch (_e) {
      }
    }
    this.title = String(params[RouterKeys.TITLE] ?? '')
    this.showNavBar = params[RouterKeys.SHOW_TITLE] !== false
    this.showProgress = params[RouterKeys.SHOW_PROGRESS] !== false
    this.bridgeProfile = BridgeConfig.parse(String(params[RouterKeys.BRIDGE_PROFILE] ?? ''),
      BridgeProfile.FULL)
    DIWebLog.infoT(DIWebLogTag.PAGE,
      'WebPageBridge.applyParams url=%{public}s bridge=%{public}s', this.url, this.bridgeProfile)
  }

  private initBridge(ctrl: DIWebController): void {
    if (this.bridgeInited) {
      return
    }
    const context = getContext(this) as Context
    this.jsApi.init(context, ctrl, {
      onTitleChange: (newTitle: string) => {
        if (newTitle.length > 0) {
          this.title = newTitle
        }
      },
      onClose: () => {
        RouterManager.back()
      }
    }, this.bridgeProfile)
    this.jsApi.addJsApiObj(ctrl, this.jsApi.getBridgeName())
    this.actionApi.init(context, ctrl, this.bridgeProfile)
    this.actionApi.registerToController(ctrl, this.bridgeProfile)
    this.bridgeInited = true
    WebFlowTracer.step('WebPageBridge', `JsBridgeApi+ActionJsApi bridge=${this.bridgeProfile}`)
  }

  onBackPress(): boolean {
    if (this.handler.handleBack(this.webCtrl)) {
      return true
    }
    RouterManager.back()
    return true
  }

  build() {
    Column() {
      if (this.showNavBar) {
        Row() {
          Text('‹')
            .fontSize(28)
            .fontColor('#333333')
            .width(40)
            .textAlign(TextAlign.Center)
            .margin({ left: 8 })
            .onClick(() => {
              if (this.webCtrl !== null && this.webCtrl.goBack()) {
                return
              }
              RouterManager.back()
            })

          Text(this.title || '加载中...')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Row().width(40).height(24)
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#FFFFFF')
        .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })
      }

      Stack({ alignContent: Alignment.Center }) {
        DIWeb({
          url: this.url,
          showProgress: this.showProgress && !this.pendingNavigation,
          useSharedController: false,
          bridgeProfile: BridgeConfig.toDIWebProfile(this.bridgeProfile),
          hostVisible: true,
          onControllerReady: (ctrl: DIWebController) => {
            this.webCtrl = ctrl
            this.initBridge(ctrl)
            WebFlowTracer.step('WebPageBridge', 'DIWeb onControllerReady')
          },
          onPageBegin: (pageUrl: string) => {
            if (this.isBlankPageUrl(pageUrl)) {
              WebFlowTracer.step('WebContainer', `onPageBegin url=${pageUrl} (placeholder)`)
              return
            }
            this.pendingNavigation = true
            WebFlowTracer.step('WebContainer', `onPageBegin url=${pageUrl}`)
          },
          onPageEnd: (pageUrl: string) => {
            if (this.isBlankPageUrl(pageUrl)) {
              WebFlowTracer.step('WebContainer', `onPageEnd url=${pageUrl} (placeholder, wait target)`)
              return
            }
            this.pendingNavigation = false
            WebFlowTracer.step('WebContainer', `onPageEnd url=${pageUrl}`)
            WebFlowTracer.end('✅ 公司路由链路成功')
            DIWebLog.infoT(DIWebLogTag.PAGE, 'WebPageBridge load SUCCESS url=%{public}s', pageUrl)
          },
          onTitleChange: (newTitle: string) => {
            if (!this.title && newTitle) {
              this.title = newTitle
            }
          },
          onError: (desc: string) => {
            this.pendingNavigation = false
            WebFlowTracer.end(`❌ 加载失败: ${desc}`)
            DIWebLog.errorT(DIWebLogTag.PAGE, 'WebPageBridge onError: %{public}s', desc)
          }
        })
          .width('100%')
          .height('100%')
          .opacity(this.pendingNavigation ? 0 : 1)

        if (this.pendingNavigation) {
          Column({ space: 12 }) {
            LoadingProgress().width(40).height(40).color('#007AFF')
            Text('加载中...').fontSize(14).fontColor('#999999')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#FFFFFF')
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
