import promptAction from '@ohos.promptAction'
import router from '@ohos.router'
import bundleManager from '@ohos.bundle.bundleManager'
import { DIWebBridgeHandler, DIWebJsBridgeConfig } from './DIWebTypes'

export interface DIWebBridgeRegistrar {
  register(method: string, handler: DIWebBridgeHandler): void
}

interface BridgeShownResult {
  shown: boolean
}

interface BridgeHiddenResult {
  hidden: boolean
}

interface BridgeConfirmResult {
  confirmed: boolean
  message: string
}

interface BridgeStorageSaveResult {
  saved: boolean
  key: string
}

interface BridgeStorageGetResult {
  key: string
  value: string
}

interface BridgeStorageRemoveResult {
  removed: boolean
  key: string
}

interface BridgeClosedResult {
  closed: boolean
}

interface MockUserInfo {
  userId: string
  name: string
  phone: string
  avatar: string
  level: string
}

interface MockToken {
  token: string
  expireIn: number
}

interface MockLoginStatus {
  loggedIn: boolean
}

interface MockDeviceInfo {
  brand: string
  model: string
  osVersion: string
  screenWidth: number
  screenHeight: number
}

interface MockNetwork {
  networkType: string
  connected: boolean
}

interface MockLocation {
  latitude: number
  longitude: number
  address: string
}

interface MockVehicleInfo {
  vin: string
  plateNumber: string
  model: string
  mileage: number
  battery: number
}

interface MockVehicleItem {
  id: string
  name: string
  plateNumber: string
}

interface MockVehicleList {
  list: MockVehicleItem[]
}

interface MockOrderItem {
  orderId: string
  title: string
  status: string
}

interface MockOrderList {
  list: MockOrderItem[]
}

interface MockRemoteResult {
  success: boolean
  action: string
  executedAt: number
}

interface MockTrackResult {
  reported: boolean
  event: string
}

interface MockBaseResponse {
  method: string
  mock: boolean
  timestamp: number
}

/** 企业级 JSAPI 方法名列表（用于压测 Bridge 注册与注入体积） */
export const DIWEB_ENTERPRISE_API_LIST: string[] = [
  'getAppInfo', 'getDeviceInfo', 'getSystemInfo', 'getNetworkType', 'getBatteryInfo',
  'getStatusBarHeight', 'getSafeAreaInsets', 'getScreenInfo', 'getLanguage', 'getTheme',
  'getPlatform', 'getAppVersion', 'getChannel', 'getEnv', 'getDeviceId',
  'getUserInfo', 'getToken', 'isLogin', 'getUserId', 'getPhone',
  'login', 'logout', 'refreshToken', 'getPermissions', 'checkAuth',
  'close', 'goBack', 'openPage', 'openWebView', 'replacePage',
  'setTitle', 'setNavigationBar', 'setStatusBarStyle', 'hideNavBar', 'showNavBar',
  'setStorage', 'getStorage', 'removeStorage', 'clearStorage', 'getStorageInfo',
  'toast', 'showLoading', 'hideLoading', 'alert', 'confirm',
  'showActionSheet', 'showPicker', 'setClipboard', 'getClipboard', 'vibrate',
  'chooseImage', 'previewImage', 'saveImage', 'scanCode', 'chooseVideo', 'compressImage',
  'getLocation', 'openMap', 'chooseLocation',
  'pay', 'share', 'openMiniProgram', 'launchApp',
  'getVehicleInfo', 'getVehicleList', 'getVin', 'getPlateNumber',
  'remoteLock', 'remoteUnlock', 'remoteStart', 'remoteAc', 'remoteHonk',
  'getMileage', 'getBatteryLevel', 'getChargeStatus', 'getTirePressure',
  'bookService', 'getOrderList', 'getOrderDetail', 'cancelOrder', 'createOrder',
  'getCouponList', 'receiveCoupon', 'getMemberInfo', 'getPoints',
  'callService', 'submitFeedback', 'getMessageList', 'readMessage',
  'uploadLog', 'reportEvent', 'trackPageView', 'trackClick'
]

const SPECIAL_HANDLERS: string[] = [
  'getAppInfo', 'close', 'goBack', 'setTitle', 'toast',
  'showLoading', 'hideLoading', 'alert', 'confirm'
]

/** 注册全部企业级 JSAPI（含 mock 实现） */
export function registerEnterpriseBridgeApis(bridge: DIWebBridgeRegistrar, config: DIWebJsBridgeConfig): void {
  const storage: Map<string, string> = new Map()

  DIWEB_ENTERPRISE_API_LIST.forEach((method: string) => {
    if (SPECIAL_HANDLERS.indexOf(method) >= 0) {
      return
    }
    bridge.register(method, (params: Record<string, Object>) => {
      return buildMockResponse(method)
    })
  })

  bridge.register('getAppInfo', () => getAppInfo())
  bridge.register('close', () => closePage(config))
  bridge.register('goBack', () => closePage(config))
  bridge.register('setTitle', (params) => setTitle(params, config))
  bridge.register('toast', (params) => showToast(params))
  bridge.register('showLoading', (params) => showLoading(params))
  bridge.register('hideLoading', () => hideLoading())
  bridge.register('alert', (params) => showAlert(params))
  bridge.register('confirm', (params) => showConfirm(params))
  bridge.register('setStorage', (params) => saveStorage(params, storage))
  bridge.register('getStorage', (params) => readStorage(params, storage))
  bridge.register('removeStorage', (params) => deleteStorage(params, storage))
}

