import request from '@/utils/axios';

export interface HealthStatus {
  status?: string;
  db?: string;
  redis?: string;
}

export function healthGet(): Promise<HealthStatus> {
  return request({
    url: '/health',
    method: 'get'
  }) as unknown as Promise<HealthStatus>;
}
