import { DIWebLog, DIWebLogTag } from './DIWebLog'
import { getBridgeScriptSizeForProfile } from './DIWebBridgeScript'
import { DIWebBridgeProfile } from './DIWebTypes'

/** 加载方式 */
export type DIWebLoadMode = '首次加载' | '切换加载' | '同URL重载' | '缓存秒开'

/** 单次 Web 页面加载监控记录 */
export interface DIWebLoadRecord {
  title: string
  url: string
  source: string
  loadMode: string
  clickTime: number
  overlayVisibleTime: number
  pageBeginTime: number
  pageEndTime: number
  bridgeReadyTime: number
  displayReadyTime: number
  /** 点击 → Overlay 显示 */
  overlayVisibleMs: number
  /** 点击 → onPageBegin */
  clickToBeginMs: number
  /** onPageBegin → onPageEnd */
  pageRenderMs: number
  /** 点击 → onPageEnd（HTML 加载完） */
  pageLoadMs: number
  bridgeInjectMs: number
  /** Bridge 注入档位 */
  bridgeProfile: string
  /** 注入脚本体积（bytes） */
  bridgeScriptBytes: number
  /** 打开前是否已预热 WebView */
  prewarmUsed: boolean
  /** 点击 → Bridge 注入完成 */
  totalReadyMs: number
  /** 点击 → 用户可见（遮罩消失 / 缓存复用） */
  displayReadyMs: number
  success: boolean
  errorMessage: string
}

interface PendingLoadSession {
  sessionId: number
  title: string
  url: string
  source: string
  loadMode: string
  bridgeProfile: DIWebBridgeProfile
  prewarmUsed: boolean
  clickTime: number
  overlayVisibleTime: number
  pageBeginTime: number
  pageEndTime: number
  /** Overlay 遮罩消失时刻，0 表示尚未可见 */
  displayReadyTime: number
}

const STORAGE_VERSION_KEY: string = 'diwebLoadMonitorVersion'
const MAX_RECORDS: number = 30

/**
 * Web 页面加载耗时监控：从点击到 H5 可见（含 Overlay 遮罩、Bridge 注入）
 */
export class DIWebLoadMonitor {
  private static records: DIWebLoadRecord[] = []
  private static pending: PendingLoadSession | null = null
  private static sessionSeq: number = 0

