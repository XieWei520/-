import request from '@/utils/axios';

export interface AdminReportQuery {
  channel_type: '1' | '2' | string;
  page_size: number;
  page_index: number;
  status?: 'pending' | 'processed' | 'rejected' | 'banned' | string;
  keyword?: string;
  handler_uid?: string;
}

export interface AdminReportRecord {
  id?: string | number;
  report_id?: string | number;
  name?: string;
  uid: string;
  channel_name?: string;
  channel_id: string;
  channel_avatar?: string;
  channel_type?: string | number;
  imgs?: string;
  category_name?: string;
  remark?: string;
  status?: 'pending' | 'processed' | 'rejected' | 'banned' | string;
  handler_uid?: string;
  handler_name?: string;
  handle_remark?: string;
  handled_at?: string;
  create_at?: string;
}

export interface AdminReportHandlePayload {
  report_id: string | number;
  channel_type: 1 | 2 | number;
  action: 'processed' | 'rejected' | 'banned';
  handle_remark: string;
  ban_target?: boolean;
}

// 举报列表
export function reportListGet(params: AdminReportQuery) {
  return request({
    url: '/manager/report/list',
    method: 'get',
    params
  });
}

export function reportHandlePost(data: AdminReportHandlePayload) {
  return request({
    url: '/manager/report/handle',
    method: 'post',
    data
  });
}
