import router from '@ohos.router'
import { DIWebLog, DIWebLogTag } from '../../../diweb/DIWebLog'
import { WebFlowTracer } from '../utils/WebFlowTracer'

export enum RouterType {
  PUSH_PATH = 'push',
  REPLACE = 'replace'
}

export enum CommonBuilderName {
  WEB_BRIDGE = 'WebPageBridge'
}

const WEB_BRIDGE_PAGE: string = 'pages/DIWebPage'

/**
 * 模拟公司 DiNavigation 路由构建器
 */
export class DiNavigation {
  private builderName: string = ''
  private params: Record<string, Object> = {}
  private routeType: RouterType = RouterType.PUSH_PATH

  static getInstance(): DiNavigation {
    return new DiNavigation()
  }

  build(name: string): DiNavigation {
    this.builderName = name
    return this
  }

  withParams(params: Record<string, Object>): DiNavigation {
    this.params = params
    return this
  }

  withRouterType(routeType: RouterType): DiNavigation {
    this.routeType = routeType
    return this
  }

  navigation(): void {
    DIWebLog.infoT(DIWebLogTag.ROUTER,
      'DiNavigation.navigation builder=%{public}s routeType=%{public}s params=%{public}s',
      this.builderName, this.routeType, JSON.stringify(this.params))
    WebFlowTracer.step('DiNavigation', `router.pushUrl -> ${WEB_BRIDGE_PAGE} (WebPageBridge)`)
    const target = WEB_BRIDGE_PAGE
    const push = this.routeType === RouterType.REPLACE
      ? router.replaceUrl({ url: target, params: this.params })
      : router.pushUrl({ url: target, params: this.params })
    push.then(() => {
      DIWebLog.infoT(DIWebLogTag.ROUTER, 'DiNavigation pushUrl SUCCESS url=%{public}s', target)
      WebFlowTracer.step('DiNavigation', 'pushUrl SUCCESS 页面已入栈')
    }).catch((err: Error) => {
      DIWebLog.errorT(DIWebLogTag.ROUTER, 'DiNavigation pushUrl FAILED url=%{public}s err=%{public}s',
        target, err.message ?? String(err))
      WebFlowTracer.end(`pushUrl FAIL: ${err.message ?? String(err)}`)
    })
  }

  getParams(): Record<string, Object> {
    const fromRouter = router.getParams() as Record<string, Object>
    if (fromRouter !== null && fromRouter !== undefined && Object.keys(fromRouter).length > 0) {
      return fromRouter
    }
    return {}
  }
}