function showLoading(params: Record<string, Object>): BridgeShownResult {
  const title = (params['title'] as string) ?? '加载中...'
  promptAction.showToast({ message: title, duration: 1500 })
  const result: BridgeShownResult = { shown: true }
  return result
}

function hideLoading(): BridgeHiddenResult {
  const result: BridgeHiddenResult = { hidden: true }
  return result
}

function showAlert(params: Record<string, Object>): BridgeShownResult {
  const message = (params['message'] as string) ?? ''
  promptAction.showToast({ message: `[alert] ${message}`, duration: 2000 })
  const result: BridgeShownResult = { shown: true }
  return result
}

function showConfirm(params: Record<string, Object>): BridgeConfirmResult {
  const result: BridgeConfirmResult = {
    confirmed: true,
    message: (params['message'] as string) ?? ''
  }
  return result
}

function saveStorage(params: Record<string, Object>, storage: Map<string, string>): BridgeStorageSaveResult {
  const key = params['key'] as string
  storage.set(key, JSON.stringify(params['value'] ?? ''))
  const result: BridgeStorageSaveResult = { saved: true, key: key }
  return result
}

function readStorage(params: Record<string, Object>, storage: Map<string, string>): BridgeStorageGetResult {
  const key = params['key'] as string
  const raw = storage.get(key)
  const result: BridgeStorageGetResult = {
    key: key,
    value: raw ?? ''
  }
  return result
}

function deleteStorage(params: Record<string, Object>, storage: Map<string, string>): BridgeStorageRemoveResult {
  const key = params['key'] as string
  storage.delete(key)
  const result: BridgeStorageRemoveResult = { removed: true, key: key }
  return result
}

function getAppInfo(): Record<string, string> {
  const info: Record<string, string> = { 'platform': 'harmonyos' }
  try {
    const bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleFlags)
    info['bundleName'] = bundleInfo.name
    info['versionName'] = bundleInfo.versionName
    info['versionCode'] = bundleInfo.versionCode.toString()
  } catch (_e) {
    info['bundleName'] = ''
    info['versionName'] = ''
    info['versionCode'] = '0'
  }
  return info
}

function closePage(config: DIWebJsBridgeConfig): BridgeClosedResult {
  if (config.onClose) {
    config.onClose()
  } else {
    router.back()
  }
  const result: BridgeClosedResult = { closed: true }
  return result
}

function setTitle(params: Record<string, Object>, config: DIWebJsBridgeConfig): Record<string, string> {
  const title = params['title'] as string
  if (title && config.onTitleChange) {
    config.onTitleChange(title)
  }
  const result: Record<string, string> = { 'title': title ?? '' }
  return result
}

function showToast(params: Record<string, Object>): BridgeShownResult {
  const message = (params['message'] as string) ?? ''
  if (message.length > 0) {
    promptAction.showToast({ message: message, duration: 2000 })
  }
  const result: BridgeShownResult = { shown: true }
  return result
}

function buildMockResponse(method: string): Object {
  const now = Date.now()

  if (method === 'getUserInfo') {
    const result: MockUserInfo = {
      userId: '10001',
      name: 'TestUser',
      phone: '138****8888',
      avatar: '',
      level: 'VIP'
    }
    return result
  }
  if (method === 'getToken') {
    const result: MockToken = { token: `mock_token_${now}`, expireIn: 7200 }
    return result
  }
  if (method === 'isLogin') {
    const result: MockLoginStatus = { loggedIn: true }
    return result
  }
  if (method === 'getDeviceInfo') {
    const result: MockDeviceInfo = {
      brand: 'HUAWEI',
      model: 'HarmonyOS Device',
      osVersion: '6.0',
      screenWidth: 1316,
      screenHeight: 2832
    }
    return result
  }
  if (method === 'getNetworkType') {
    const result: MockNetwork = { networkType: 'wifi', connected: true }
    return result
  }
  if (method === 'getLocation') {
    const result: MockLocation = {
      latitude: 39.9042,
      longitude: 116.4074,
      address: '北京市东城区'
    }
    return result
  }
  if (method === 'getVehicleInfo') {
    const result: MockVehicleInfo = {
      vin: 'LSVAA4182ES000001',
      plateNumber: '京A·88888',
      model: 'Demo EV',
      mileage: 12800,
      battery: 85
    }
    return result
  }
  if (method === 'getVehicleList') {
    const item1: MockVehicleItem = { id: 'v1', name: 'Demo EV', plateNumber: '京A·88888' }
    const item2: MockVehicleItem = { id: 'v2', name: 'Demo SUV', plateNumber: '京B·66666' }
    const list: MockVehicleItem[] = [item1, item2]
    const result: MockVehicleList = { list: list }
    return result
  }
  if (method === 'getOrderList') {
    const order1: MockOrderItem = { orderId: 'O001', title: '智能行车记录仪', status: '待发货' }
    const order2: MockOrderItem = { orderId: 'O002', title: '无线车载充电器', status: '已完成' }
    const list: MockOrderItem[] = [order1, order2]
    const result: MockOrderList = { list: list }
    return result
  }
  if (method.indexOf('remote') === 0) {
    const result: MockRemoteResult = { success: true, action: method, executedAt: now }
    return result
  }
  if (method.indexOf('track') === 0 || method === 'reportEvent' || method === 'uploadLog') {
    const result: MockTrackResult = { reported: true, event: method }
    return result
  }

  const result: MockBaseResponse = { method: method, mock: true, timestamp: now }
  return result
}
