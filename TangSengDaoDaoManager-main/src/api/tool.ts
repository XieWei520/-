import request from '@/utils/axios';

export interface AppVersionListQuery {
  page_size: number;
  page_index: number;
  os?: string;
  is_force?: number | '';
  enabled?: number | '';
}

export interface AppVersionRecord {
  id?: string | number;
  os: string;
  app_version: string;
  build_number?: number;
  minimum_version?: string;
  minimum_build_number?: number;
  is_force?: number | boolean;
  enabled?: number | boolean;
  title?: string;
  update_desc?: string;
  download_url?: string;
  signature?: string;
  created_at?: string;
}

export interface AppVersionCreateRequest {
  app_version: string;
  os: string;
  is_force: number;
  enabled: number;
  title: string;
  build_number: number;
  minimum_version?: string;
  minimum_build_number: number;
  update_desc: string;
  download_url?: string;
  signature?: string;
  reason: string;
}

export function commonAppversionListGet(params: AppVersionListQuery) {
  return request({
    url: '/common/appversion/list',
    method: 'get',
    params
  });
}

export function commonAppversionPost(data: AppVersionCreateRequest) {
  return request({
    url: '/common/appversion',
    method: 'post',
    data
  });
}
