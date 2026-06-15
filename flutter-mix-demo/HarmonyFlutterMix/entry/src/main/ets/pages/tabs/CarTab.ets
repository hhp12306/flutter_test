import { CoreUtils, WebNavigateParams } from '../../common/core/components/utils/CoreUtils'
import { DIWebH5Path } from '../../diweb/DIWebRawfile'
import { DIWebLog, DIWebLogTag } from '../../diweb/DIWebLog'
import { TabMenuItem, TabMenuItemData } from './TabMenuItem'

/**
 * 爱车 Tab
 */
@Component
export struct CarTab {
  private menuItems: TabMenuItemData[] = [
    { title: '车辆信息', subtitle: '查看车辆档案与状态', h5Url: DIWebH5Path.CAR_DETAIL, h5Title: '车辆信息' },
    { title: '保养记录', subtitle: '历史保养与提醒', h5Url: DIWebH5Path.CAR_DETAIL, h5Title: '保养记录' },
    { title: '行驶数据', subtitle: '里程、油耗统计', h5Url: DIWebH5Path.CAR_DETAIL, h5Title: '行驶数据' }
  ]

  build() {
    Column() {
      Row() {
        Text('爱车')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')

      Column({ space: 1 }) {
        Row() {
          Column({ space: 4 }) {
            Text('我的 Model Y')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
            Text('续航 420km · 电量 78%')
              .fontSize(13)
              .fontColor('#666666')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('🚗')
            .fontSize(40)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .margin({ bottom: 12 })

        ForEach(this.menuItems, (item: TabMenuItemData, index: number) => {
          TabMenuItem({
            item: item,
            onTap: (data: TabMenuItemData) => {
              DIWebLog.infoT(DIWebLogTag.ROUTER, 'CarTab click title=%{public}s url=%{public}s',
                data.h5Title, data.h5Url)
              const navParams: WebNavigateParams = {
                url: data.h5Url,
                title: data.h5Title,
                source: '爱车',
                scene: 'service',
                bridgeProfile: 'community'
              }
              CoreUtils.navigateToWebview(navParams)
            }
          })
        }, (item: TabMenuItemData, index: number) => `${item.title}_${index}`)
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }
}
