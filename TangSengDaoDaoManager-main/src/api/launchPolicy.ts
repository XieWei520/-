import request from '@/utils/axios';

export type LaunchPolicyPlatform = 'android' | 'windows' | 'ios' | 'macos' | 'web';

export interface LaunchPolicyQuery {
  platform: LaunchPolicyPlatform;
  version: string;
  build: number;
}

export interface LaunchPolicyVersionPolicy {
  latest_version?: string;
  latest_build?: number;
  min_supported_version?: string;
  min_supported_build?: number;
  force_update?: boolean;
  download_url?: string;
  changelog?: string;
  title?: string;
  enabled?: boolean | number;
  is_force?: boolean | number;
}

export interface LaunchPolicyStartupNotice {
  notice_id?: string;
  title?: string;
  content?: string;
  image_url?: string;
  platforms?: string[] | string;
  frequency?: string;
  enabled?: boolean | number;
  start_at?: string;
  end_at?: string;
}

export interface LaunchPolicyMaintenance {
  enabled: boolean;
  title?: string;
  message?: string;
}

export interface LaunchPolicyResponse {
  serverTime?: string;
  platform?: string;
  version?: string;
  build?: number;
  versionPolicy?: LaunchPolicyVersionPolicy;
  maintenance?: LaunchPolicyMaintenance | null;
  startupNotice?: LaunchPolicyStartupNotice;
  maintenance_enabled?: boolean;
  maintenance_message?: string;
}

export interface StartupNoticeRequest {
  notice_id?: string;
  title: string;
  content: string;
  image_url?: string;
  platforms: string[];
  frequency: string;
  enabled: number;
  start_at?: string;
  end_at?: string;
  reason: string;
}

export interface StartupNoticeListQuery {
  page_size: number;
  page_index: number;
}

export function appLaunchPolicyGet(params: LaunchPolicyQuery) {
  return request({
    url: '/app/launch-policy',
    method: 'get',
    params
  });
}

export function startupNoticeListGet(params: StartupNoticeListQuery) {
  return request({
    url: '/manager/common/startup-notices',
    method: 'get',
    params
  });
}

export function startupNoticeCreatePost(data: StartupNoticeRequest) {
  return request({
    url: '/manager/common/startup-notices',
    method: 'post',
    data
  });
}

export function startupNoticeUpdatePut(noticeID: string, data: StartupNoticeRequest) {
  return request({
    url: `/manager/common/startup-notices/${noticeID}`,
    method: 'put',
    data
  });
}
