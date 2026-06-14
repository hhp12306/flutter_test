
import { FlutterEntry } from '@ohos/flutter_ohos';

export class DiscoverFlutterHolder {
  private static entry: FlutterEntry | null = null

  static setEntry(entry: FlutterEntry | null): void {
    DiscoverFlutterHolder.entry = entry
  }

  static onAppForeground(): void {
    DiscoverFlutterHolder.entry?.onPageShow()
  }

  static onAppBackground(): void {
    DiscoverFlutterHolder.entry?.onPageHide()
  }

  static destroy(): void {
    if (DiscoverFlutterHolder.entry !== null) {
      DiscoverFlutterHolder.entry.aboutToDisappear()
      DiscoverFlutterHolder.entry = null
    }
  }
}
