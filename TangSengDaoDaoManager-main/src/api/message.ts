import request from '@/utils/axios';

export interface AdminForbiddenWordPolicyQuery {
  page_size: number;
  page_index: number;
  keyword?: string;
  group?: string;
  status?: string;
  version?: string;
}

export interface AdminForbiddenWordPolicyRecord {
  id: string | number;
  name?: string;
  group?: string;
  version: string;
  status: 'draft' | 'published' | 'disabled' | 'rolled_back' | string;
  word_count?: number;
  hit_count?: number;
  published_at?: string;
  published_by?: string;
  rollback_from_version?: string;
  updated_at?: string;
  created_at?: string;
}

export interface AdminForbiddenWordPolicyAction {
  version?: string;
  target_version?: string;
  reason: string;
}

export interface AdminForbiddenWordHitLogQuery {
  page_size: number;
  page_index: number;
  keyword?: string;
  group?: string;
  policy_version?: string;
  uid?: string;
  target_id?: string;
  start_at?: string;
  end_at?: string;
}

export interface AdminForbiddenWordHitLogRecord {
  id: string | number;
  policy_version: string;
  group?: string;
  word: string;
  uid?: string;
  target_type?: string;
  target_id?: string;
  message_id?: string;
  action?: string;
  content_preview?: string;
  device_id?: string;
  created_at: string;
}

export interface AdminMessageAuditQuery {
  page_size: number;
  page_index: number;
  keyword?: string;
  channel_id?: string | number | null;
  channel_type?: 1 | 2;
  uid?: string | number | null;
  touid?: string | number | null;
  sender_uid?: string;
  target_id?: string;
  message_type?: string;
  device_id?: string;
  start_at?: string;
  end_at?: string;
}

export interface AdminMessageAuditRecord {
  message_id: string | number;
  message_seq?: number;
  sender?: string;
  sender_uid?: string;
  sender_name?: string;
  channel_id?: string;
  channel_type?: number;
  target_id?: string;
  message_type?: string;
  payload?: unknown;
  is_encrypt?: number;
  device_id?: string;
  device_name?: string;
  device_model?: string;
  revoke?: number;
  is_deleted?: number;
  created_at?: string;
}

export interface AdminMessageDeleteRequest {
  channel_id?: string | number | null;
  channel_type: 1 | 2;
  from_uid?: string | number | null;
  reason: string;
  list: Array<{
    message_id: string | number;
    message_seq?: number;
  }>;
}

// 消息记录
export function messageGet(params: any) {
  return request({
    url: '/manager/message',
    method: 'get',
    params
  });
}

// 发消息
export function messageSendPost(data: any) {
  return request({
    url: '/manager/message/send',
    method: 'post',
    data
  });
}

// 删除消息
export function messageDelete(data: AdminMessageDeleteRequest) {
  return request({
    url: '/manager/message',
    method: 'delete',
    data
  });
}

// 发全员消息
export function messageSendAllPost(data: any) {
  return request({
    url: '/manager/message/sendall',
    method: 'post',
    data
  });
}

// 违禁词列表
export function messageProhibitWordsGet(params: any) {
  return request({
    url: '/manager/message/prohibit_words',
    method: 'get',
    params
  });
}
// 新增违禁词
export function messageProhibitWordsPost(params: any) {
  return request({
    url: '/manager/message/prohibit_words',
    method: 'post',
    params
  });
}
// 删除违禁词
export function messageProhibitWordsDelete(params: any) {
  return request({
    url: '/manager/message/prohibit_words',
    method: 'delete',
    params
  });
}

// 单聊天消息
export function messageRecordpersonalGet(params: AdminMessageAuditQuery) {
  return request({
    url: '/manager/message/recordpersonal',
    method: 'get',
    params
  });
}

// 群聊天消息
export function messageRecordGet(params: AdminMessageAuditQuery) {
  return request({
    url: '/manager/message/record',
    method: 'get',
    params
  });
}

// 查看设备
export function messageUserDevices(params: any) {
  return request({
    url: '/manager/user/devices',
    method: 'get',
    params
  });
}

export function messageForbiddenWordPoliciesGet(params: AdminForbiddenWordPolicyQuery) {
  return request({
    url: '/manager/message/prohibit_word_policies',
    method: 'get',
    params
  });
}

export function messageForbiddenWordPolicyPublishPost(data: AdminForbiddenWordPolicyAction) {
  return request({
    url: '/manager/message/prohibit_word_policies/publish',
    method: 'post',
    data
  });
}

export function messageForbiddenWordPolicyRollbackPost(data: AdminForbiddenWordPolicyAction) {
  return request({
    url: '/manager/message/prohibit_word_policies/rollback',
    method: 'post',
    data
  });
}

export function messageForbiddenWordHitLogsGet(params: AdminForbiddenWordHitLogQuery) {
  return request({
    url: '/manager/message/prohibit_word_hit_logs',
    method: 'get',
    params
  });
}
