import router from '@ohos.router'
import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodChannel,
  MethodCall,
  MethodResult
} from '@ohos/flutter_ohos'
import { DIWebRouter } from '../diweb/DIWebRouter'
import { DIWebSession } from '../diweb/DIWebSession'
import { DIWebBridgeProfile } from '../diweb/DIWebTypes'
import { DIWebLog, DIWebLogTag } from '../diweb/DIWebLog'

const CHANNEL_NAME: string = 'com.example.harmonyfluttermix/diweb'

/**
 * Flutter ↔ 原生 DIWeb 通信通道
 */
export class DIWebChannelPlugin implements FlutterPlugin {
  private channel: MethodChannel | null = null

  getUniqueClassName(): string {
    return 'DIWebChannelPlugin'
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    DIWebLog.infoT(DIWebLogTag.CHANNEL, 'onAttachedToEngine channel=%{public}s', CHANNEL_NAME)
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME)
    this.channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        this.handleMethodCall(call, result)
      }
    })
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    DIWebLog.infoT(DIWebLogTag.CHANNEL, 'onDetachedFromEngine')
    if (this.channel) {
      this.channel.setMethodCallHandler(null)
      this.channel = null
    }
  }

  private handleMethodCall(call: MethodCall, result: MethodResult): void {
    const session = DIWebSession.getInstance()
    DIWebLog.infoT(DIWebLogTag.CHANNEL,
      'onMethodCall method=%{public}s args=%{public}s session=%{public}s',
      call.method, JSON.stringify(call.args ?? {}), session.getDiagnosticSummary())

    switch (call.method) {
      case 'openTestPage':
        DIWebLog.infoT(DIWebLogTag.CHANNEL, 'openTestPage -> pages/DIWebTestPage')
        router.pushUrl({ url: 'pages/DIWebTestPage' })
          .then(() => {
            DIWebLog.infoT(DIWebLogTag.CHANNEL, 'openTestPage success')
            result.success(true)
          })
          .catch((err: Error) => {
            DIWebLog.errorT(DIWebLogTag.CHANNEL, 'openTestPage failed: %{public}s', err.message ?? String(err))
            result.error('ROUTER_ERROR', err.message, null)
          })
        break
      case 'openH5': {
        const url = call.argument('url') as string
        const title = call.argument('title') as string
        const profileArg = call.argument('bridgeProfile') as string
        const bridgeProfile: DIWebBridgeProfile = profileArg === 'full' ? 'full' : 'community'
        DIWebLog.infoT(DIWebLogTag.CHANNEL,
          'openH5 url=%{public}s title=%{public}s bridge=%{public}s prewarm=%{public}s prewarmSource=%{public}s',
          url ?? '', title ?? '', bridgeProfile, String(session.isPrewarmed()), session.getPrewarmSource() || '-')
        if (!url) {
          DIWebLog.errorT(DIWebLogTag.CHANNEL, 'openH5 url is empty')
          result.error('INVALID_ARGS', 'url is required', null)
          return
        }
        DIWebRouter.open(url, { title: title ?? '', source: 'Flutter社区', bridgeProfile: bridgeProfile })
        DIWebLog.infoT(DIWebLogTag.CHANNEL, 'openH5 dispatched ok')
        result.success(true)
        break
      }
      default:
        DIWebLog.warnT(DIWebLogTag.CHANNEL, 'notImplemented method=%{public}s', call.method)
        result.notImplemented()
    }
  }
}
