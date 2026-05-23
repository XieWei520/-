import request from '@/utils/axios';

export interface AdminAuditLogQuery {
  page_size: number;
  page_index: number;
  operator_uid?: string;
  action?: string;
  target_type?: string;
  target_id?: string;
  start_at?: string;
  end_at?: string;
}

export interface AdminAuditLogRecord {
  id: string | number;
  operator_uid: string;
  operator_name?: string;
  action: string;
  target_type: string;
  target_id: string;
  before_json?: Record<string, unknown> | string;
  after_json?: Record<string, unknown> | string;
  reason: string;
  ip?: string;
  user_agent?: string;
  created_at: string;
}

export function adminAuditLogsGet(params: AdminAuditLogQuery) {
  return request({
    url: '/manager/audit/logs',
    method: 'get',
    params
  });
}
