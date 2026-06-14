/**
 * 模拟公司项目 H5 侧 Bridge SDK（静态加载，用于压测页面初始化耗时）
 * 页面通过 <script src="enterprise-bridge-sdk.js"> 引入
 */
(function (global) {
  'use strict';

  var PAGE_START = Date.now();
  var SDK_VERSION = '3.2.1-enterprise';

  // 模拟 SDK 初始化：权限表、路由表、埋点配置
  var PERMISSION_MAP = {};
  var ROUTE_MAP = {};
  var TRACK_CONFIG = { enable: true, batchSize: 20, flushInterval: 5000 };
  var EVENT_BUS = { _handlers: {}, on: function (e, h) {}, off: function () {}, emit: function () {} };

  for (var i = 0; i < 50; i++) {
    PERMISSION_MAP['perm_' + i] = { code: 'P' + i, desc: 'permission_' + i, required: i % 3 === 0 };
    ROUTE_MAP['route_' + i] = { path: '/page/' + i, auth: i % 2 === 0, native: i % 5 === 0 };
  }

  // 模拟工具函数簇（公司 SDK 常见冗余代码）
  var Utils = {
    uuid: function () { return 'uuid-' + Math.random().toString(36).slice(2); },
    deepClone: function (obj) { return JSON.parse(JSON.stringify(obj || {})); },
    formatDate: function (ts) { return new Date(ts || Date.now()).toISOString(); },
    debounce: function (fn) { return fn; },
    throttle: function (fn) { return fn; },
    isEmpty: function (v) { return v === null || v === undefined || v === ''; }
  };

  for (var j = 0; j < 30; j++) {
    Utils['helper_' + j] = function (input) {
      return { index: j, input: input, ts: Date.now(), hash: String(input).length * j };
    };
  }

  // 模拟请求队列 / 拦截器链
  var RequestPipeline = {
    _interceptors: [],
    use: function (fn) { this._interceptors.push(fn); },
    run: function (ctx) {
      var i = 0;
      var next = function () {
        if (i >= RequestPipeline._interceptors.length) return ctx;
        return RequestPipeline._interceptors[i++](ctx, next);
      };
      return next();
    }
  };
  for (var k = 0; k < 10; k++) {
    RequestPipeline.use(function (ctx, next) { return next ? next() : ctx; });
  }

  // SDK 主入口：包装 EnterpriseBridge（原生注入后可用）
  var BridgeSDK = {
    version: SDK_VERSION,
    pageStartTime: PAGE_START,
    sdkLoadTime: Date.now(),
    utils: Utils,
    permissions: PERMISSION_MAP,
    routes: ROUTE_MAP,
    trackConfig: TRACK_CONFIG,
    eventBus: EVENT_BUS,
    pipeline: RequestPipeline,
    isReady: function () {
      return !!(global.DIWeb && global.EnterpriseBridge && global.__DIWEB_BRIDGE_READY__);
    },
    getPerfInfo: function () {
      var now = Date.now();
      return {
        sdkVersion: SDK_VERSION,
        pageStart: PAGE_START,
        sdkLoadCost: this.sdkLoadTime - PAGE_START,
        bridgeReadyTime: global.__DIWEB_BRIDGE_READY_TIME__ || 0,
        bridgeWaitCost: global.__DIWEB_BRIDGE_READY_TIME__
          ? (global.__DIWEB_BRIDGE_READY_TIME__ - PAGE_START) : -1,
        now: now,
        totalCost: now - PAGE_START,
        apiCount: global.DIWeb ? (global.DIWeb._apiCount || 0) : 0,
        injectScriptReady: !!global.__DIWEB_BRIDGE_READY__
      };
    },
    call: function (method, params) {
      if (global.EnterpriseBridge && global.EnterpriseBridge[method]) {
        return global.EnterpriseBridge[method](params);
      }
      if (global.DIWeb) {
        return global.DIWeb.call(method, params);
      }
      return { code: -1, message: 'bridge not ready' };
    },
    batchCall: function (methods) {
      var results = {};
      (methods || []).forEach(function (m) {
        try {
          results[m] = BridgeSDK.call(m, {});
        } catch (e) {
          results[m] = { error: e.message };
        }
      });
      return results;
    }
  };

  // 预注册常用 API 别名（模拟多套命名风格共存）
  var ALIAS_GROUPS = [
    ['getUserInfo', 'getUser', 'fetchUserInfo'],
    ['getToken', 'fetchToken', 'getAccessToken'],
    ['getVehicleInfo', 'getCarInfo', 'fetchVehicle'],
    ['toast', 'showToast', 'showTips'],
    ['close', 'closePage', 'goBack']
  ];
  ALIAS_GROUPS.forEach(function (group) {
    group.forEach(function (name, idx) {
      BridgeSDK[name] = function (params) {
        return BridgeSDK.call(group[0], params);
      };
    });
  });

  global.BridgeSDK = BridgeSDK;
  global.__BRIDGE_SDK_LOADED__ = true;
  global.__BRIDGE_SDK_LOAD_TIME__ = Date.now();
})(window);
