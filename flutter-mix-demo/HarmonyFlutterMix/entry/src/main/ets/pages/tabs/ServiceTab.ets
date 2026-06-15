import { CoreUtils, WebNavigateParams } from '../../common/core/components/utils/CoreUtils'
import { DIWebH5Path } from '../../diweb/DIWebRawfile'
import { DIWebLog, DIWebLogTag } from '../../diweb/DIWebLog'
import { TabMenuItem, TabMenuItemData } from './TabMenuItem'

/**
 * 服务 Tab
 */
@Component
export struct ServiceTab {
  private menuItems: TabMenuItemData[] = [
    { title: '预约维保', subtitle: '在线预约保养维修', h5Url: DIWebH5Path.SERVICE_DETAIL, h5Title: '预约维保' },
    { title: '道路救援', subtitle: '7×24 小时紧急救援', h5Url: DIWebH5Path.SERVICE_DETAIL, h5Title: '道路救援' },
    { title: '充电服务', subtitle: '查找附近充电桩', h5Url: DIWebH5Path.SERVICE_DETAIL, h5Title: '充电服务' },
    { title: '保险服务', subtitle: '车险报价与理赔', h5Url: DIWebH5Path.SERVICE_DETAIL, h5Title: '保险服务' }
  ]

  build() {
    Column() {
      Row() {
        Text('服务')
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
        ForEach(this.menuItems, (item: TabMenuItemData, index: number) => {
          TabMenuItem({
            item: item,
            onTap: (data: TabMenuItemData) => {
              DIWebLog.infoT(DIWebLogTag.ROUTER, 'ServiceTab click title=%{public}s url=%{public}s',
                data.h5Title, data.h5Url)
              const navParams: WebNavigateParams = {
                url: data.h5Url,
                title: data.h5Title,
                source: '服务',
                scene: 'service',
                bridgeProfile: 'service'
              }
              CoreUtils.navigateToWebview(navParams)
            }
          })
        }, (item: TabMenuItemData, index: number) => `${item.title}_${index}`)
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
      .padding({ top: 12 })
    }
    .width('100%')
    .height('100%')
  }
}
