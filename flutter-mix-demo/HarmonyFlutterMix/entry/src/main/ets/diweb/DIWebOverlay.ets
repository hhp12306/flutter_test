import { DIWeb } from './DIWeb'
import { DIWebController } from './DIWebController'
import { DIWebRouteParams } from './DIWebRouter'
import { RouterManager } from '../common/core/router/RouterManager'
import { DIWebSession, DIWEB_OVERLAY_VISIBLE_KEY } from './DIWebSession'
import { DIWebLog, DIWebLogTag } from './DIWebLog'
import { DIWebLoadMonitor } from './DIWebLoadMonitor'

/**
 * Index 层常驻 H5 容器：隐藏时不销毁 WebView，返回后再开接近秒开
 */
@Component
export struct DIWebOverlay {
  @StorageLink(DIWEB_OVERLAY_VISIBLE_KEY) @Watch('onVisibleChanged') visible: boolean = false
  @State url: string = ''
  @State title: string = ''
  @State showNavBar: boolean = true
  @State showProgress: boolean = true
  @State bridgeProfile: string = 'full'
  @State forceReloadTick: number = 0
  /** URL 切换中：用全屏 Loading 遮住旧 Web 内容，避免闪烁 */
  @State pendingNavigation: boolean = false
  private webCtrl: DIWebController | null = null

  aboutToAppear(): void {
    DIWebSession.initOverlayStorage()
    DIWebSession.getInstance().bindOverlayHost((params: DIWebRouteParams) => {
      this.applyRouteParams(params)
    })
    DIWebLog.infoT(DIWebLogTag.OVERLAY, 'aboutToAppear bindOverlayHost')
  }

  onVisibleChanged(): void {
    DIWebLog.infoT(DIWebLogTag.OVERLAY,
      'onVisibleChanged visible=%{public}s url=%{public}s title=%{public}s pendingNav=%{public}s webCanGoBack=%{public}s',
      String(this.visible), this.url || '(empty)', this.title || '(empty)', String(this.pendingNavigation),
      String(this.webCtrl?.canGoBack() ?? DIWebSession.getInstance().getSharedController().canGoBack()))
    if (this.visible) {
      DIWebLoadMonitor.markOverlayVisible()
      this.onOverlayShow()
    } else {
      this.onOverlayHide()
    }
  }

  private onOverlayShow(): void {
    DIWebLog.infoT(DIWebLogTag.OVERLAY, 'onOverlayShow url=%{public}s pendingNav=%{public}s',
      this.url || '(empty)', String(this.pendingNavigation))
    if (this.pendingNavigation) {
      DIWebLog.infoT(DIWebLogTag.OVERLAY, 'onOverlayShow defer onActive until pageEnd')
      return
    }
    if (this.webCtrl !== null) {
      this.webCtrl.onActive()
    }
  }

  private onOverlayHide(): void {
    DIWebLog.infoT(DIWebLogTag.OVERLAY, 'onOverlayHide url=%{public}s', this.url || '(empty)')
    this.pendingNavigation = false
    if (this.webCtrl !== null) {
      this.webCtrl.onInactive()
    }
  }

  aboutToDisappear(): void {
    DIWebSession.getInstance().unbindOverlayHost()
    DIWebLog.infoT(DIWebLogTag.OVERLAY, 'aboutToDisappear unbindOverlayHost')
  }

