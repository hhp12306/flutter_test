
import common from '@ohos.app.ability.common';
import { DiscoverTab } from './tabs/DiscoverTab'
import { MallTab } from './tabs/MallTab'
import { CarTab } from './tabs/CarTab'
import { ServiceTab } from './tabs/ServiceTab'
import { MineTab } from './tabs/MineTab'
import { TestTab } from './tabs/TestTab'
import { DIWebOverlay } from '../diweb/DIWebOverlay'
import { DIWebRouter } from '../diweb/DIWebRouter'
import { DIWebSession, DIWEB_OVERLAY_VISIBLE_KEY } from '../diweb/DIWebSession'
import { DIWebLog, DIWebLogTag } from '../diweb/DIWebLog'

const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

@Entry
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @State currentIndex: number = 0
  @StorageLink(DIWEB_OVERLAY_VISIBLE_KEY) overlayVisible: boolean = false

  aboutToAppear(): void {
    DIWebSession.initOverlayStorage()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Overlay 放底层：隐藏时 Tabs zIndex 更高，避免 Web 挡住底部 Tab 点击
      DIWebOverlay()
        .width('100%')
        .height('100%')
        .zIndex(this.overlayVisible ? 1000 : 0)

      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        TabContent() {
          DiscoverTab({ isActive: this.currentIndex === 0 })
        }
        .tabBar(this.tabBarItem('发现', 0))

        TabContent() {
          MallTab()
        }
        .tabBar(this.tabBarItem('商城', 1))

        TabContent() {
          CarTab()
        }
        .tabBar(this.tabBarItem('爱车', 2))

        TabContent() {
          ServiceTab()
        }
        .tabBar(this.tabBarItem('服务', 3))

        TabContent() {
          TestTab()
        }
        .tabBar(this.tabBarItem('测试', 4))

        TabContent() {
          MineTab()
        }
        .tabBar(this.tabBarItem('我的', 5))
      }
      .scrollable(false)
      .barHeight(56)
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        const session = DIWebSession.getInstance()
        DIWebLog.infoT(DIWebLogTag.INDEX,
          'tabChange index=%{public}s overlayVisible=%{public}s session=%{public}s',
          String(index), String(this.overlayVisible), session.getDiagnosticSummary())
        this.currentIndex = index
      })
      .width('100%')
      .height('100%')
      .zIndex(this.overlayVisible ? 0 : 1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  tabBarItem(title: string, index: number) {
    Column() {
      Text(this.tabIcon(index))
        .fontSize(20)
      Text(title)
        .fontSize(10)
        .margin({ top: 2 })
        .fontColor(this.currentIndex === index ? '#007AFF' : '#999999')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  private tabIcon(index: number): string {
    const icons: string[] = ['🔍', '🛒', '🚗', '🔧', '🧪', '👤']
    return icons[index] ?? '•'
  }

  onBackPress(): boolean {
    DIWebLog.infoT(DIWebLogTag.INDEX, 'onBackPress overlayVisible=%{public}s tabIndex=%{public}d',
      String(this.overlayVisible), String(this.currentIndex))
    if (DIWebSession.getInstance().isOverlayVisible()) {
      DIWebLog.infoT(DIWebLogTag.INDEX, 'onBackPress close overlay directly')
      DIWebRouter.back()
      return true
    }
    if (this.currentIndex === 0) {
      this.context.eventHub.emit(EVENT_BACK_PRESS)
      return true
    }
    return false
  }
}
