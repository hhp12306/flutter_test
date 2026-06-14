import hilog from '@ohos.hilog'

/** HiLog 域，过滤 tag=DIWeb* 可查看全部 Web 相关日志 */
const DOMAIN: number = 0xD100
const DEFAULT_TAG: string = 'DIWeb'

/** 子模块 tag，HiLog 可按 tag 单独过滤 */
export class DIWebLogTag {
  static readonly ROUTER: string = 'DIWeb-Router'
  static readonly SESSION: string = 'DIWeb-Session'
  static readonly OVERLAY: string = 'DIWeb-Overlay'
  static readonly VIEW: string = 'DIWeb-View'
  static readonly PAGE: string = 'DIWeb-Page'
  static readonly INDEX: string = 'DIWeb-Index'
  static readonly NAV: string = 'DIWeb-Nav'
  static readonly MONITOR: string = 'DIWeb-Monitor'
  /** WebView 预热 */
  static readonly PREWARM: string = 'DIWeb-Prewarm'
  /** Bridge 脚本注入 */
  static readonly BRIDGE: string = 'DIWeb-Bridge'
  /** Flutter MethodChannel */
  static readonly CHANNEL: string = 'DIWeb-Channel'
  /** 测试 Tab 操作 */
  static readonly TEST: string = 'DIWeb-Test'
}

/** 导航链路追踪：一次 open 对应一个 navId，便于排查「跳两层」 */
export class DIWebNavTrace {
  private static seq: number = 0

  static begin(action: string, detail: string): number {
    const id = ++DIWebNavTrace.seq
    DIWebLog.infoT(DIWebLogTag.NAV, '#%{public}d BEGIN %{public}s | %{public}s',
      String(id), action, detail)
    return id
  }

  static step(navId: number, step: string, detail: string): void {
    DIWebLog.infoT(DIWebLogTag.NAV, '#%{public}d STEP %{public}s | %{public}s',
      String(navId), step, detail)
  }

  static end(navId: number, result: string): void {
    DIWebLog.infoT(DIWebLogTag.NAV, '#%{public}d END %{public}s',
      String(navId), result)
  }

  static warn(navId: number, detail: string): void {
    DIWebLog.warnT(DIWebLogTag.NAV, '#%{public}d WARN %{public}s',
      String(navId), detail)
  }
}

export class DIWebLog {
  static info(msg: string, ...args: string[]): void {
    DIWebLog.write('info', DEFAULT_TAG, msg, args)
  }

  static warn(msg: string, ...args: string[]): void {
    DIWebLog.write('warn', DEFAULT_TAG, msg, args)
  }

  static error(msg: string, ...args: string[]): void {
    DIWebLog.write('error', DEFAULT_TAG, msg, args)
  }

  static debug(msg: string, ...args: string[]): void {
    DIWebLog.write('debug', DEFAULT_TAG, msg, args)
  }

  static infoT(tag: string, msg: string, ...args: string[]): void {
    DIWebLog.write('info', tag, msg, args)
  }

  static warnT(tag: string, msg: string, ...args: string[]): void {
    DIWebLog.write('warn', tag, msg, args)
  }

  static errorT(tag: string, msg: string, ...args: string[]): void {
    DIWebLog.write('error', tag, msg, args)
  }

  static debugT(tag: string, msg: string, ...args: string[]): void {
    DIWebLog.write('debug', tag, msg, args)
  }

  private static write(level: string, tag: string, msg: string, args: string[]): void {
    const text = `[${level}] ${msg}`
    if (args.length > 0) {
      if (level === 'info') {
        hilog.info(DOMAIN, tag, text, ...args)
      } else if (level === 'warn') {
        hilog.warn(DOMAIN, tag, text, ...args)
      } else if (level === 'error') {
        hilog.error(DOMAIN, tag, text, ...args)
      } else {
        hilog.debug(DOMAIN, tag, text, ...args)
      }
    } else {
      if (level === 'info') {
        hilog.info(DOMAIN, tag, text)
      } else if (level === 'warn') {
        hilog.warn(DOMAIN, tag, text)
      } else if (level === 'error') {
        hilog.error(DOMAIN, tag, text)
      } else {
        hilog.debug(DOMAIN, tag, text)
      }
    }
  }
}
