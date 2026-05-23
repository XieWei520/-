const customerService: Menu.MenuOptions = {
  component: '/customer-service/index',
  name: 'customerService',
  path: '/customer-service',
  meta: {
    icon: 'i-bd-headset',
    isAffix: false,
    isFull: false,
    isHide: false,
    isKeepAlive: true,
    isLink: '',
    index: 11,
    title: '客服人员'
  },
  children: [
    {
      component: '/customer-service/index',
      name: 'customerServiceIndex',
      path: '/customer-service/index',
      meta: {
        icon: 'i-bd-headset',
        isAffix: false,
        isFull: false,
        isHide: false,
        isKeepAlive: true,
        isLink: '',
        title: '人员设置'
      }
    }
  ]
};
export default customerService;
