
import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { FlutterManager } from '@ohos/flutter_ohos';
import { DIWebLog } from '../diweb/DIWebLog';
import { DIWebLoadMonitor } from '../diweb/DIWebLoadMonitor';
import { DiscoverFlutterHolder } from '../flutter/DiscoverFlutterHolder';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    DIWebLog.info('EntryAbility onCreate')
    DIWebLoadMonitor.initStorage()
    FlutterManager.getInstance().pushUIAbility(this)
  }

  onDestroy(): void {
    DiscoverFlutterHolder.destroy()
    FlutterManager.getInstance().popUIAbility(this)
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    FlutterManager.getInstance().pushWindowStage(this, windowStage)
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        DIWebLog.error('loadContent failed: %{public}s', JSON.stringify(err))
      }
    })
  }

  onWindowStageDestroy(): void {
    FlutterManager.getInstance().popWindowStage(this)
  }

  onForeground(): void {
    DiscoverFlutterHolder.onAppForeground()
  }

  onBackground(): void {
    DiscoverFlutterHolder.onAppBackground()
  }
}
