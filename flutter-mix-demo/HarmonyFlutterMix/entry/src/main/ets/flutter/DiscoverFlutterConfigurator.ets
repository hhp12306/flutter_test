
import { FlutterEngineConfigurator, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '@ohos/flutter_module';
import { DIWebChannelPlugin } from '../plugins/DIWebChannelPlugin';
import { DIWebLog } from '../diweb/DIWebLog';

export class DiscoverFlutterConfigurator implements FlutterEngineConfigurator {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    DIWebLog.info('DiscoverFlutterConfigurator configureFlutterEngine')
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    flutterEngine.getPlugins()?.add(new DIWebChannelPlugin());
  }

  cleanUpFlutterEngine(_flutterEngine: FlutterEngine): void {
  }
}
