<template>
  <bd-page class="operation-dashboard">
    <div class="dashboard-header">
      <div>
        <h1>运维 Dashboard</h1>
        <p>核心运行指标、服务健康和运营待办集中入口。</p>
      </div>
      <el-tag :type="summaryState.type" effect="plain">{{ summaryState.label }}</el-tag>
    </div>

    <el-row :gutter="12">
      <el-col v-for="metric in metrics" :key="metric.key" :xs="24" :sm="12" :lg="6">
        <div class="metric-card">
          <div class="metric-title">
            <span>{{ metric.title }}</span>
          </div>
          <div class="metric-value">{{ metric.value }}</div>
          <div class="metric-desc">{{ metric.description }}</div>
        </div>
      </el-col>
    </el-row>

    <el-row :gutter="12" class="dashboard-row">
      <el-col :xs="24" :lg="14">
        <div class="panel">
          <div class="panel-header">
            <h2>服务健康</h2>
            <el-button text type="primary" @click="router.push('/monitoring/health')">查看详情</el-button>
          </div>
          <div class="service-list">
            <div v-for="service in services" :key="service.name" class="service-row">
              <div class="service-name">
                <el-icon>
                  <component :is="service.icon" />
                </el-icon>
                <span>{{ service.name }}</span>
              </div>
              <el-tag :type="service.tag" effect="plain">{{ service.status }}</el-tag>
            </div>
          </div>
        </div>
      </el-col>

      <el-col :xs="24" :lg="10">
        <div class="panel">
          <div class="panel-header">
            <h2>风险待办</h2>
            <el-button text type="primary" @click="router.push('/report/user')">查看举报</el-button>
          </div>
          <div class="todo-list">
            <div v-for="item in riskTodos" :key="item.title" class="todo-row">
              <span>{{ item.title }}</span>
              <strong>{{ item.value }}</strong>
            </div>
          </div>
        </div>
      </el-col>
    </el-row>

    <el-row :gutter="12" class="dashboard-row">
      <el-col :xs="24" :lg="12">
        <div class="panel">
          <div class="panel-header">
            <h2>最近趋势</h2>
            <el-tag type="success" effect="plain">近 7 天</el-tag>
          </div>
          <div v-if="trendRows.length > 0" class="trend-list">
            <div v-for="item in trendRows" :key="item.date" class="trend-row">
              <span>{{ item.date }}</span>
              <strong>活跃 {{ item.active_user_count }} / 消息 {{ item.message_count }}</strong>
            </div>
          </div>
          <el-empty v-else description="暂无趋势数据" />
        </div>
      </el-col>

      <el-col :xs="24" :lg="12">
        <div class="panel">
          <div class="panel-header">
            <h2>发布状态</h2>
            <el-button text type="primary" @click="router.push('/launch-policy')">查看启动策略</el-button>
          </div>
          <div class="release-list">
            <div v-for="item in releaseStates" :key="item.title" class="release-row">
              <span>{{ item.title }}</span>
              <el-tag type="info" effect="plain">{{ item.status }}</el-tag>
            </div>
          </div>
        </div>
      </el-col>
    </el-row>
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: Dashboard
  isAffix: true
</route>

<script lang="ts" setup>
import dayjs from 'dayjs';
import { useRouter } from 'vue-router';
import { dashboardOverviewGet, type DashboardOverview, type DashboardServiceHealth } from '@/api/dashboard';
import { startupNoticeListGet } from '@/api/launchPolicy';
import { reportListGet } from '@/api/report';
import { getAppconfigGet, type AppConfig } from '@/api/setting';
import { commonAppversionListGet } from '@/api/tool';

interface Metric {
  key: string;
  title: string;
  value: string;
  description: string;
}

interface SummaryState {
  label: string;
  type: 'success' | 'warning' | 'info' | 'primary' | 'danger';
}

type TagType = 'success' | 'warning' | 'info' | 'primary' | 'danger';

const router = useRouter();
const today = dayjs().format('YYYY-MM-DD');
const dashboardOverview = ref<DashboardOverview | null>(null);
const appConfig = ref<Partial<AppConfig>>({});
const pendingUserReports = ref('--');
const pendingGroupReports = ref('--');
const enabledNoticeCount = ref('--');
const enabledVersionCount = ref('--');

const summaryState = reactive<SummaryState>({
  label: '加载中',
  type: 'info'
});

const metrics = reactive<Metric[]>([
  { key: 'register_count', title: '今日注册', value: '0', description: '今日新注册用户' },
  { key: 'group_create_count', title: '今日建群', value: '0', description: '今日新创建群组' },
  { key: 'user_total_count', title: '总用户', value: '0', description: '数据库用户总量' },
  { key: 'group_total_count', title: '总群组', value: '0', description: '数据库群组总量' },
  { key: 'online_total_count', title: '在线用户', value: '--', description: '当前在线用户数' },
  { key: 'active_user_count', title: '今日活跃', value: '--', description: '今日登录或上线用户' },
  { key: 'message_count', title: '消息量', value: '--', description: '今日消息表写入量' },
  { key: 'connect_success_rate', title: '连接成功率', value: '--', description: '等待客户端连接质量上报' }
]);

const normalizeStatus = (status?: string) => {
  const value = String(status || '').toLowerCase();
  if (value === 'up' || value === 'ok' || value === 'healthy') return '正常';
  if (!value) return '未知';
  return status || '未知';
};

const tagFor = (status?: string): TagType => {
  const value = String(status || '').toLowerCase();
  if (value === 'up' || value === 'ok' || value === 'healthy') return 'success';
  if (!value || value === 'unknown') return 'info';
  return 'danger';
};

