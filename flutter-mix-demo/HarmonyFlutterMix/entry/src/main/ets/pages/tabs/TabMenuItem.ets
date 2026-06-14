/** Tab 页通用菜单项 */
export interface TabMenuItemData {
  title: string
  subtitle: string
  h5Url: string
  h5Title: string
}

@Component
export struct TabMenuItem {
  @Prop item: TabMenuItemData = { title: '', subtitle: '', h5Url: '', h5Title: '' }
  onTap?: (item: TabMenuItemData) => void

  build() {
    Row() {
      Column({ space: 4 }) {
        Text(this.item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        Text(this.item.subtitle)
          .fontSize(13)
          .fontColor('#999999')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(20)
        .fontColor('#CCCCCC')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      if (this.onTap) {
        this.onTap(this.item)
      }
    })
  }
}
