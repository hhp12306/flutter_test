import router from '@ohos.router'
import { DIWeb } from '../diweb/DIWeb'
import { DIWebController } from '../diweb/DIWebController'
import { DIWebRouteParams, DIWebRouter } from '../diweb/DIWebRouter'
import { DIWebSession } from '../diweb/DIWebSession'
import { DIWEB_LOCAL_DEMO_URL } from '../diweb/DIWebTypes'
import { DIWebLog, DIWebLogTag } from '../diweb/DIWebLog'

/**
 * H5 二级页面容器（单例 WebView）：带导航栏，支持 Web 内后退与关闭
 */
@Entry
@Component
struct DIWebPage {
  @State url: string = DIWEB_LOCAL_DEMO_URL
  @State title: string = ''
  @State showNavBar: boolean = true
  @State showProgress: boolean = true
  private webCtrl: DIWebController | null = null

  aboutToAppear(): void {
    DIWebLog.infoT(DIWebLogTag.PAGE, 'aboutToAppear')
    DIWebSession.getInstance().bindPage((params: DIWebRouteParams) => {
      this.applyRouteParams(params)
    })
    const params = router.getParams() as DIWebRouteParams
    DIWebLog.infoT(DIWebLogTag.PAGE, 'params=%{public}s', JSON.stringify(params ?? {}))
    this.applyRouteParams(params)
  }

  aboutToDisappear(): void {
    DIWebLog.infoT(DIWebLogTag.PAGE, 'aboutToDisappear unbindPage')
    DIWebSession.getInstance().unbindPage()
  }

  private applyRouteParams(params?: DIWebRouteParams): void {
    if (!params) {
      return
    }
    this.url = (params.url && params.url.length > 0) ? params.url : DIWEB_LOCAL_DEMO_URL
    this.title = params.title ?? ''
    this.showNavBar = params.showNavBar ?? true
    this.showProgress = params.showProgress ?? true
    DIWebLog.infoT(DIWebLogTag.PAGE, 'applyRoute url=%{public}s title=%{public}s', this.url, this.title)
  }

  onBackPress(): boolean {
    DIWebLog.infoT(DIWebLogTag.PAGE, 'onBackPress webCanGoBack=%{public}s',
      String(this.webCtrl?.canGoBack() ?? false))
    if (this.webCtrl && this.webCtrl.goBack()) {
      return true
    }
    return false
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
              if (this.webCtrl && this.webCtrl.goBack()) {
                return
              }
              DIWebRouter.back()
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

      DIWeb({
        url: this.url,
        showProgress: this.showProgress,
        onControllerReady: (ctrl: DIWebController) => {
          this.webCtrl = ctrl
          ctrl.configureBridge({
            onTitleChange: (newTitle: string) => {
              if (newTitle && newTitle.length > 0) {
                this.title = newTitle
              }
            },
            onClose: () => {
              DIWebLog.info('DIWebPage bridge close')
              DIWebRouter.back()
            }
          })
        },
        onTitleChange: (newTitle: string) => {
          if (!this.title && newTitle) {
            this.title = newTitle
          }
        },
        onError: (desc: string) => {
          DIWebLog.error('DIWebPage onError: %{public}s', desc)
        }
      })
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
