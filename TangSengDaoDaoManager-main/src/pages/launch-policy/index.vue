<template>
  <bd-page class="launch-policy-control flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">启动策略中心</p>
        </div>
        <el-space>
          <el-button @click="goTo('/tool/appupdate')">APP 版本</el-button>
          <el-button @click="goTo('/launch-policy/notices')">弹窗公告</el-button>
          <el-button type="primary" :loading="loading" @click="getLaunchPolicy">刷新预览</el-button>
        </el-space>
      </div>

      <div class="flex-1 overflow-auto p-12px">
        <el-alert
          class="mb-12px"
          type="info"
          :closable="false"
          show-icon
          title="本页展示客户端启动策略预览；APP 版本、弹窗公告和维护模式均来自现有后端接口。"
        />

        <el-form :model="queryForm" inline class="policy-query mb-12px">
          <el-form-item label="平台">
            <el-select v-model="queryForm.platform" class="!w-150px">
              <el-option label="Android" value="android" />
              <el-option label="Windows" value="windows" />
              <el-option label="iOS" value="ios" disabled />
              <el-option label="macOS" value="macos" disabled />
              <el-option label="Web" value="web" disabled />
            </el-select>
          </el-form-item>
          <el-form-item label="当前版本">
            <el-input v-model="queryForm.version" class="!w-140px" />
          </el-form-item>
          <el-form-item label="当前 Build">
            <el-input-number v-model="queryForm.build" class="!w-140px" :min="0" :step="1" />
          </el-form-item>
          <el-form-item>
            <el-button type="primary" :loading="loading" @click="getLaunchPolicy">查询客户端策略</el-button>
          </el-form-item>
        </el-form>

        <el-row :gutter="12" class="mb-12px">
          <el-col :xs="24" :md="8">
            <div class="policy-card">
              <div class="policy-card__head">
                <span>强制更新</span>
                <el-tag :type="forceUpdate ? 'danger' : 'success'">{{ forceUpdate ? '已触发' : '未触发' }}</el-tag>
              </div>
              <div class="policy-card__value">{{ versionPolicyText }}</div>
              <div class="policy-card__meta">来源：APP 版本配置</div>
              <el-button class="mt-12px" type="primary" plain @click="goTo('/tool/appupdate')">配置 APP 版本</el-button>
            </div>
          </el-col>
          <el-col :xs="24" :md="8">
            <div class="policy-card">
              <div class="policy-card__head">
                <span>弹窗公告</span>
                <el-tag :type="startupNotice?.title ? 'warning' : 'info'">
                  {{ startupNotice?.title ? '有匹配公告' : '无匹配公告' }}
                </el-tag>
              </div>
              <div class="policy-card__value">{{ startupNotice?.title || '-' }}</div>
              <div class="policy-card__meta">{{ startupNotice?.content || '来源：startup_notice' }}</div>
              <el-button class="mt-12px" type="primary" plain @click="goTo('/launch-policy/notices')">管理弹窗公告</el-button>
            </div>
          </el-col>
          <el-col :xs="24" :md="8">
            <div class="policy-card maintenance-mode">
              <div class="policy-card__head">
                <span>维护模式</span>
                <el-tag :type="maintenanceEnabled ? 'danger' : 'success'">
                  {{ maintenanceEnabled ? '已开启' : '未开启' }}
                </el-tag>
              </div>
              <div class="policy-card__value">{{ maintenanceTitle }}</div>
              <div class="policy-card__meta">{{ maintenanceMessage }}</div>
              <el-button class="mt-12px" type="primary" plain @click="goTo('/setting/currencysetting')">配置维护模式</el-button>
            </div>
          </el-col>
        </el-row>

        <el-row :gutter="12">
          <el-col :xs="24" :lg="14">
            <div class="policy-panel">
              <div class="policy-panel__title">策略预览</div>
              <el-descriptions :column="2" border>
                <el-descriptions-item label="接口">/app/launch-policy</el-descriptions-item>
                <el-descriptions-item label="服务时间">{{ policy?.serverTime || '-' }}</el-descriptions-item>
                <el-descriptions-item label="平台">{{ policy?.platform || queryForm.platform }}</el-descriptions-item>
                <el-descriptions-item label="当前 Build">{{ policy?.build ?? queryForm.build }}</el-descriptions-item>
                <el-descriptions-item label="最新版本">{{
                  versionPolicy?.latest_version || versionPolicy?.title || '-'
                }}</el-descriptions-item>
                <el-descriptions-item label="最新 Build">{{ versionPolicy?.latest_build ?? '-' }}</el-descriptions-item>
                <el-descriptions-item label="最低版本">
                  {{ versionPolicy?.min_supported_version || '-' }}
                </el-descriptions-item>
                <el-descriptions-item label="最低 Build">
                  {{ versionPolicy?.min_supported_build ?? '-' }}
                </el-descriptions-item>
                <el-descriptions-item label="下载地址" :span="2">
                  {{ versionPolicy?.download_url || '-' }}
                </el-descriptions-item>
                <el-descriptions-item label="更新说明" :span="2">
                  {{ versionPolicy?.changelog || '-' }}
                </el-descriptions-item>
              </el-descriptions>
            </div>
          </el-col>
          <el-col :xs="24" :lg="10">
            <div class="policy-panel">
              <div class="policy-panel__title">客户端启动顺序</div>
              <el-timeline>
                <el-timeline-item :type="maintenanceEnabled ? 'danger' : 'success'" timestamp="1">
                  维护模式：{{ maintenanceEnabled ? '阻断进入并展示维护提示' : '未开启' }}
                </el-timeline-item>
                <el-timeline-item :type="forceUpdate ? 'danger' : 'success'" timestamp="2">
                  低于最低 Build 时阻断进入并要求更新
                </el-timeline-item>
                <el-timeline-item type="warning" timestamp="3">低于最新 Build 时展示可选更新</el-timeline-item>
                <el-timeline-item :type="startupNotice?.title ? 'warning' : 'info'" timestamp="4">
                  命中公告后按 once/daily/every_start 展示
                </el-timeline-item>
              </el-timeline>
            </div>
          </el-col>
        </el-row>
      </div>
    </div>
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: 启动策略
  isAffix: false
