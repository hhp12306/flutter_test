import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { DIWeb } from '../diweb/DIWeb'
import { DIWebController } from '../diweb/DIWebController'
import { DIWebRouter } from '../diweb/DIWebRouter'
import { DIWEB_LOCAL_DEMO_URL } from '../diweb/DIWebTypes'
import { DIWebLog } from '../diweb/DIWebLog'

interface TestCaseItem {
  title: string
  desc: string
  action: () => void
}

/**
 * DIWeb 测试页：进入后直接展示本地 H5 Demo
 */
@Entry
@Component
struct DIWebTestPage {
  @State pageTitle: string = 'DIWeb 测试'
  @State showList: boolean = false
  @State inlineUrl: string = DIWEB_LOCAL_DEMO_URL
  @State inlineTitle: string = '本地 Demo'
  private readonly remoteDemoUrl: string = 'https://www.baidu.com'
  private testCases: TestCaseItem[] = []

  aboutToAppear(): void {
    DIWebLog.info('DIWebTestPage aboutToAppear, inlineUrl=%{public}s', this.inlineUrl)
    this.initTestCases()
  }

  private initTestCases(): void {
    this.testCases = [
      {
        title: '本地 Demo 页（二级页打开）',
        desc: '通过 DIWebPage 打开本地 H5',
        action: () => {
          DIWebRouter.open(DIWEB_LOCAL_DEMO_URL, { title: '本地 Demo', useOverlay: false })
        }
      },
      {
        title: '远程 H5 页面',
        desc: '加载百度，验证网络访问',
        action: () => {
          DIWebRouter.open(this.remoteDemoUrl, { title: '远程 H5', useOverlay: false })
        }
      },
      {
        title: '无导航栏打开',
        desc: '全屏 H5，隐藏顶部导航栏',
        action: () => {
          DIWebRouter.open(DIWEB_LOCAL_DEMO_URL, {
            title: '全屏 Demo',
            showNavBar: false,
            useOverlay: false
          })
        }
      },
      {
        title: '切换回本地 Demo',
        desc: '当前页内嵌 Web 重新加载本地 Demo',
        action: () => {
          this.inlineUrl = DIWEB_LOCAL_DEMO_URL
          this.inlineTitle = '本地 Demo'
          this.showList = false
        }
      }
    ]
  }

  private runTestCase(item: TestCaseItem): void {
    DIWebLog.info('DIWebTestPage runTestCase: %{public}s', item.title)
    promptAction.showToast({ message: `正在打开: ${item.title}`, duration: 1500 })
    item.action()
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
            if (this.showList) {
              this.showList = false
            } else {
              router.back()
            }
          })

        Text(this.showList ? '测试场景' : this.inlineTitle)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('更多')
          .fontSize(14)
          .fontColor('#007AFF')
          .width(40)
          .textAlign(TextAlign.Center)
          .margin({ right: 12 })
          .onClick(() => {
            this.showList = true
          })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')
      .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })

      if (this.showList) {
        Scroll() {
          Column({ space: 12 }) {
            Text('选择测试场景')
              .fontSize(14)
              .fontColor('#999999')
              .width('100%')
              .margin({ top: 16, bottom: 4 })

            ForEach(this.testCases, (item: TestCaseItem, index: number) => {
              Column({ space: 6 }) {
                Text(item.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333333')
                  .width('100%')

                Text(item.desc)
                  .fontSize(13)
                  .fontColor('#888888')
                  .width('100%')
              }
              .width('100%')
              .padding(16)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .onClick(() => {
                this.runTestCase(item)
              })
            }, (item: TestCaseItem, index: number) => `${item.title}_${index}`)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .backgroundColor('#F5F5F5')
      } else {
        DIWeb({
          url: this.inlineUrl,
          useSharedController: false,
          onControllerReady: (ctrl: DIWebController) => {
            ctrl.registerHandler('getUserInfo', () => {
              return {
                'userId': '10001',
                'name': 'TestUser',
                'from': 'DIWebTestPage'
              }
            })
          },
          onTitleChange: (title: string) => {
            if (title) {
              this.inlineTitle = title
            }
          }
        })
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
