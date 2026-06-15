import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodChannel,
  MethodCall,
  MethodResult
} from '@ohos/flutter_ohos'
import { NavigateService } from '../service/flutter_bridge/services/NavigateService'
import { WebNavigateParams } from '../common/core/components/utils/CoreUtils'
import { DIWebSession } from '../diweb/DIWebSession'
import { DIWebLog, DIWebLogTag } from '../diweb/DIWebLog'
import router from '@ohos.router'

const CHANNEL_NAME: string = 'com.example.harmonyfluttermix/diweb'

/**
 * Flutter ↔ 原生桥接插件（委托 NavigateService，对齐公司 dilink_flutter_plugin_channel）
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
        router.pushUrl({ url: 'pages/DIWebTestPage' })
          .then(() => result.success(true))
          .catch((err: Error) => result.error('ROUTER_ERROR', err.message, null))
        break
      case 'openH5': {
        const args = (call.args ?? {}) as Record<string, Object>
        if (!args['url']) {
          result.error('INVALID_ARGS', 'url is required', null)
          return
        }
        const navParams: WebNavigateParams = {
          url: String(args['url']),
          title: String(args['title'] ?? ''),
          scene: String(args['scene'] ?? 'community'),
          source: String(args['source'] ?? 'Flutter社区'),
          showNavigation: args['showNavigation'] !== false
        }
        if (args['bridgeProfile'] !== undefined && args['bridgeProfile'] !== null) {
          navParams.bridgeProfile = String(args['bridgeProfile'])
        }
        if (args['useOverlay'] === true) {
          navParams.useOverlay = true
        }
        NavigateService.getInstance().toWebviewFromRecord(navParams,
          () => result.success(true),
          (msg: string) => result.error('NAVIGATE_ERROR', msg, null))
        break
      }
      default:
        result.notImplemented()
    }
  }
}
