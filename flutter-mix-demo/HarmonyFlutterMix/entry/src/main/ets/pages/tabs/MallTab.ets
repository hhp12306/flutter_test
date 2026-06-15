import { CoreUtils, WebNavigateParams } from '../../common/core/components/utils/CoreUtils'
import { DIWebH5Path } from '../../diweb/DIWebRawfile'
import { DIWebLog, DIWebLogTag } from '../../diweb/DIWebLog'

interface MallProduct {
  id: string
  name: string
  price: string
  desc: string
}

/**
 * 商城 Tab：原生商品列表，点击进入 H5 详情
 */
@Component
export struct MallTab {
  private products: MallProduct[] = [
    { id: '1', name: '智能行车记录仪', price: '¥299', desc: '4K高清 · 夜视增强' },
    { id: '2', name: '车载空气净化器', price: '¥459', desc: 'HEPA过滤 · 静音运行' },
    { id: '3', name: '无线车载充电器', price: '¥129', desc: '15W快充 · 自动夹持' },
    { id: '4', name: '全包围脚垫', price: '¥388', desc: '专车定制 · 防水耐磨' }
  ]

  build() {
    Column() {
      Row() {
        Text('商城')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.products, (product: MallProduct) => {
            Row() {
              Column() {
                Text('🛍')
                  .fontSize(28)
              }
              .width(72)
              .height(72)
              .borderRadius(8)
              .backgroundColor('#F5F5F5')
              .justifyContent(FlexAlign.Center)

              Column({ space: 4 }) {
                Text(product.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333333')
                Text(product.desc)
                  .fontSize(13)
                  .fontColor('#999999')
                Text(product.price)
                  .fontSize(15)
                  .fontColor('#FF6B00')
                  .fontWeight(FontWeight.Medium)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .onClick(() => {
              DIWebLog.infoT(DIWebLogTag.ROUTER, 'MallTab click product=%{public}s url=%{public}s',
                product.name, DIWebH5Path.MALL_DETAIL)
              const navParams: WebNavigateParams = {
                url: DIWebH5Path.MALL_DETAIL,
                title: product.name,
                source: '商城',
                scene: 'mall',
                bridgeProfile: 'mall'
              }
              CoreUtils.navigateToWebview(navParams)
            })
          }, (product: MallProduct) => product.id)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }
}