const iconForService = (key: string) => {
  const icons: Record<string, string> = {
    api: 'i-bd-server',
    mysql: 'i-bd-database-network',
    redis: 'i-bd-database-setting',
    wukongim: 'i-bd-connection',
    minio: 'i-bd-folder-cloud',
    livekit: 'i-bd-video-one',
    callgateway: 'i-bd-video-one'
  };
  return icons[key] || 'i-bd-server';
};

const services = computed(() =>
  (dashboardOverview.value?.services || []).map((service: DashboardServiceHealth) => ({
    name: service.name,
    icon: iconForService(service.key),
    status: normalizeStatus(service.status),
    tag: tagFor(service.status)
  }))
);

const trendRows = computed(() => dashboardOverview.value?.trends || []);

const riskTodos = computed(() => [
  { title: '待处理用户举报', value: pendingUserReports.value },
  { title: '待处理群举报', value: pendingGroupReports.value },
  { title: '高危操作审计', value: '已记录' },
  { title: '用户物理删除任务', value: '已接入' }
]);

const releaseStates = computed(() => [
  { title: 'APP 版本/强制更新', status: `${enabledVersionCount.value} 个启用版本` },
  { title: '维护模式', status: appConfig.value.maintenance_enabled === 1 ? '已开启' : '未开启' },
  { title: '弹窗公告', status: `${enabledNoticeCount.value} 个启用公告` },
  { title: 'VIP 设置', status: '已接入' }
]);

const formatMetricValue = (key: string, value: number | null | undefined, sampleCount?: number) => {
  if (key === 'connect_success_rate') {
    if (!sampleCount || value === null || value === undefined) return '暂无样本';
    return `${Math.round(value * 10000) / 100}%`;
  }
  return `${value ?? 0}`;
};

const getDashboardOverview = () => {
  dashboardOverviewGet({ date: today })
    .then(res => {
      dashboardOverview.value = res;
      const metricValues = res.metrics || {};
      metrics.forEach(metric => {
        metric.value = formatMetricValue(
          metric.key,
          metricValues[metric.key as keyof typeof metricValues] as number | null | undefined,
          metricValues.connect_sample_count
        );
      });
      const allHealthy = (res.services || []).every(service => tagFor(service.status) === 'success');
      summaryState.label = allHealthy ? '核心服务正常' : '存在异常服务';
      summaryState.type = allHealthy ? 'success' : 'danger';
    })
    .catch(() => {
      summaryState.label = 'Dashboard 数据加载失败';
      summaryState.type = 'danger';
    });
};

const getRiskTodos = () => {
  Promise.allSettled([
    reportListGet({ channel_type: '1', status: 'pending', page_index: 1, page_size: 1 }),
    reportListGet({ channel_type: '2', status: 'pending', page_index: 1, page_size: 1 })
  ]).then(([userReports, groupReports]) => {
    if (userReports.status === 'fulfilled') pendingUserReports.value = String((userReports.value as any)?.count ?? 0);
    if (groupReports.status === 'fulfilled') pendingGroupReports.value = String((groupReports.value as any)?.count ?? 0);
  });
};

const getReleaseStates = () => {
  Promise.allSettled([
    getAppconfigGet(),
    startupNoticeListGet({ page_index: 1, page_size: 100 }),
    commonAppversionListGet({ page_index: 1, page_size: 100 })
  ]).then(([config, notices, versions]) => {
    if (config.status === 'fulfilled') appConfig.value = config.value || {};
    if (notices.status === 'fulfilled') {
      const list = ((notices.value as any)?.list || []) as any[];
      enabledNoticeCount.value = String(list.filter(item => item.enabled === true || item.enabled === 1).length);
    }
    if (versions.status === 'fulfilled') {
      const list = ((versions.value as any)?.list || []) as any[];
      enabledVersionCount.value = String(list.filter(item => item.enabled === true || item.enabled === 1).length);
    }
  });
};

onMounted(() => {
  getDashboardOverview();
  getRiskTodos();
  getReleaseStates();
});
</script>

<style lang="scss" scoped>
.operation-dashboard {
  height: 100%;
  overflow: auto;

  .dashboard-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    padding: 16px;
    margin-bottom: 12px;
    background: var(--el-bg-color);
    border: 1px solid var(--el-border-color-light);
    border-radius: 6px;

    h1 {
      margin: 0;
      font-size: 22px;
      font-weight: 600;
      color: var(--el-text-color-primary);
    }

    p {
      margin: 8px 0 0;
      color: var(--el-text-color-secondary);
    }
  }

  .dashboard-row {
    margin-top: 12px;
  }

  .metric-card,
  .panel {
    background: var(--el-bg-color);
    border: 1px solid var(--el-border-color-light);
    border-radius: 6px;
  }

  .metric-card {
    min-height: 118px;
    padding: 16px;
    margin-bottom: 12px;

    .metric-title {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      color: var(--el-text-color-secondary);
    }

    .metric-value {
      margin-top: 14px;
      font-size: 28px;
      font-weight: 700;
      color: var(--el-text-color-primary);
    }

    .metric-desc {
      margin-top: 10px;
      color: var(--el-text-color-secondary);
    }
  }

  .panel {
    min-height: 280px;
    padding: 16px;

    .panel-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 12px;

      h2 {
        margin: 0;
        font-size: 16px;
        font-weight: 600;
        color: var(--el-text-color-primary);
      }
    }
  }

  .service-row,
  .todo-row,
  .release-row,
  .trend-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    min-height: 38px;
    border-bottom: 1px solid var(--el-border-color-lighter);

    &:last-child {
      border-bottom: none;
    }
  }

  .service-name {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--el-text-color-primary);
  }

  .todo-row strong {
    color: var(--el-text-color-secondary);
  }

  .trend-row strong {
    color: var(--el-text-color-secondary);
  }
}
</style>
