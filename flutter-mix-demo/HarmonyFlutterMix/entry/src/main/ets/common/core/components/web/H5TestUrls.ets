/** UAT 社区帖子 H5 测试地址 */
export interface H5TestPost {
  label: string
  url: string
}

export class H5TestUrls {
  static readonly UAT_BASE: string =
    'https://common-cache-h5-uat.bydauto.com/platform/uat/2026100000002/1.0.0.1/index.html'

  static readonly UAT_POSTS: H5TestPost[] = [
    {
      label: '帖子 pid=2406463',
      url: `${H5TestUrls.UAT_BASE}#/pages/community/detail/index?type=1&pid=2406463`
    },
    {
      label: '帖子 pid=2406030',
      url: `${H5TestUrls.UAT_BASE}#/pages/community/detail/index?type=1&pid=2406030`
    },
    {
      label: '帖子 pid=2405312',
      url: `${H5TestUrls.UAT_BASE}#/pages/community/detail/index?type=1&pid=2405312`
    },
    {
      label: '帖子 pid=2405232',
      url: `${H5TestUrls.UAT_BASE}#/pages/community/detail/index?type=1&pid=2405232`
    }
  ]
}
