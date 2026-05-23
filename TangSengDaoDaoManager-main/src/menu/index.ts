const baseMeta = {
  isAffix: false,
  isFull: false,
  isHide: false,
  isKeepAlive: true,
  isLink: ''
};

interface MenuItemOptions extends Omit<Partial<Menu.MenuOptions>, 'children' | 'meta'> {
  children?: Menu.MenuOptions[];
  meta?: Partial<Menu.MetaProps>;
}

const menuItem = (path: string, name: string, title: string, icon: string, options: MenuItemOptions = {}): Menu.MenuOptions => ({
  path,
  name,
  component: options.component,
  redirect: options.redirect,
  meta: {
    ...baseMeta,
    icon,
    title,
    ...options.meta
  },
  children: options.children
});

const menu: Menu.MenuOptions[] = [
  menuItem('/operation', 'operation', '运营', 'i-bd-data', {
    redirect: '/home',
    meta: { index: 1 },
    children: [
      menuItem('/home', 'homeIndex', 'Dashboard', 'i-bd-home', {
        component: '/home/index',
        meta: { isAffix: true }
      }),
      menuItem('/launch-policy', 'launchPolicyIndex', '启动策略', 'i-bd-application-menu', {
        component: '/launch-policy'
      }),
      menuItem('/launch-policy/notices', 'launchPolicyNotices', '弹窗公告', 'i-bd-volume-notice', {
        component: '/launch-policy/notices'
      }),
      menuItem('/tool/appupdate', 'toolAppupdate', 'APP 版本', 'i-bd-application-one', {
        component: '/tool/appupdate'
      }),
      menuItem('/workplace', 'workplaceIndex', '工作台总览', 'i-bd-all-application', {
        component: '/workplace'
      }),
      menuItem('/workplace/manage', 'workplaceManage', '工作台应用', 'i-bd-application'),
      menuItem('/workplace/configuration', 'workplaceConfiguration', '工作台配置', 'i-bd-setting-config'),
      menuItem('/vip', 'vipIndex', 'VIP 管理', 'i-bd-vip-one', {
        component: '/vip'
      }),
      menuItem('/customer-service', 'customerServiceIndex', '客服人员', 'i-bd-headset', {
        component: '/customer-service'
      })
    ]
  }),
  menuItem('/users', 'users', '用户', 'i-bd-user', {
    redirect: '/user/userlist',
    meta: { index: 2 },
    children: [
      menuItem('/user/userlist', 'userUserlist', '用户列表', 'i-bd-user', {
        component: '/user/userlist'
      }),
      menuItem('/user/adduser', 'userAdduser', '新增用户', 'i-bd-add-user', {
        component: '/user/adduser'
      }),
      menuItem('/user/disablelist', 'userDisablelist', '封禁用户', 'i-bd-wrong-user', {
        component: '/user/disablelist'
      }),
      menuItem('/user/friends', 'userFriends', '好友关系', 'i-bd-user-to-user-transmission', {
        component: '/user/friends',
        meta: { isHide: true }
      }),
      menuItem('/user/userblacklist', 'userUserblacklist', '黑名单', 'i-bd-block', {
        component: '/user/userblacklist',
        meta: { isHide: true }
      }),
      menuItem('/user/purge', 'userPurge', '物理删除', 'i-bd-delete', {
        component: '/user/purge',
        meta: { auth: ['superAdmin'] }
      })
    ]
  }),
  menuItem('/groups', 'groups', '群组', 'i-bd-peoples-two', {
    redirect: '/group/grouplist',
    meta: { index: 3 },
    children: [
      menuItem('/group/grouplist', 'groupGrouplist', '群列表', 'i-bd-group', {
        component: '/group/grouplist'
      }),
      menuItem('/group/groupdisablelist', 'groupGroupdisablelist', '群封禁', 'i-bd-ungroup', {
        component: '/group/groupdisablelist'
      }),
      menuItem('/group/groupmembers', 'groupGroupmembers', '群成员', 'i-bd-peoples', {
        component: '/group/groupmembers',
        meta: { isHide: true }
      }),
      menuItem('/group/groupblacklist', 'groupGroupblacklist', '群黑名单', 'i-bd-block', {
        component: '/group/groupblacklist',
        meta: { isHide: true }
      })
    ]
  }),
  menuItem('/content-safety', 'contentSafety', '内容安全', 'i-bd-message-security', {
    redirect: '/message/prohibitwords',
    meta: { index: 4 },
    children: [
      menuItem('/message/prohibitwords', 'messageProhibitwords', '违禁词策略', 'i-bd-message-security', {
        component: '/message/prohibitwords'
      }),
      menuItem('/report/user', 'reportUser', '举报用户', 'i-bd-wrong-user', {
        component: '/report/user'
      }),
      menuItem('/report/group', 'reportGroup', '举报群聊', 'i-bd-user-to-user-transmission', {
        component: '/report/group'
      }),
      menuItem('/message/sendmsglist', 'messageSendmsglist', '群发记录', 'i-bd-communication', {
        component: '/message/sendmsglist'
      }),
      menuItem('/message/record', 'messageRecord', '群消息审计', 'i-bd-message', {
        component: '/message/record',
        meta: { isHide: true }
      }),
      menuItem('/message/recordpersonal', 'messageRecordpersonal', '单聊消息审计', 'i-bd-message', {
        component: '/message/recordpersonal',
        meta: { isHide: true }
      })
    ]
  }),
  menuItem('/system', 'system', '系统配置', 'i-bd-setting', {
    redirect: '/setting/currencysetting',
    meta: { index: 5 },
    children: [
      menuItem('/setting/currencysetting', 'settingCurrencysetting', '基础配置', 'i-bd-setting-config', {
        component: '/setting/currencysetting'
      }),
      menuItem('/audit/logs', 'auditLogs', '操作审计', 'i-bd-log', {
        component: '/audit/logs',
        meta: { auth: ['superAdmin'] }
      }),
      menuItem('/user/administrator', 'userAdministrator', '管理员', 'i-bd-user-business', {
        component: '/user/administrator',
        meta: { auth: ['superAdmin'] }
      }),
      menuItem('/setting/updatepwd', 'settingUpdatepwd', '修改登录密码', 'i-bd-shield', {
        component: '/setting/updatepwd'
      })
    ]
  }),
  menuItem('/monitoring', 'monitoring', '监控运维', 'i-bd-monitor', {
    redirect: '/monitoring/health',
    meta: { index: 6 },
    children: [
      menuItem('/monitoring/health', 'monitoringHealth', '服务健康', 'i-bd-monitor', {
        component: '/monitoring/health'
      })
    ]
  })
];

export default menu;
