import { DIWebController } from '../../../../diweb/DIWebController'
import { DIWebLog, DIWebLogTag } from '../../../../diweb/DIWebLog'

export interface WebCallBindings {
  onPageBegin?: (url: string) => void
  onPageEnd?: (url: string) => void
  onTitleChange?: (title: string) => void
  onError?: (desc: string) => void
  onClose?: () => void
}

/** loadEvent 回调 */
export interface WebLoadEventCallbacks {
  begin?: () => void
  end?: () => void
}

/**
 * WebView 事件处理器（对齐公司 WebCallHandler）
 */
export class WebCallHandler {
  private multiPage: boolean = false
  private controllerAttachedFn: (() => void) | null = null
  private loadBeginFn: (() => void) | null = null
  private loadEndFn: (() => void) | null = null
  private titleChangeFn: ((title: string) => void) | null = null
  private closeFn: (() => void) | null = null
  private errorFn: ((desc: string) => void) | null = null

  supportMulti(multi: boolean): void {
    this.multiPage = multi
    DIWebLog.infoT(DIWebLogTag.VIEW, 'WebCallHandler.supportMulti=%{public}s', String(multi))
  }

  isMultiPage(): boolean {
    return this.multiPage
  }

  onControllerAttached(fn: () => void): void {
    this.controllerAttachedFn = fn
  }

  notifyControllerAttached(): void {
    if (this.controllerAttachedFn !== null) {
      this.controllerAttachedFn()
    }
  }

  loadEvent(events: WebLoadEventCallbacks): void {
    this.loadBeginFn = events.begin ?? null
    this.loadEndFn = events.end ?? null
  }

  link(): WebCallBindings {
    return {
      onPageBegin: (url: string) => {
        DIWebLog.infoT(DIWebLogTag.VIEW, 'WebCallHandler.onPageBegin url=%{public}s', url)
        if (this.loadBeginFn !== null) {
          this.loadBeginFn()
        }
      },
      onPageEnd: (url: string) => {
        DIWebLog.infoT(DIWebLogTag.VIEW, 'WebCallHandler.onPageEnd url=%{public}s', url)
        if (this.loadEndFn !== null) {
          this.loadEndFn()
        }
      },
      onTitleChange: (title: string) => {
        if (this.titleChangeFn !== null) {
          this.titleChangeFn(title)
        }
      },
      onError: (desc: string) => {
        if (this.errorFn !== null) {
          this.errorFn(desc)
        }
      },
      onClose: () => {
        if (this.closeFn !== null) {
          this.closeFn()
        }
      }
    }
  }

  setTitleHandler(fn: (title: string) => void): void {
    this.titleChangeFn = fn
  }

  setCloseHandler(fn: () => void): void {
    this.closeFn = fn
  }

  setErrorHandler(fn: (desc: string) => void): void {
    this.errorFn = fn
  }

  handleBack(controller: DIWebController | null): boolean {
    if (this.multiPage && controller !== null && controller.goBack()) {
      DIWebLog.infoT(DIWebLogTag.VIEW, 'WebCallHandler.handleBack web backward')
      return true
    }
    return false
  }
}
