import { hidebug } from '@kit.PerformanceAnalysisKit'
import { taskpool } from '@kit.ArkTS'
import { DIWebLog, DIWebLogTag } from './DIWebLog'

/** 应用进程内存快照（单位 KB） */
export interface DIWebMemorySnapshot {
  pssKb: number
  privateDirtyKb: number
  sharedDirtyKb: number
  nativeHeapKb: number
  timestamp: number
}

interface MemoryTaskResult {
  pssKb: number
  privateDirtyKb: number
  sharedDirtyKb: number
  nativeHeapKb: number
  timestamp: number
}

@Concurrent
function readMemorySnapshotTask(): MemoryTaskResult {
  const nativeHeapBytes = Number(hidebug.getNativeHeapAllocatedSize())
  const result: MemoryTaskResult = {
    pssKb: Number(hidebug.getPss()),
    privateDirtyKb: Number(hidebug.getPrivateDirty()),
    sharedDirtyKb: Number(hidebug.getSharedDirty()),
    nativeHeapKb: Math.round(nativeHeapBytes / 1024),
    timestamp: Date.now()
  }
  return result
}

/**
 * 应用内存监控（HiDebug / hidebug，仅调试用）
 * getPss 等接口较慢，统一走 taskpool 异步线程。
 */
export class DIWebMemoryMonitor {
  static readSnapshotAsync(onResult: (snapshot: DIWebMemorySnapshot) => void): void {
    taskpool.execute(readMemorySnapshotTask).then((raw: Object) => {
      const data = raw as MemoryTaskResult
      onResult({
        pssKb: data.pssKb,
        privateDirtyKb: data.privateDirtyKb,
        sharedDirtyKb: data.sharedDirtyKb,
        nativeHeapKb: data.nativeHeapKb,
        timestamp: data.timestamp
      })
    }).catch((err: Error) => {
      DIWebLog.warnT(DIWebLogTag.MONITOR, 'readSnapshotAsync failed: %{public}s', err.message ?? String(err))
      onResult({
        pssKb: -1,
        privateDirtyKb: -1,
        sharedDirtyKb: -1,
        nativeHeapKb: -1,
        timestamp: Date.now()
      })
    })
  }

  static formatKb(kb: number): string {
    if (kb < 0) {
      return '--'
    }
    if (kb >= 1024) {
      return `${(kb / 1024).toFixed(1)} MB`
    }
    return `${kb} KB`
  }

  static formatDeltaKb(deltaKb: number): string {
    if (deltaKb === 0) {
      return '0'
    }
    const sign = deltaKb > 0 ? '+' : ''
    if (Math.abs(deltaKb) >= 1024) {
      return `${sign}${(deltaKb / 1024).toFixed(1)} MB`
    }
    return `${sign}${deltaKb} KB`
  }
}
