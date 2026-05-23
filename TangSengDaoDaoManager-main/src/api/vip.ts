import request from '@/utils/axios';

export interface SetVipRequest {
  uid: string;
  vip_level: number;
  vip_expire_time?: string;
  reason: string;
}

export function setVipPost(data: SetVipRequest) {
  return request({
    url: '/manager/user/set_vip',
    method: 'post',
    data
  });
}
