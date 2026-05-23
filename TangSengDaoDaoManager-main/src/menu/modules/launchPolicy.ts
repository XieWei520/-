const launchPolicy: Menu.MenuOptions = {
  component: '/launch-policy/notices',
  name: 'launchPolicy',
  path: '/launch-policy',
  meta: {
    icon: 'i-bd-announcement',
    isAffix: false,
    isFull: false,
    isHide: false,
    isKeepAlive: true,
    isLink: '',
    index: 12,
    title: '启动策略'
  },
  children: [
    {
      component: '/launch-policy/notices',
      name: 'launchPolicyNotices',
      path: '/launch-policy/notices',
      meta: {
        icon: 'i-bd-volume-notice',
        isAffix: false,
        isFull: false,
        isHide: false,
        isKeepAlive: true,
        isLink: '',
        title: '弹窗公告'
      }
    }
  ]
};
export default launchPolicy;
