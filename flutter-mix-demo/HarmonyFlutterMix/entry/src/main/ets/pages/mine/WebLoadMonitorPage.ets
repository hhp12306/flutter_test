import router from '@ohos.router'
import { DIWebLoadMonitor, DIWebLoadRecord, DIWEB_LOAD_MONITOR_VERSION_KEY } from '../../diweb/DIWebLoadMonitor'

/**
 * Web 加载监控页（原生）：展示从其它入口打开 H5 的耗时记录
 */
@Entry
@Component
struct WebLoadMonitorPage {
  @StorageLink(DIWEB_LOAD_MONITOR_VERSION_KEY) monitorVersion: number = 0

  aboutToAppear(): void {
    DIWebLoadMonitor.initStorage()
    DIWebLoadMonitor.logRecordsSummary()
  }

  private getLoadRecords(): DIWebLoadRecord[] {
    return DIWebLoadMonitor.getRecords()
  }

  private formatTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '--'
    }
    const date = new Date(timestamp)
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    const seconds = date.getSeconds().toString().padStart(2, '0')
    return `${hours}:${minutes}:${seconds}`
  }

  private loadModeColor(mode: string): string {
    if (mode === '缓存秒开') {
      return '#34C759'
    }
    if (mode === '切换加载') {
      return '#FF9500'
    }
    return '#007AFF'
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

        Text('Web 加载监控')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('清空')
          .fontSize(14)
          .fontColor('#007AFF')
          .width(40)
          .textAlign(TextAlign.Center)
          .margin({ right: 12 })
          .onClick(() => {
            DIWebLoadMonitor.clearRecords()
          })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')
      .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })

      Column({ space: 8 }) {
        Text('记录点击 → Overlay 显示 → H5 加载 → 遮罩消失 全链路耗时')
          .fontSize(13)
          .fontColor('#999999')
          .width('100%')

        Text(`共 ${this.getLoadRecords().length} 条记录`)
          .fontSize(12)
          .fontColor('#BBBBBB')
          .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .backgroundColor('#F5F5F5')

      if (this.getLoadRecords().length === 0) {
        Column({ space: 8 }) {
          Text('暂无记录')
            .fontSize(16)
            .fontColor('#999999')
          Text('请从商城、爱车、服务、测试 Tab 或 Flutter 社区页打开 H5')
            .fontSize(13)
            .fontColor('#BBBBBB')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(24)
        .backgroundColor('#F5F5F5')
      } else {
        List({ space: 10 }) {
          ForEach(this.getLoadRecords(), (record: DIWebLoadRecord, index: number) => {
            ListItem() {
              Column({ space: 6 }) {
                Row() {
                  Text(record.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(record.success ? '#333333' : '#FF3B30')
                    .layoutWeight(1)
                  Text(this.formatTime(record.clickTime))
                    .fontSize(12)
                    .fontColor('#999999')
                }
                .width('100%')

                Row({ space: 8 }) {
                  Text(record.source)
                    .fontSize(11)
                    .fontColor('#007AFF')
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .backgroundColor('#EEF4FF')
                    .borderRadius(4)
                  Text(record.loadMode)
                    .fontSize(11)
                    .fontColor(this.loadModeColor(record.loadMode))
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .backgroundColor('#F5F5F5')
                    .borderRadius(4)
                  Text(record.bridgeProfile)
                    .fontSize(11)
                    .fontColor('#5856D6')
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .backgroundColor('#F0EFFF')
                    .borderRadius(4)
                  if (record.prewarmUsed) {
                    Text('预热')
                      .fontSize(11)
                      .fontColor('#34C759')
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor('#E8F8EE')
                      .borderRadius(4)
                  }
                  Text(record.url)
                    .fontSize(12)
                    .fontColor('#888888')
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')

                Row({ space: 12 }) {
                  Text(`可见 ${record.displayReadyMs} ms`)
                    .fontSize(13)
                    .fontColor('#007AFF')
                    .fontWeight(FontWeight.Medium)
                  Text(`总计 ${record.totalReadyMs} ms`)
                    .fontSize(12)
                    .fontColor('#666666')
                }
                .width('100%')

                Row({ space: 12 }) {
                  Text(`Overlay ${record.overlayVisibleMs} ms`)
                    .fontSize(12)
                    .fontColor('#666666')
                  Text(`HTML ${record.pageLoadMs} ms`)
                    .fontSize(12)
                    .fontColor('#666666')
                  Text(`渲染 ${record.pageRenderMs} ms`)
                    .fontSize(12)
                    .fontColor('#666666')
                  Text(`Bridge ${record.bridgeInjectMs} ms`)
                    .fontSize(12)
                    .fontColor('#666666')
                  Text(`${record.bridgeScriptBytes} B`)
                    .fontSize(12)
                    .fontColor('#666666')
                }
                .width('100%')

                if (!record.success) {
                  Text(record.errorMessage)
                    .fontSize(12)
                    .fontColor('#FF3B30')
                    .width('100%')
                }
              }
              .width('100%')
              .padding(14)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
            }
          }, (record: DIWebLoadRecord, index: number) => `${this.monitorVersion}_${record.clickTime}_${index}`)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 24 })
        .backgroundColor('#F5F5F5')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