  /** 点击打开 Web */
  static markClick(url: string, title: string, source: string = '未知', loadMode: string = '首次加载',
    bridgeProfile: DIWebBridgeProfile = 'full', prewarmUsed: boolean = false): void {
    DIWebLoadMonitor.abandonPending('新点击覆盖')
    const sessionId = ++DIWebLoadMonitor.sessionSeq
    const session: PendingLoadSession = {
      sessionId: sessionId,
      title: title.length > 0 ? title : url,
      url: url,
      source: source,
      loadMode: loadMode,
      bridgeProfile: bridgeProfile,
      prewarmUsed: prewarmUsed,
      clickTime: Date.now(),
      overlayVisibleTime: 0,
      pageBeginTime: 0,
      pageEndTime: 0,
      displayReadyTime: 0
    }
    DIWebLoadMonitor.pending = session
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s CLICK BEGIN | mode=%{public}s source=%{public}s bridge=%{public}s prewarm=%{public}s title=%{public}s url=%{public}s',
      String(sessionId), loadMode, source, bridgeProfile, String(prewarmUsed), session.title, url)
  }

  /** Overlay 变为可见 */
  static markOverlayVisible(): void {
    if (DIWebLoadMonitor.pending === null) {
      DIWebLog.warnT(DIWebLogTag.MONITOR, 'markOverlayVisible skip: no pending session')
      return
    }
    const pending = DIWebLoadMonitor.pending
    pending.overlayVisibleTime = Date.now()
    const cost = pending.overlayVisibleTime - pending.clickTime
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s STEP overlayVisible | +%{public}s ms from click',
      String(pending.sessionId), String(cost))
  }

  /** Web onPageBegin（跳过 about:blank） */
  static markPageBegin(pageUrl: string): void {
    if (DIWebLoadMonitor.pending === null) {
      DIWebLog.debugT(DIWebLogTag.MONITOR, 'markPageBegin skip: no pending url=%{public}s', pageUrl)
      return
    }
    if (DIWebLoadMonitor.isBlankUrl(pageUrl)) {
      DIWebLog.debugT(DIWebLogTag.MONITOR, 'markPageBegin skip: blank url=%{public}s', pageUrl)
      return
    }
    const pending = DIWebLoadMonitor.pending
    pending.pageBeginTime = Date.now()
    const fromClick = pending.pageBeginTime - pending.clickTime
    const sinceOverlay = pending.overlayVisibleTime > 0
      ? pending.pageBeginTime - pending.overlayVisibleTime : -1
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s STEP pageBegin | +%{public}s ms from click sinceOverlay=%{public}s ms url=%{public}s',
      String(pending.sessionId), String(fromClick), String(sinceOverlay), pageUrl)
  }

  /** Web onPageEnd（Bridge 注入前） */
  static markPageEnd(pageUrl: string): void {
    if (DIWebLoadMonitor.pending === null) {
      DIWebLog.debugT(DIWebLogTag.MONITOR, 'markPageEnd skip: no pending url=%{public}s', pageUrl)
      return
    }
    if (DIWebLoadMonitor.isBlankUrl(pageUrl)) {
      DIWebLog.debugT(DIWebLogTag.MONITOR, 'markPageEnd skip: blank url=%{public}s', pageUrl)
      return
    }
    const pending = DIWebLoadMonitor.pending
    pending.pageEndTime = Date.now()
    const pageLoadMs = pending.pageEndTime - pending.clickTime
    const renderMs = pending.pageEndTime - pending.pageBeginTime
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s STEP pageEnd | +%{public}s ms from click render=%{public}s ms url=%{public}s',
      String(pending.sessionId), String(pageLoadMs), String(renderMs), pageUrl)
  }

  /** Bridge 注入完成 */
  static markReady(bridgeInjectMs: number, success: boolean, errorMessage: string = ''): void {
    const pending = DIWebLoadMonitor.pending
    if (pending === null) {
      DIWebLog.warnT(DIWebLogTag.MONITOR, 'markReady skip: no pending injectMs=%{public}s success=%{public}s',
        String(bridgeInjectMs), String(success))
      return
    }
    if (DIWebLoadMonitor.isBlankUrl(pending.url)) {
      DIWebLog.warnT(DIWebLogTag.MONITOR, 'markReady skip: blank pending url=%{public}s', pending.url)
      return
    }
    const sessionId = pending.sessionId
    const bridgeReadyTime = Date.now()
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s STEP bridgeInject | +%{public}s ms cost=%{public}s ms',
      String(sessionId), String(bridgeReadyTime - pending.clickTime), String(bridgeInjectMs))
    const pageBeginTime = pending.pageBeginTime > 0 ? pending.pageBeginTime : bridgeReadyTime
    const pageEndTime = pending.pageEndTime > 0 ? pending.pageEndTime : bridgeReadyTime
    const overlayVisibleTime = pending.overlayVisibleTime > 0 ? pending.overlayVisibleTime : pending.clickTime
    const displayReadyTime = pending.displayReadyTime > 0 ? pending.displayReadyTime : bridgeReadyTime
    const record: DIWebLoadRecord = {
      title: pending.title,
      url: pending.url,
      source: pending.source,
      loadMode: pending.loadMode,
      clickTime: pending.clickTime,
      overlayVisibleTime: overlayVisibleTime,
      pageBeginTime: pageBeginTime,
      pageEndTime: pageEndTime,
      bridgeReadyTime: bridgeReadyTime,
      displayReadyTime: displayReadyTime,
      overlayVisibleMs: overlayVisibleTime - pending.clickTime,
      clickToBeginMs: pageBeginTime - pending.clickTime,
      pageRenderMs: pageEndTime - pageBeginTime,
      pageLoadMs: pageEndTime - pending.clickTime,
      bridgeInjectMs: bridgeInjectMs,
      bridgeProfile: pending.bridgeProfile,
      bridgeScriptBytes: getBridgeScriptSizeForProfile(pending.bridgeProfile),
      prewarmUsed: pending.prewarmUsed,
      totalReadyMs: bridgeReadyTime - pending.clickTime,
      displayReadyMs: displayReadyTime - pending.clickTime,
      success: success,
      errorMessage: errorMessage
    }
    DIWebLoadMonitor.saveRecord(record, sessionId)
    DIWebLoadMonitor.logReport(record, sessionId)
  }

  /** 缓存秒开：Web 未重新 loadUrl，直接复用 */
  static markCacheReuse(): void {
    const pending = DIWebLoadMonitor.pending
    if (pending === null) {
      DIWebLog.debugT(DIWebLogTag.MONITOR, 'markCacheReuse skip: no pending')
      return
    }
    if (pending.loadMode !== '缓存秒开') {
      DIWebLog.debugT(DIWebLogTag.MONITOR, 'markCacheReuse skip: loadMode=%{public}s', pending.loadMode)
      return
    }
    const sessionId = pending.sessionId
    const now = Date.now()
    const overlayVisibleTime = pending.overlayVisibleTime > 0 ? pending.overlayVisibleTime : now
    const totalMs = now - pending.clickTime
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s STEP cacheReuse | +%{public}s ms from click (no reload)',
      String(sessionId), String(totalMs))
    const record: DIWebLoadRecord = {
      title: pending.title,
      url: pending.url,
      source: pending.source,
      loadMode: '缓存秒开',
      clickTime: pending.clickTime,
      overlayVisibleTime: overlayVisibleTime,
      pageBeginTime: 0,
      pageEndTime: 0,
      bridgeReadyTime: now,
      displayReadyTime: now,
      overlayVisibleMs: overlayVisibleTime - pending.clickTime,
      clickToBeginMs: 0,
      pageRenderMs: 0,
      pageLoadMs: 0,
      bridgeInjectMs: 0,
      bridgeProfile: pending.bridgeProfile,
      bridgeScriptBytes: getBridgeScriptSizeForProfile(pending.bridgeProfile),
      prewarmUsed: pending.prewarmUsed,
      totalReadyMs: totalMs,
      displayReadyMs: totalMs,
      success: true,
      errorMessage: ''
    }
    DIWebLoadMonitor.saveRecord(record, sessionId)
    DIWebLoadMonitor.logReport(record, sessionId)
  }

  /** Overlay 遮罩消失：写入当前 pending，markReady 归档时使用 */
  static markOverlayContentVisible(): void {
    if (DIWebLoadMonitor.pending === null) {
      DIWebLog.warnT(DIWebLogTag.MONITOR, 'markOverlayContentVisible skip: no pending session')
      return
    }
    const pending = DIWebLoadMonitor.pending
    pending.displayReadyTime = Date.now()
    const fromClick = pending.displayReadyTime - pending.clickTime
    const sincePageEnd = pending.pageEndTime > 0 ? pending.displayReadyTime - pending.pageEndTime : -1
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s STEP contentVisible | +%{public}s ms from click sincePageEnd=%{public}s ms mode=%{public}s url=%{public}s',
      String(pending.sessionId), String(fromClick), String(sincePageEnd), pending.loadMode, pending.url)
  }

  static markDisplayReady(): void {
    DIWebLoadMonitor.markOverlayContentVisible()
  }

  static markFailed(errorMessage: string): void {
    if (DIWebLoadMonitor.pending === null) {
      DIWebLog.warnT(DIWebLogTag.MONITOR, 'markFailed skip: no pending err=%{public}s', errorMessage)
      return
    }
    DIWebLog.errorT(DIWebLogTag.MONITOR,
      '#%{public}s FAILED | err=%{public}s url=%{public}s',
      String(DIWebLoadMonitor.pending.sessionId), errorMessage, DIWebLoadMonitor.pending.url)
    DIWebLoadMonitor.markReady(0, false, errorMessage)
  }

  /** 打开监控页时打印历史记录摘要 */
  static logRecordsSummary(): void {
    const list = DIWebLoadMonitor.records
    DIWebLog.infoT(DIWebLogTag.MONITOR, 'SUMMARY totalRecords=%{public}s pending=%{public}s',
      String(list.length), DIWebLoadMonitor.pending !== null ? 'yes' : 'no')
    list.forEach((record: DIWebLoadRecord, index: number) => {
      DIWebLog.infoT(DIWebLogTag.MONITOR,
        'SUMMARY[%{public}s] %{public}s | mode=%{public}s bridge=%{public}s prewarm=%{public}s visible=%{public}sms html=%{public}sms bridge=%{public}sms | %{public}s',
        String(index), record.success ? 'OK' : 'FAIL', record.loadMode, record.bridgeProfile,
        String(record.prewarmUsed), String(record.displayReadyMs), String(record.pageLoadMs),
        String(record.bridgeInjectMs), record.title)
    })
  }

  static getRecords(): DIWebLoadRecord[] {
    return DIWebLoadMonitor.records
  }

  static clearRecords(): void {
    const count = DIWebLoadMonitor.records.length
    DIWebLoadMonitor.records = []
    DIWebLoadMonitor.pending = null
    DIWebLoadMonitor.notifyUpdate()
    DIWebLog.infoT(DIWebLogTag.MONITOR, 'CLEAR removed=%{public}s records', String(count))
  }

  static initStorage(): void {
    AppStorage.setOrCreate(STORAGE_VERSION_KEY, 0)
  }

  private static saveRecord(record: DIWebLoadRecord, sessionId: number): void {
    DIWebLoadMonitor.records.unshift(record)
    if (DIWebLoadMonitor.records.length > MAX_RECORDS) {
      DIWebLoadMonitor.records.pop()
    }
    DIWebLoadMonitor.pending = null
    DIWebLoadMonitor.notifyUpdate()
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s SAVED | totalRecords=%{public}s success=%{public}s',
      String(sessionId), String(DIWebLoadMonitor.records.length), String(record.success))
  }

  /** 单次加载最终报告，便于对比 prewarm / bridge 档位效果 */
  private static logReport(record: DIWebLoadRecord, sessionId: number): void {
    const endToVisible = record.displayReadyTime > 0 && record.pageEndTime > 0
      ? record.displayReadyTime - record.pageEndTime : 0
    const endToBridge = record.bridgeReadyTime > 0 && record.pageEndTime > 0
      ? record.bridgeReadyTime - record.pageEndTime : 0
    const status = record.success ? 'OK' : 'FAIL'
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s REPORT %{public}s | source=%{public}s mode=%{public}s bridge=%{public}s prewarm=%{public}s',
      String(sessionId), status, record.source, record.loadMode, record.bridgeProfile,
      String(record.prewarmUsed))
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s REPORT 耗时 | 可见=%{public}sms HTML=%{public}sms 渲染=%{public}sms Bridge=%{public}sms Overlay=%{public}sms 总计=%{public}sms',
      String(sessionId), String(record.displayReadyMs), String(record.pageLoadMs),
      String(record.pageRenderMs), String(record.bridgeInjectMs), String(record.overlayVisibleMs),
      String(record.totalReadyMs))
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s REPORT 分段 | 点击→Overlay=%{public}sms 点击→Begin=%{public}sms Begin→End=%{public}sms End→可见=%{public}sms End→Bridge=%{public}sms',
      String(sessionId), String(record.overlayVisibleMs), String(record.clickToBeginMs),
      String(record.pageRenderMs), String(endToVisible), String(endToBridge))
    DIWebLog.infoT(DIWebLogTag.MONITOR,
      '#%{public}s REPORT 脚本 | profile=%{public}s bytes=%{public}s title=%{public}s url=%{public}s',
      String(sessionId), record.bridgeProfile, String(record.bridgeScriptBytes),
      record.title, record.url)
    if (!record.success && record.errorMessage.length > 0) {
      DIWebLog.errorT(DIWebLogTag.MONITOR, '#%{public}s REPORT error=%{public}s',
        String(sessionId), record.errorMessage)
    }
  }

  private static abandonPending(reason: string): void {
    if (DIWebLoadMonitor.pending !== null) {
      DIWebLog.warnT(DIWebLogTag.MONITOR,
        '#%{public}s ABANDON reason=%{public}s url=%{public}s',
        String(DIWebLoadMonitor.pending.sessionId), reason, DIWebLoadMonitor.pending.url)
      DIWebLoadMonitor.pending = null
    }
  }

  private static isBlankUrl(url: string): boolean {
    return url.length === 0 || url.includes('about:blank')
  }

  private static notifyUpdate(): void {
    AppStorage.setOrCreate(STORAGE_VERSION_KEY, Date.now())
  }
}

export const DIWEB_LOAD_MONITOR_VERSION_KEY: string = STORAGE_VERSION_KEY
