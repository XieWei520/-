<template>
  <bd-page class="monitoring-health">
    <div class="health-shell">
      <div class="health-header">
        <div>
          <h1>服务健康</h1>
          <p>展示 Go API、MySQL、Redis、WuKongIM、MinIO、LiveKit 和 CallGateway 的实时探测状态。</p>
        </div>
        <el-space>
          <el-tag :type="overallTag" effect="plain">{{ overallText }}</el-tag>
          <el-button type="primary" :loading="loading" @click="loadHealth">刷新</el-button>
        </el-space>
      </div>

      <el-alert v-if="loadError" class="mb-12px" type="error" :closable="false" show-icon :title="loadError" />

      <el-row :gutter="12">
        <el-col v-for="item in services" :key="item.name" :xs="24" :sm="12" :lg="8">
          <div class="service-item">
            <div class="service-title">
              <el-icon>
                <component :is="item.icon" />
              </el-icon>
              <span>{{ item.name }}</span>
            </div>
            <el-tag :type="item.tag" effect="plain">{{ item.status }}</el-tag>
            <p>{{ item.description }}</p>
          </div>
        </el-col>
      </el-row>
    </div>
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: 服务健康
  isAffix: false
  isKeepAlive: true
</route>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { dashboardOverviewGet, type DashboardOverview, type DashboardServiceHealth } from '@/api/dashboard';

type TagType = 'success' | 'warning' | 'info' | 'danger';

const loading = ref(false);
const loadError = ref('');
const dashboardOverview = ref<DashboardOverview | null>(null);

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

const overallTag = computed<TagType>(() => tagFor(dashboardOverview.value?.status));
const overallText = computed(() => `整体：${normalizeStatus(dashboardOverview.value?.status)}`);

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

const descriptionForService = (service: DashboardServiceHealth) => {
  if (service.message) return service.message;
  const descriptions: Record<string, string> = {
    api: 'Go API 进程可正常响应。',
    mysql: '数据库连接可正常建立。',
    redis: '缓存连接可正常建立。',
    wukongim: 'WuKongIM 管理健康检查可正常响应。',
    minio: 'MinIO live health 检查可正常响应。',
    livekit: 'LiveKit 服务入口可正常响应。',
    callgateway: 'CallGateway 健康检查可正常响应。'
  };
  return descriptions[service.key] || '服务健康检查已返回。';
};

const services = computed(() =>
  (dashboardOverview.value?.services || []).map((service: DashboardServiceHealth) => ({
    name: service.name,
    icon: iconForService(service.key),
    status: normalizeStatus(service.status),
    tag: tagFor(service.status),
    description: descriptionForService(service)
  }))
);

const loadHealth = () => {
  loading.value = true;
  loadError.value = '';
  dashboardOverviewGet()
    .then(res => {
      dashboardOverview.value = res || null;
    })
    .catch(err => {
      dashboardOverview.value = null;
      loadError.value = err?.msg || '健康检查接口调用失败';
    })
    .finally(() => {
      loading.value = false;
    });
};

onMounted(() => {
  loadHealth();
});
</script>

<style lang="scss" scoped>
.monitoring-health {
  .health-shell {
    height: 100%;
    padding: 16px;
    overflow: auto;
    background: var(--el-bg-color);
    border: 1px solid var(--el-border-color-light);
    border-radius: 6px;
  }

  .health-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    margin-bottom: 16px;

    h1 {
      margin: 0;
      font-size: 20px;
      font-weight: 600;
      color: var(--el-text-color-primary);
    }

    p {
      margin: 8px 0 0;
      color: var(--el-text-color-secondary);
    }
  }

  .service-item {
    min-height: 132px;
    padding: 16px;
    margin-bottom: 12px;
    background: var(--el-bg-color-page);
    border: 1px solid var(--el-border-color-light);
    border-radius: 6px;

    .service-title {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 12px;
      font-weight: 600;
      color: var(--el-text-color-primary);
    }

    p {
      margin: 12px 0 0;
      line-height: 1.6;
      color: var(--el-text-color-secondary);
    }
  }
}
</style>
