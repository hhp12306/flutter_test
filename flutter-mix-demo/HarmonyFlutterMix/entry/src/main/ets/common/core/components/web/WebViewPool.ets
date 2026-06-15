import { DIWebController } from '../../../../diweb/DIWebController'
import { DIWebLog, DIWebLogTag } from '../../../../diweb/DIWebLog'

const TAG: string = 'WebViewPool'
const DEFAULT_MAX_SIZE: number = 3

/**
 * WebView 预热池（对齐公司 P1 优化方案，模拟 JsApiWebController 复用）
 */
export class WebViewPool {
  private static instance: WebViewPool | null = null
  private pool: DIWebController[] = []
  private maxSize: number = DEFAULT_MAX_SIZE

  static getInstance(): WebViewPool {
    if (WebViewPool.instance === null) {
      WebViewPool.instance = new WebViewPool()
    }
    return WebViewPool.instance
  }

  /** 预热：创建休眠中的 WebView Controller */
  prewarm(count: number = 1): void {
    for (let i = 0; i < count && this.pool.length < this.maxSize; i++) {
      const controller = new DIWebController()
      try {
        controller.onActive()
      } catch (_e) {
        DIWebLog.warnT(DIWebLogTag.PREWARM, '%{public}s prewarm onActive failed', TAG)
      }
      this.pool.push(controller)
      DIWebLog.infoT(DIWebLogTag.PREWARM, '%{public}s prewarm ok poolSize=%{public}s', TAG,
        String(this.pool.length))
    }
  }

  /** 从池中获取，空则返回 null（调用方新建） */
  acquire(): DIWebController | null {
    if (this.pool.length > 0) {
      const controller = this.pool.pop() ?? null
      DIWebLog.infoT(DIWebLogTag.PREWARM, '%{public}s acquire remaining=%{public}s', TAG,
        String(this.pool.length))
      return controller
    }
    DIWebLog.warnT(DIWebLogTag.PREWARM, '%{public}s acquire pool empty, need new instance', TAG)
    return null
  }

  /** 页面关闭时回收到池 */
  release(controller: DIWebController): void {
    if (this.pool.length < this.maxSize) {
      try {
        controller.onInactive()
      } catch (_e) {
        DIWebLog.warnT(DIWebLogTag.PREWARM, '%{public}s release onInactive failed', TAG)
      }
      this.pool.push(controller)
      DIWebLog.infoT(DIWebLogTag.PREWARM, '%{public}s release poolSize=%{public}s', TAG,
        String(this.pool.length))
    } else {
      DIWebLog.warnT(DIWebLogTag.PREWARM, '%{public}s release pool full, discard instance', TAG)
    }
  }

  clear(): void {
    this.pool.forEach((c: DIWebController) => {
      try {
        c.onInactive()
      } catch (_e) {
      }
    })
    this.pool = []
    DIWebLog.infoT(DIWebLogTag.PREWARM, '%{public}s cleared', TAG)
  }

  getPoolSize(): number {
    return this.pool.length
  }
}