  private applyRouteParams(params: DIWebRouteParams): void {
    const prevUrl = this.url
    const prevTitle = this.title
    const prevBridge = this.bridgeProfile
    const sameUrl = prevUrl === (params.url ?? '')
    const titleChanged = prevTitle !== (params.title ?? '')
    const newBridge = params.bridgeProfile ?? 'full'
    const bridgeChanged = prevBridge !== newBridge
    this.url = params.url ?? ''
    this.title = params.title ?? ''
    this.showNavBar = params.showNavBar ?? true
    this.showProgress = params.showProgress ?? true
    this.bridgeProfile = newBridge
    DIWebLog.infoT(DIWebLogTag.OVERLAY,
      'applyRoute prevUrl=%{public}s -> url=%{public}s bridge=%{public}s -> %{public}s sameUrl=%{public}s titleChanged=%{public}s bridgeChanged=%{public}s visible=%{public}s',
      prevUrl || '(empty)', this.url || '(empty)', prevBridge, newBridge,
      String(sameUrl), String(titleChanged), String(bridgeChanged), String(this.visible))
    if (sameUrl && (titleChanged || bridgeChanged)) {
      this.forceReloadTick++
      this.pendingNavigation = true
      DIWebLog.infoT(DIWebLogTag.OVERLAY,
        'applyRoute sameUrl+metaChanged forceReload tick=%{public}s reason=%{public}s pendingNavigation=true',
        String(this.forceReloadTick), bridgeChanged ? 'bridgeChanged' : 'titleChanged')
    } else if (!sameUrl) {
      this.pendingNavigation = true
      DIWebLog.infoT(DIWebLogTag.OVERLAY, 'applyRoute urlChanged pendingNavigation=true')
    } else if (sameUrl && this.visible) {
      DIWebLog.infoT(DIWebLogTag.OVERLAY, 'applyRoute sameUrl while visible -> onOverlayShow')
      this.onOverlayShow()
    }
  }

  private clearPendingNavigation(reason: string): void {
    if (!this.pendingNavigation) {
      return
    }
    this.pendingNavigation = false
    DIWebLog.infoT(DIWebLogTag.OVERLAY, 'clearPendingNavigation reason=%{public}s url=%{public}s',
      reason, this.url || '(empty)')
    if (this.visible && this.webCtrl !== null) {
      this.webCtrl.onActive()
      DIWebLog.infoT(DIWebLogTag.OVERLAY, 'clearPendingNavigation onActive after page ready')
    }
    DIWebLoadMonitor.markOverlayContentVisible()
  }

  private handleBack(): void {
    const webUrl = this.webCtrl?.getCurrentUrl() ?? ''
    DIWebLog.infoT(DIWebLogTag.OVERLAY,
      'handleBack closeOverlay url=%{public}s webUrl=%{public}s webCanGoBack=%{public}s',
      this.url || '(empty)', webUrl || '(empty)', String(this.webCtrl?.canGoBack() ?? false))
    // Overlay 模式：直接关闭容器，不走 Web 内后退（避免退到 about:blank 占位页）
    RouterManager.back()
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
              this.handleBack()
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
          hostVisible: this.visible && !this.pendingNavigation,
          forceReloadTick: this.forceReloadTick,
          bridgeProfile: this.bridgeProfile as 'community' | 'full',
          onControllerReady: (ctrl: DIWebController) => {
            this.webCtrl = ctrl
            ctrl.configureBridge({
              onTitleChange: (newTitle: string) => {
                if (newTitle && newTitle.length > 0 && !newTitle.includes('about:blank')) {
                  this.title = newTitle
                }
              },
              onClose: () => {
                DIWebLog.infoT(DIWebLogTag.OVERLAY, 'bridge close -> RouterManager.back')
                RouterManager.back()
              }
            })
          },
          onPageEnd: (pageUrl: string) => {
            if (this.pendingNavigation) {
              this.clearPendingNavigation(`onPageEnd:${pageUrl}`)
            }
          },
          onTitleChange: (newTitle: string) => {
            if (!this.title && newTitle) {
              this.title = newTitle
            }
          },
          onError: (desc: string) => {
            this.clearPendingNavigation('onError')
            DIWebLog.errorT(DIWebLogTag.OVERLAY, 'onError: %{public}s', desc)
          }
        })
          .width('100%')
          .height('100%')
          .opacity(this.pendingNavigation ? 0 : 1)

        if (this.pendingNavigation) {
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
      }
      .layoutWeight(1)
      .width('100%')
      .hitTestBehavior(this.visible ? HitTestMode.Default : HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .visibility(this.visible ? Visibility.Visible : Visibility.Hidden)
    .hitTestBehavior(this.visible ? HitTestMode.Default : HitTestMode.None)
  }
}