</route>

<script lang="ts" setup>
import { computed, reactive, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { useRouter } from 'vue-router';
import {
  appLaunchPolicyGet,
  type LaunchPolicyPlatform,
  type LaunchPolicyMaintenance,
  type LaunchPolicyResponse,
  type LaunchPolicyStartupNotice,
  type LaunchPolicyVersionPolicy
} from '@/api/launchPolicy';
import { getAppconfigGet, type AppConfig } from '@/api/setting';

const router = useRouter();
const loading = ref(false);
const policy = ref<LaunchPolicyResponse | null>(null);
const appConfig = ref<Partial<AppConfig>>({});

const queryForm = reactive({
  platform: 'android' as LaunchPolicyPlatform,
  version: '1.0.0',
  build: 1
});

const versionPolicy = computed<LaunchPolicyVersionPolicy | undefined>(() => policy.value?.versionPolicy);
const startupNotice = computed<LaunchPolicyStartupNotice | undefined>(() => policy.value?.startupNotice);
const policyMaintenance = computed<LaunchPolicyMaintenance | null | undefined>(() => policy.value?.maintenance);

const forceUpdate = computed(() => {
  const value = versionPolicy.value?.force_update ?? versionPolicy.value?.is_force;
  return value === true || value === 1;
});

const versionPolicyText = computed(() => {
  if (!versionPolicy.value) {
    return '暂无策略';
  }
  const latest = versionPolicy.value.latest_version || versionPolicy.value.title || '-';
  const minBuild = versionPolicy.value.min_supported_build ?? '-';
  return `${latest} / 最低 Build ${minBuild}`;
});

const maintenanceEnabled = computed(() => {
  return policyMaintenance.value?.enabled === true || appConfig.value.maintenance_enabled === 1;
});

const maintenanceTitle = computed(() => {
  return policyMaintenance.value?.title || appConfig.value.maintenance_title || (maintenanceEnabled.value ? '维护中' : '正常开放');
});

const maintenanceMessage = computed(() => {
  return (
    policyMaintenance.value?.message ||
    appConfig.value.maintenance_message ||
    (maintenanceEnabled.value ? '客户端启动时将展示维护提示。' : '客户端启动不会被维护模式阻断。')
  );
});

const goTo = (path: string) => {
  router.push(path);
};

const getLaunchPolicy = () => {
  loading.value = true;
  appLaunchPolicyGet({
    platform: queryForm.platform,
    version: queryForm.version,
    build: queryForm.build
  })
    .then(res => {
      policy.value = res as LaunchPolicyResponse;
    })
    .catch(err => {
      policy.value = null;
      ElMessage.error(err?.msg || '启动策略查询失败');
    })
    .finally(() => {
      loading.value = false;
    });
};

const getAppConfig = () => {
  getAppconfigGet().then(res => {
    appConfig.value = res || {};
  });
};

onMounted(() => {
  getAppConfig();
  getLaunchPolicy();
});
</script>

<style lang="scss" scoped>
.bd-title {
  border-bottom: 1px solid var(--el-card-border-color);
}

.policy-query {
  padding: 12px;
  background: var(--el-fill-color-lighter);
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
}

.policy-card,
.policy-panel {
  min-height: 154px;
  padding: 14px;
  background: var(--el-bg-color);
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
}

.policy-card__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-weight: 600;
}

.policy-card__value {
  margin-top: 16px;
  font-size: 18px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.policy-card__meta {
  min-height: 36px;
  margin-top: 8px;
  color: var(--el-text-color-secondary);
  line-height: 18px;
}

.policy-panel__title {
  margin-bottom: 12px;
  font-weight: 600;
}
</style>
