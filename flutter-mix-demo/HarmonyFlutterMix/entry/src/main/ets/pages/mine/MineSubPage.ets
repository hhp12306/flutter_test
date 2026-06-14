import router from '@ohos.router'

interface MineSubPageParams {
  pageType?: string
  title?: string
}

interface SettingItem {
  label: string
  value: string
}

/**
 * 我的 Tab 原生二级页
 */
@Entry
@Component
struct MineSubPage {
  @State pageType: string = 'profile'
  @State title: string = ''
  private settingItems: SettingItem[] = [
    { label: '消息通知', value: '已开启' },
    { label: '隐私设置', value: '' },
    { label: '关于我们', value: 'v1.0.0' }
  ]

  aboutToAppear(): void {
    const params = router.getParams() as MineSubPageParams
    if (params) {
      this.pageType = params.pageType ?? 'profile'
      this.title = params.title ?? ''
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor('#333333')
          .width(40)
          .textAlign(TextAlign.Center)
          .margin({ left: 8 })
          .onClick(() => {
            router.back()
          })

        Text(this.title || '详情')
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

      Scroll() {
        Column() {
          if (this.pageType === 'profile') {
            this.profileContent()
          } else if (this.pageType === 'orders') {
            this.ordersContent()
          } else {
            this.settingsContent()
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  profileContent() {
    Column({ space: 12 }) {
      Column() {
        Column() {
          Text('用')
            .fontSize(32)
            .fontColor('#FFFFFF')
        }
        .width(80)
        .height(80)
        .borderRadius(40)
        .backgroundColor('#007AFF')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 24, bottom: 16 })

        Text('用户昵称')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
        Text('138****8888')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 6, bottom: 24 })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)

      Column({ space: 1 }) {
        this.infoRow('昵称', '用户昵称')
        this.infoRow('手机号', '138****8888')
        this.infoRow('会员等级', '普通会员')
      }
      .borderRadius(12)
      .clip(true)
    }
  }

  @Builder
  ordersContent() {
    Column({ space: 12 }) {
      ForEach(['智能行车记录仪', '无线车载充电器'], (name: string, index: number) => {
        Row() {
          Column({ space: 4 }) {
            Text(name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text('待发货')
              .fontSize(13)
              .fontColor('#FF6B00')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('›')
            .fontSize(20)
            .fontColor('#CCCCCC')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
      }, (name: string, index: number) => `${name}_${index}`)
    }
  }

  @Builder
  settingsContent() {
    Column({ space: 12 }) {
      Column({ space: 1 }) {
        ForEach(this.settingItems, (item: SettingItem, index: number) => {
          Row() {
            Text(item.label)
              .fontSize(16)
              .fontColor('#333333')
              .layoutWeight(1)
            if (item.value.length > 0) {
              Text(item.value)
                .fontSize(14)
                .fontColor('#999999')
            }
            Text('›')
              .fontSize(20)
              .fontColor('#CCCCCC')
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .backgroundColor('#FFFFFF')
        }, (item: SettingItem, index: number) => `${item.label}_${index}`)
      }
      .borderRadius(12)
      .clip(true)
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#333333')
        .layoutWeight(1)
      Text(value)
        .fontSize(14)
        .fontColor('#999999')
      Text('›')
        .fontSize(20)
        .fontColor('#CCCCCC')
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#FFFFFF')
  }
}
