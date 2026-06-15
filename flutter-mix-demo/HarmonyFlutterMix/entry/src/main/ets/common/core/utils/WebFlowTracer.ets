import { DIWebLog, DIWebLogTag } from '../../../diweb/DIWebLog'

/**
 * 端到端链路打点：一次打开 H5 从入口到页面，按 #1 #2 #3 顺序输出
 * HiLog 过滤：tag=DIWeb-E2E
 */
export class WebFlowTracer {
  private static seq: number = 0
  private static flowId: string = ''

  static begin(flow: string): void {
    WebFlowTracer.seq = 0
    WebFlowTracer.flowId = flow
    WebFlowTracer.step('BEGIN', flow)
  }

  static step(layer: string, detail: string): void {
    const n = ++WebFlowTracer.seq
    DIWebLog.infoT(DIWebLogTag.E2E,
      '#%{public}s [%{public}s] %{public}s | flow=%{public}s',
      String(n), layer, detail, WebFlowTracer.flowId)
  }

  static end(result: string): void {
    const n = ++WebFlowTracer.seq
    DIWebLog.infoT(DIWebLogTag.E2E,
      '#%{public}s [END] %{public}s | flow=%{public}s',
      String(n), result, WebFlowTracer.flowId)
  }
}
