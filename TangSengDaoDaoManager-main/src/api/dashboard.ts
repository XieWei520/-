import request from '@/utils/axios';

export interface DashboardMetrics {
  register_count: number;
  group_create_count: number;
  user_total_count: number;
  group_total_count: number;
  online_total_count: number;
  active_user_count: number;
  message_count: number;
  connect_success_rate: number | null;
  connect_sample_count: number;
}

export interface DashboardServiceHealth {
  key: string;
  name: string;
  status: string;
  message?: string;
}

export interface DashboardTrendPoint {
  date: string;
  active_user_count: number;
  message_count: number;
}

export interface DashboardOverview {
  status: string;
  metrics: DashboardMetrics;
  services: DashboardServiceHealth[];
  trends: DashboardTrendPoint[];
  generated_at: string;
}

export function dashboardOverviewGet(params?: { date?: string }): Promise<DashboardOverview> {
  return request({
    url: '/manager/dashboard/overview',
    method: 'get',
    params
  }) as unknown as Promise<DashboardOverview>;
}
