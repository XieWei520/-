import request from '@/utils/axios';

export interface AppConfig {
  welcome_message: string;
  revoke_second: number;
  new_user_join_system_group: number;
  search_by_phone: number;
  send_welcome_message_on: number;
  register_invite_on: number;
  invite_system_account_join_group_on: number;
  register_user_must_complete_info_on: number;
  channel_pinned_message_max_count?: number;
  can_modify_api_url?: number;
  maintenance_enabled?: number;
  maintenance_title?: string;
  maintenance_message?: string;
}

// 更新密码
export function userUpdatepasswordPost(data: any) {
  return request({
    url: '/manager/user/updatepassword',
    method: 'post',
    data
  });
}

// 获取通用设置
export function getAppconfigGet(params?: any): Promise<AppConfig> {
  return request({
    url: '/manager/common/appconfig',
    method: 'get',
    params
  }) as unknown as Promise<AppConfig>;
}

// 更新通用设置
export function updateAppconfigPost(data: any) {
  return request({
    url: '/manager/common/appconfig',
    method: 'post',
    data
  });
}
