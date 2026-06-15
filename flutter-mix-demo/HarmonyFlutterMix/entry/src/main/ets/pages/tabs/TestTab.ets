import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { DIWebRouter } from '../../diweb/DIWebRouter'
import { DIWebSession } from '../../diweb/DIWebSession'
import { WebViewPool } from '../../common/core/components/web/WebViewPool'
import { DIWEB_LOCAL_DEMO_URL } from '../../diweb/DIWebTypes'
import { getBridgeScriptSizeForProfile } from '../../diweb/DIWebBridgeScript'
import { DIWebLog, DIWebLogTag } from '../../diweb/DIWebLog'
import { H5TestUrls, H5TestPost } from '../../common/core/components/web/H5TestUrls'

const REMOTE_H5_URL: string = 'https://m.baidu.com'

/**
 * 测试 Tab：对比「公司路由 WebPageBridge」vs「Overlay 优化」vs WebViewPool
 */
@Component
export struct TestTab {
  @State statusTick: number = 0

  private refreshStatus(): void {
    this.statusTick++
  }

  private logTestAction(action: string, detail: string): void {
    const session = DIWebSession.getInstance()
    DIWebLog.infoT(DIWebLogTag.TEST, '%{public}s | %{public}s | pool=%{public}s session=%{public}s',
      action, detail, String(WebViewPool.getInstance().getPoolSize()), session.getDiagnosticSummary())
  }

  build() {
    Column() {
      Row() {
        Text('H5 性能对比测试')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        Blank()
        Text('刷新')
          .fontSize(14)
          .fontColor('#007AFF')
          .onClick(() => this.refreshStatus())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text('当前状态')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            Text(`WebViewPool: ${WebViewPool.getInstance().getPoolSize()} 个`)
              .fontSize(13).fontColor('#666666').width('100%')
            Text(`Overlay 就绪: ${DIWebSession.getInstance().isOverlayHostReady() ? '是' : '否'}`)
              .fontSize(13).fontColor('#666666').width('100%')
          Text('HiLog 过滤: DIWeb-E2E')
              .fontSize(12).fontColor('#007AFF').width('100%')
            Text('成功标志: 看到 #N [END] ✅ 公司路由链路成功')
              .fontSize(12).fontColor('#34C759').width('100%')
          }
          .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(12)

          this.sectionTitle('WebViewPool（公司 P1 优化）')
          Button('预热 WebViewPool (2个)')
            .width('100%').height(44).fontSize(14)
            .onClick(() => {
              WebViewPool.getInstance().prewarm(2)
              promptAction.showToast({ message: 'WebViewPool 已预热', duration: 1500 })
              this.refreshStatus()
            })
          Button('清空 WebViewPool')
            .width('100%').height(44).fontSize(14)
            .backgroundColor('#F0F0F0').fontColor('#333333')
            .onClick(() => {
              WebViewPool.getInstance().clear()
              this.refreshStatus()
            })

          this.sectionTitle('UAT 社区帖子（真实 H5）')
          Text('路由: pages/DIWebPage (WebPageBridge 逻辑)')
            .fontSize(12).fontColor('#999999').width('100%')
          ForEach(H5TestUrls.UAT_POSTS, (post: H5TestPost) => {
            Button(`公司路由：${post.label}`)
              .width('100%').height(44).fontSize(13)
              .onClick(() => {
                this.logTestAction('router', `uat ${post.label}`)
                DIWebRouter.open(post.url, {
                  title: post.label,
                  source: 'UAT社区',
                  bridgeProfile: 'community'
                })
              })
          }, (post: H5TestPost) => post.label)

          Button('Overlay：UAT 帖子 pid=2406463')
            .width('100%').height(44).fontSize(13)
            .backgroundColor('#E8F4FF')
            .onClick(() => {
              const post = H5TestUrls.UAT_POSTS[0]
              DIWebSession.getInstance().prewarmWeb('测试Tab-Overlay')
              DIWebRouter.open(post.url, {
                title: post.label,
                source: 'UAT-Overlay',
                bridgeProfile: 'community',
                useOverlay: true
              })
            })

          this.sectionTitle('公司路由模式（默认，模拟 dilink）')
          Text('NavigateService → CoreUtils → RouterManager → pages/DIWebPage')
            .fontSize(12).fontColor('#999999').width('100%')
          Button('公司路由：远程 H5 (community)')
            .width('100%').height(44).fontSize(14)
            .onClick(() => {
              this.logTestAction('router', `remote community ${REMOTE_H5_URL}`)
              DIWebRouter.open(REMOTE_H5_URL, {
                title: '社区帖子', source: 'Flutter社区', bridgeProfile: 'community'
              })
            })
          Button('公司路由：本地 Demo (community)')
            .width('100%').height(44).fontSize(14)
            .backgroundColor('#F0F0F0').fontColor('#333333')
            .onClick(() => {
              this.logTestAction('router', `local community ${DIWEB_LOCAL_DEMO_URL}`)
              DIWebRouter.open(DIWEB_LOCAL_DEMO_URL, {
                title: '本地 Demo', source: '测试Tab', bridgeProfile: 'community'
              })
            })
          Button('公司路由：full Bridge 压测')
            .width('100%').height(44).fontSize(14)
            .onClick(() => {
              DIWebRouter.open(DIWEB_LOCAL_DEMO_URL, {
                title: '压测', source: '测试Tab', bridgeProfile: 'full'
              })
            })

          this.sectionTitle('Overlay 优化模式（Demo 方案）')
          Text('useOverlay=true → DIWebSession.openInOverlay')
            .fontSize(12).fontColor('#999999').width('100%')
          Button('Overlay：远程 H5 (community)')
            .width('100%').height(44).fontSize(14)
            .backgroundColor('#E8F4FF')
            .onClick(() => {
              DIWebSession.getInstance().prewarmWeb('测试Tab-Overlay')
              DIWebRouter.open(REMOTE_H5_URL, {
                title: 'Overlay远程', source: 'Overlay测试',
                bridgeProfile: 'community', useOverlay: true
              })
            })
          Button('Overlay：本地 Demo 秒开对比')
            .width('100%').height(44).fontSize(14)
            .backgroundColor('#E8F4FF')
            .onClick(() => {
              DIWebSession.getInstance().prewarmWeb('测试Tab-Overlay')
              DIWebRouter.open(DIWEB_LOCAL_DEMO_URL, {
                title: 'Overlay本地', source: 'Overlay测试',
                bridgeProfile: 'community', useOverlay: true
              })
            })

          this.sectionTitle('监控')
          Button('查看 Web 加载监控')
            .width('100%').height(44).fontSize(14).backgroundColor('#34C759')
            .onClick(() => router.pushUrl({ url: 'pages/mine/WebLoadMonitorPage' }))

          Text('对比建议：先测「公司路由」再测「Overlay」，查看监控页 displayReadyMs 差异')
            .fontSize(12).fontColor('#BBBBBB').width('100%').margin({ top: 4 })
          Text('DevEco → HiLog 窗口搜索 DIWeb-E2E，成功应看到 [END] ✅ 公司路由链路成功')
            .fontSize(11).fontColor('#CCCCCC').width('100%').margin({ top: 8, bottom: 24 })
        }
        .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      }
      .layoutWeight(1).backgroundColor('#F5F5F5')
    }
    .width('100%').height('100%')
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#666666')
      .width('100%').margin({ top: 4 })
  }
}
