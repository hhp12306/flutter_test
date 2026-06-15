import { DIWeb } from '../../../../diweb/DIWeb'
import { DIWebController } from '../../../../diweb/DIWebController'
import { BridgeConfig, BridgeProfile } from './BridgeProfile'
import { WebCallBindings } from './WebCallHandler'
import { DIWebLog, DIWebLogTag } from '../../../../diweb/DIWebLog'

/**
 * Web 容器（对齐公司 WebContainer：Loading/Error/遮罩）
 */
@Component
export struct WebContainer {
  @Prop @Watch('onUrlUpdated') url: string = ''
  @Prop showProgress: boolean = true
  @Prop bridgeProfile: BridgeProfile = BridgeProfile.FULL
  controller: DIWebController = new DIWebController()
  call: WebCallBindings = {}
  @State loadVisible: boolean = false
  @State errorVisible: boolean = false
  @State errorMessage: string = ''
  @State pendingNavigation: boolean = false
  private prevUrl: string = ''

  aboutToAppear(): void {
    this.prevUrl = this.url
    if (this.url.length > 0) {
      this.pendingNavigation = true
    }
  }

  onUrlUpdated(): void {
    if (this.url !== this.prevUrl && this.url.length > 0) {
      this.pendingNavigation = true
      this.errorVisible = false
      this.errorMessage = ''
      this.prevUrl = this.url
      DIWebLog.infoT(DIWebLogTag.VIEW, 'WebContainer urlChanged pendingNavigation=true url=%{public}s',
        this.url)
    }
  }

  /** 供 WebPageBridge 控制遮罩 */
  setPendingNavigation(pending: boolean): void {
    this.pendingNavigation = pending
    if (!pending) {
      this.loadVisible = false
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.url.length === 0) {
        Column({ space: 8 }) {
          Text('暂无内容')
            .fontSize(15)
            .fontColor('#999999')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        DIWeb({
          url: this.url,
          showProgress: this.showProgress && !this.pendingNavigation,
          useSharedController: false,
          externalController: this.controller,
          bridgeProfile: BridgeConfig.toDIWebProfile(this.bridgeProfile),
          hostVisible: !this.pendingNavigation,
          onPageBegin: (pageUrl: string) => {
            this.loadVisible = true
            if (this.call.onPageBegin) {
              this.call.onPageBegin(pageUrl)
            }
          },
          onPageEnd: (pageUrl: string) => {
            this.pendingNavigation = false
            this.loadVisible = false
            if (this.call.onPageEnd) {
              this.call.onPageEnd(pageUrl)
            }
          },
          onTitleChange: (title: string) => {
            if (this.call.onTitleChange) {
              this.call.onTitleChange(title)
            }
          },
          onError: (desc: string) => {
            this.errorVisible = true
            this.errorMessage = desc
            this.loadVisible = false
            this.pendingNavigation = false
            if (this.call.onError) {
              this.call.onError(desc)
            }
          }
        })
          .width('100%')
          .height('100%')
          .opacity(this.pendingNavigation ? 0 : 1)

        if (this.errorVisible) {
          Column({ space: 8 }) {
            Text('页面加载失败')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor('#888888')
            Button('重试')
              .onClick(() => {
                this.errorVisible = false
                this.errorMessage = ''
                this.pendingNavigation = true
                this.controller.reload()
              })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .padding(24)
          .backgroundColor('#FFFFFF')
        }
      }

      if (this.pendingNavigation || this.loadVisible) {
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
    .width('100%')
    .height('100%')
    .onAppear(() => {
      this.loadVisible = true
      DIWebLog.infoT(DIWebLogTag.VIEW, 'WebContainer.onAppear loadVisible=true')
    })
  }
}
