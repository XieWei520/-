import request from '@/utils/axios';

export interface SetCustomerServiceRequest {
  uid: string;
  enabled: boolean;
  is_default: boolean;
  reason: string;
}

export function setCustomerServicePost(data: SetCustomerServiceRequest) {
  return request({
    url: '/manager/user/set_customer_service',
    method: 'post',
    data
  });
}
