import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter 侧调用原生 DIWeb 的通道
class DIWebChannel {
  static const MethodChannel _channel =
      MethodChannel('com.example.harmonyfluttermix/diweb');

  /// 打开 DIWeb 测试页
  static Future<void> openTestPage() async {
    debugPrint('[DIWeb][Flutter] openTestPage called');
    try {
      final result = await _channel.invokeMethod('openTestPage');
      debugPrint('[DIWeb][Flutter] openTestPage success: $result');
    } on PlatformException catch (e) {
      debugPrint('[DIWeb][Flutter] openTestPage failed: code=${e.code}, msg=${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[DIWeb][Flutter] openTestPage error: $e');
      rethrow;
    }
  }

  /// 打开 H5 二级页面
  static Future<void> openH5(String url, {String? title}) async {
    debugPrint('[DIWeb][Flutter] openH5 called: url=$url, title=$title');
    try {
      final result = await _channel.invokeMethod('openH5', {
        'url': url,
        'title': title ?? '',
      });
      debugPrint('[DIWeb][Flutter] openH5 success: $result');
    } on PlatformException catch (e) {
      debugPrint('[DIWeb][Flutter] openH5 failed: code=${e.code}, msg=${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[DIWeb][Flutter] openH5 error: $e');
      rethrow;
    }
  }
}
