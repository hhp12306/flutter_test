import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { DIWebRouter } from '../../diweb/DIWebRouter'
import { DIWebSession } from '../../diweb/DIWebSession'
import { DIWEB_LOCAL_DEMO_URL } from '../../diweb/DIWebTypes'
import { getBridgeScriptSizeForProfile } from '../../diweb/DIWebBridgeScript'
import { DIWebLog, DIWebLogTag } from '../../diweb/DIWebLog'

/** 远程 H5 测试地址（模拟社区帖子/详情） */
const REMOTE_H5_URL: string = 'https://m.baidu.com'

/**
 * 测试 Tab：对比 Bridge 档位、WebView 预热、Flutter 打开 H5 等场景
 */
@Component
export struct TestTab {
  @State statusTick: number = 0

  private refreshStatus(): void {
    const session = DIWebSession.getInstance()
    DIWebLog.infoT(DIWebLogTag.TEST, 'refreshStatus %{public}s', session.getDiagnosticSummary())
    this.statusTick++
  }

  private logTestAction(action: string, detail: string): void {
    const session = DIWebSession.getInstance()
    DIWebLog.infoT(DIWebLogTag.TEST, '%{public}s | %{public}s | session=%{public}s',
      action, detail, session.getDiagnosticSummary())
  }

  private getPrewarmText(): string {
    const session = DIWebSession.getInstance()
    if (!session.isPrewarmed()) {
      return '未预热'
    }
    const source = session.getPrewarmSource()
    const time = session.getPrewarmTime()
    const date = new Date(time)
    const hh = date.getHours().toString().padStart(2, '0')
    const mm = date.getMinutes().toString().padStart(2, '0')
    const ss = date.getSeconds().toString().padStart(2, '0')
    return `已预热 (${source} ${hh}:${mm}:${ss})`
  }

  build() {
    Column() {
      Row() {
        Text('DIWeb 测试')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        Blank()
        Text('刷新')
          .fontSize(14)
          .fontColor('#007AFF')
          .onClick(() => {
            this.refreshStatus()
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 8 }) {
            Text('WebView 状态')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .width('100%')
            Text(`预热: ${this.getPrewarmText()}`)
              .fontSize(13)
              .fontColor('#666666')
              .width('100%')
            Text(`Overlay 就绪: ${DIWebSession.getInstance().isOverlayHostReady() ? '是' : '否'}`)
              .fontSize(13)
              .fontColor('#666666')
              .width('100%')
            Text(`Web URL: ${DIWebSession.getInstance().getSharedController().getCurrentUrl() || 'about:blank'}`)
              .fontSize(13)
              .fontColor('#666666')
              .width('100%')
            Text(`Bridge 体积 community=${getBridgeScriptSizeForProfile('community')}B / full=${getBridgeScriptSizeForProfile('full')}B`)
              .fontSize(12)
              .fontColor('#999999')
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)

          this.sectionTitle('预热')
          Button('手动预热 WebView（模拟进入社区 Tab）')
            .width('100%')
            .height(44)
            .fontSize(14)
            .onClick(() => {
              this.logTestAction('prewarm', '手动预热')
              DIWebSession.getInstance().prewarmWeb('测试Tab')
              promptAction.showToast({ message: 'WebView 已预热', duration: 1500 })
              this.refreshStatus()
            })

          this.sectionTitle('社区场景（精简 Bridge）')
          Button('模拟 Flutter 打开远程 H5')
            .width('100%')
            .height(44)
            .fontSize(14)
            .onClick(() => {
              this.logTestAction('openH5', `remote community url=${REMOTE_H5_URL}`)
              DIWebRouter.open(REMOTE_H5_URL, {
                title: '社区帖子详情',
                source: 'Flutter社区',
                bridgeProfile: 'community'
              })
            })
          Button('打开本地 Demo（community Bridge）')
            .width('100%')
            .height(44)
            .fontSize(14)
            .backgroundColor('#F0F0F0')
            .fontColor('#333333')
            .onClick(() => {
              this.logTestAction('openH5', `local community url=${DIWEB_LOCAL_DEMO_URL}`)
              DIWebRouter.open(DIWEB_LOCAL_DEMO_URL, {
                title: '本地 Demo',
                source: '测试Tab',
                bridgeProfile: 'community'
              })
            })

          this.sectionTitle('压测对比（全量 Bridge 93 API）')
          Button('打开远程 H5（full Bridge）')
            .width('100%')
            .height(44)
            .fontSize(14)
            .onClick(() => {
              this.logTestAction('openH5', `remote full url=${REMOTE_H5_URL}`)
              DIWebRouter.open(REMOTE_H5_URL, {
                title: '远程 H5 压测',
                source: '测试Tab',
                bridgeProfile: 'full'
              })
            })
          Button('打开本地 Demo（full Bridge）')
            .width('100%')
            .height(44)
            .fontSize(14)
            .backgroundColor('#F0F0F0')
            .fontColor('#333333')
            .onClick(() => {
              this.logTestAction('openH5', `local full url=${DIWEB_LOCAL_DEMO_URL}`)
              DIWebRouter.open(DIWEB_LOCAL_DEMO_URL, {
                title: '本地 Demo 压测',
                source: '测试Tab',
                bridgeProfile: 'full'
              })
            })

          this.sectionTitle('监控')
          Button('查看 Web 加载监控')
            .width('100%')
            .height(44)
            .fontSize(14)
            .backgroundColor('#34C759')
            .onClick(() => {
              this.logTestAction('navigate', 'WebLoadMonitorPage')
              router.pushUrl({ url: 'pages/mine/WebLoadMonitorPage' })
            })

          Text('提示：远程页（如百度）在模拟器上子资源常报 -100/-32，已忽略；建议先用「本地 Demo」对比 Bridge 档位')
            .fontSize(12)
            .fontColor('#BBBBBB')
            .width('100%')
            .margin({ top: 8, bottom: 24 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor('#666666')
      .width('100%')
      .margin({ top: 4 })
  }
}
