import { DIWEB_ENTERPRISE_API_LIST } from './DIWebBridgeApis'
import { DIWebBridgeProfile } from './DIWebTypes'

/** 社区 H5 常用 Bridge 方法（精简注入） */
export const DIWEB_COMMUNITY_API_LIST: string[] = [
  'getAppInfo', 'close', 'setTitle', 'toast'
]

/** 生成带大量 JSAPI 包装方法的注入脚本（模拟公司 H5 SDK 体积） */
export function buildBridgeInjectScript(): string {
  return buildBridgeInjectScriptForApis(DIWEB_ENTERPRISE_API_LIST, 'full')
}

/** 社区精简 Bridge 注入脚本 */
export function buildCommunityBridgeInjectScript(): string {
  return buildBridgeInjectScriptForApis(DIWEB_COMMUNITY_API_LIST, 'community')
}

function buildBridgeInjectScriptForApis(apiList: string[], profile: string): string {
  const apiWrappers: string[] = []
  apiList.forEach((method: string) => {
    apiWrappers.push(
      `    ${method}: function(params){ return window.DIWeb.call('${method}', params); }`
    )
  })

  return `
(function() {
  if (window.DIWeb && window.DIWeb._injected) { return; }
  var callbacks = {};
  var core = {
    _injected: true,
    _profile: '${profile}',
    _apiCount: ${apiList.length},
    _injectTime: Date.now(),
    call: function(method, params) {
      var res = window.DIWebBridge.call(method, JSON.stringify(params || {}));
      return JSON.parse(res);
    },
    callAsync: function(method, params) {
      return window.DIWebBridge.callAsync(method, JSON.stringify(params || {}))
        .then(function(res) { return JSON.parse(res); });
    },
    on: function(event, handler) {
      if (!callbacks[event]) { callbacks[event] = []; }
      callbacks[event].push(handler);
    },
    off: function(event, handler) {
      if (!callbacks[event]) { return; }
      callbacks[event] = callbacks[event].filter(function(h) { return h !== handler; });
    },
    _dispatchEvent: function(event, data) {
      var handlers = callbacks[event] || [];
      handlers.forEach(function(h) { try { h(data); } catch(e) {} });
    },
    getApiList: function() {
      return ${JSON.stringify(apiList)};
    }
  };
  window.DIWeb = core;
  window.EnterpriseBridge = {
${apiWrappers.join(',\n')}
  };
  window.__DIWEB_BRIDGE_READY__ = true;
  window.__DIWEB_BRIDGE_READY_TIME__ = Date.now();
})();
true;
`
}

export function getBridgeScriptForProfile(profile: DIWebBridgeProfile): string {
  if (profile === 'community') {
    return buildCommunityBridgeInjectScript()
  }
  return buildBridgeInjectScript()
}

export function getBridgeScriptSizeForProfile(profile: DIWebBridgeProfile): number {
  return getBridgeScriptForProfile(profile).length
}

/** 注入脚本字符数，用于日志对比 */
export function getBridgeInjectScriptSize(): number {
  return buildBridgeInjectScript().length
}
