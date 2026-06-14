
import { FlutterPage, FlutterEntry } from '@ohos/flutter_ohos'
import { DiscoverFlutterConfigurator } from '../../flutter/DiscoverFlutterConfigurator'
import { DiscoverFlutterHolder } from '../../flutter/DiscoverFlutterHolder'
import { DIWebLog, DIWebLogTag } from '../../diweb/DIWebLog'
import { DIWebSession } from '../../diweb/DIWebSession'

@Component
export struct DiscoverTab {
  @Prop @Watch('onActiveChanged') isActive: boolean = false
  @State viewId: string = ''
  @State showFlutter: boolean = false
  @State isLoading: boolean = false
  private flutterEntry: FlutterEntry | null = null
  private initialized: boolean = false

  aboutToAppear(): void {
    DIWebLog.infoT(DIWebLogTag.PREWARM, 'DiscoverTab aboutToAppear isActive=%{public}s initialized=%{public}s',
      String(this.isActive), String(this.initialized))
    if (this.isActive && !this.initialized) {
      DIWebSession.getInstance().prewarmWeb('社区Tab')
      this.initFlutter()
    }
  }

  aboutToDisappear(): void {
    if (this.flutterEntry !== null) {
      this.flutterEntry.aboutToDisappear()
      DiscoverFlutterHolder.setEntry(null)
      this.flutterEntry = null
      this.initialized = false
    }
  }

  onActiveChanged(): void {
    DIWebLog.infoT(DIWebLogTag.PREWARM, 'DiscoverTab onActiveChanged isActive=%{public}s initialized=%{public}s',
      String(this.isActive), String(this.initialized))
    if (this.isActive) {
      DIWebSession.getInstance().prewarmWeb('社区Tab')
      if (!this.initialized) {
        this.initFlutter()
      } else {
        DIWebLog.info('DiscoverTab flutter onPageShow')
        this.flutterEntry?.onPageShow()
      }
    } else if (this.initialized) {
      DIWebLog.info('DiscoverTab flutter onPageHide')
      this.flutterEntry?.onPageHide()
    }
  }

  private initFlutter(): void {
    if (this.initialized) {
      return
    }
    this.isLoading = true
    DIWebLog.info('DiscoverTab initFlutter start')
    const context = getContext(this) as Context
    const entry = new FlutterEntry(context)
    entry.setFlutterEngineConfigurator(new DiscoverFlutterConfigurator())
    entry.aboutToAppear()
    this.flutterEntry = entry
    this.viewId = entry.getFlutterView().getId()
    DiscoverFlutterHolder.setEntry(entry)
    this.initialized = true
    this.showFlutter = true
    this.isLoading = false
    DIWebLog.info('DiscoverTab initFlutter end, viewId=%{public}s', this.viewId)
  }

  build() {
    Column() {
      if (this.showFlutter) {
        FlutterPage({ viewId: this.viewId })
          .width('100%')
          .height('100%')
      } else if (this.isLoading) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#007AFF')
          Text('Flutter 加载中...')
            .fontSize(14)
            .fontColor('#999999')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
