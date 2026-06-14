import router from '@ohos.router'
import { TabMenuItem } from './TabMenuItem'

interface MineMenuItem {
  title: string
  subtitle: string
  pageType: string
}

/**
 * 我的 Tab：原生页面
 */
@Component
export struct MineTab {
  private menuItems: MineMenuItem[] = [
    { title: '个人资料', subtitle: '头像、昵称、手机号', pageType: 'profile' },
    { title: '我的订单', subtitle: '商城订单与物流', pageType: 'orders' },
    { title: '设置', subtitle: '通知、隐私、关于', pageType: 'settings' },
    { title: 'Web 加载监控', subtitle: '查看其它入口打开 H5 的耗时', pageType: 'webMonitor' }
  ]

  private openNativePage(pageType: string, title: string): void {
    router.pushUrl({
      url: 'pages/mine/MineSubPage',
      params: { pageType, title }
    })
  }

  private openWebMonitorPage(): void {
    router.pushUrl({ url: 'pages/mine/WebLoadMonitorPage' })
  }

  build() {
    Column() {
      Row() {
        Text('我的')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')

      Column({ space: 12 }) {
        Row() {
          Column() {
            Text('用')
              .fontSize(24)
              .fontColor('#FFFFFF')
          }
          .width(64)
          .height(64)
          .borderRadius(32)
          .backgroundColor('#007AFF')
          .justifyContent(FlexAlign.Center)

          Column({ space: 4 }) {
            Text('用户昵称')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
            Text('138****8888')
              .fontSize(13)
              .fontColor('#999999')
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 16 })
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .onClick(() => {
          this.openNativePage('profile', '个人资料')
        })

        Column({ space: 1 }) {
          ForEach(this.menuItems, (item: MineMenuItem, index: number) => {
            TabMenuItem({
              item: {
                title: item.title,
                subtitle: item.subtitle,
                h5Url: '',
                h5Title: item.title
              },
              onTap: () => {
                if (item.pageType === 'webMonitor') {
                  this.openWebMonitorPage()
                } else {
                  this.openNativePage(item.pageType, item.title)
                }
              }
            })
          }, (item: MineMenuItem, index: number) => `${item.title}_${index}`)
        }
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
    }
    .width('100%')
    .height('100%')
  }
}
