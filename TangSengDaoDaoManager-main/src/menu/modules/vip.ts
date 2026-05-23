const vip: Menu.MenuOptions = {
  component: '/vip/index',
  name: 'vip',
  path: '/vip',
  meta: {
    icon: 'i-bd-vip-one',
    isAffix: false,
    isFull: false,
    isHide: false,
    isKeepAlive: true,
    isLink: '',
    index: 10,
    title: 'VIP管理'
  },
  children: [
    {
      component: '/vip/index',
      name: 'vipIndex',
      path: '/vip/index',
      meta: {
        icon: 'i-bd-vip-one',
        isAffix: false,
        isFull: false,
        isHide: false,
        isKeepAlive: true,
        isLink: '',
        title: '用户VIP'
      }
    }
  ]
};
export default vip;
