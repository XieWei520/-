import request from '@/utils/axios';

export interface AdminUserPurgePreview {
  uid: string;
  phone?: string;
  username?: string;
  name?: string;
  can_purge?: boolean;
  warnings?: string[];
  blockers?: string[];
  counts?: {
    created_groups?: number;
    group_messages?: number;
    personal_messages?: number;
    minio_objects?: number;
    devices?: number;
    friends?: number;
    reports?: number;
    [key: string]: number | undefined;
  };
  verification?: {
    phone_reusable?: boolean;
    uid_references?: number;
    phone_references?: number;
    [key: string]: boolean | number | string | undefined;
  };
}

export interface AdminUserPurgeRequest {
  reason: string;
  confirm_uid: string;
}

export interface AdminUserPurgeJob {
  job_id: string;
  uid: string;
  status: 'pending' | 'running' | 'succeeded' | 'failed' | 'cancelled' | string;
  progress?: number;
  current_step?: string;
  error_message?: string;
  started_at?: string;
  finished_at?: string;
  created_at?: string;
  result?: AdminUserPurgePreview['verification'] & {
    deleted_groups?: number;
    deleted_messages?: number;
    deleted_minio_objects?: number;
  };
}

export function userPurgePreviewGet(uid: string): Promise<AdminUserPurgePreview> {
  return request({
    url: `/manager/users/${uid}/purge-preview`,
    method: 'get'
  }) as unknown as Promise<AdminUserPurgePreview>;
}

export function userPurgeDelete(uid: string, data: AdminUserPurgeRequest): Promise<AdminUserPurgeJob> {
  return request({
    url: `/manager/users/${uid}/purge`,
    method: 'delete',
    data
  }) as unknown as Promise<AdminUserPurgeJob>;
}

export function userPurgeJobGet(jobId: string): Promise<AdminUserPurgeJob> {
  return request({
    url: `/manager/users/purge-jobs/${jobId}`,
    method: 'get'
  }) as unknown as Promise<AdminUserPurgeJob>;
}
