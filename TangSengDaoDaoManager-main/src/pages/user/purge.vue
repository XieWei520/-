<template>
  <bd-page class="user-purge-control flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">用户物理删除</p>
        </div>
        <el-button type="primary" :loading="previewLoading" @click="loadPreview">删除预览</el-button>
      </div>

      <el-alert
        class="m-12px mb-0"
        type="error"
        :closable="false"
        show-icon
        title="物理删除必须由后端鉴权、事务、审计和清理任务保证；前端只提交 preview、purge 和 job 查询请求。"
      />

      <div class="purge-layout">
        <section class="purge-panel">
          <div class="section-title">目标用户</div>
          <el-form :model="queryForm" label-width="86px">
            <el-form-item label="用户 UID">
              <el-input v-model.trim="queryForm.uid" clearable placeholder="输入要物理删除的 uid" />
            </el-form-item>
            <el-form-item>
              <el-space>
                <el-button type="primary" :loading="previewLoading" @click="loadPreview">查询预览</el-button>
                <el-button @click="resetPreview">重置</el-button>
              </el-space>
            </el-form-item>
          </el-form>

          <el-empty v-if="!purgePreview && !previewError" description="请先查询删除预览" />
          <el-alert v-if="previewError" class="mb-12px" type="warning" :closable="false" show-icon :title="previewError" />

          <div v-if="purgePreview" class="preview-content">
            <el-descriptions :column="1" border>
              <el-descriptions-item label="UID">{{ purgePreview.uid }}</el-descriptions-item>
              <el-descriptions-item label="手机号">{{ purgePreview.phone || '-' }}</el-descriptions-item>
              <el-descriptions-item label="用户名">{{ purgePreview.username || '-' }}</el-descriptions-item>
              <el-descriptions-item label="昵称">{{ purgePreview.name || '-' }}</el-descriptions-item>
              <el-descriptions-item label="可删除">
                <el-tag :type="purgePreview.can_purge === false ? 'danger' : 'success'">
                  {{ purgePreview.can_purge === false ? '否' : '是' }}
                </el-tag>
              </el-descriptions-item>
            </el-descriptions>

            <div class="section-title compact">清理范围</div>
            <el-table :data="countRows" border>
              <el-table-column prop="label" label="项目" min-width="160" />
              <el-table-column prop="value" label="数量" width="120" />
            </el-table>

            <div class="section-title compact">风险提示</div>
            <el-empty v-if="!riskRows.length" description="暂无阻断项或警告" />
            <el-table v-else :data="riskRows" border>
              <el-table-column prop="level" label="级别" width="100">
                <template #default="scope">
                  <el-tag :type="scope.row.level === 'blocker' ? 'danger' : 'warning'">
                    {{ scope.row.level === 'blocker' ? '阻断' : '警告' }}
                  </el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="message" label="内容" min-width="220" />
            </el-table>
          </div>
        </section>

        <section class="purge-panel">
          <div class="section-title">执行删除</div>
          <el-form :model="purgeForm" label-width="96px">
            <el-form-item label="确认 UID">
              <el-input v-model.trim="purgeForm.confirm_uid" placeholder="必须与目标 uid 完全一致" />
            </el-form-item>
            <el-form-item>
              <el-button type="danger" :disabled="!canSubmitPurge" :loading="purgeLoading" @click="submitPurge">
                提交物理删除
              </el-button>
            </el-form-item>
          </el-form>

          <el-divider />

          <div class="section-title">任务查询</div>
          <el-form :model="jobQueryForm" label-width="86px">
            <el-form-item label="Job ID">
              <el-input v-model.trim="jobQueryForm.job_id" clearable placeholder="后端返回的 purge job_id" />
            </el-form-item>
            <el-form-item>
              <el-space>
                <el-button :loading="jobLoading" @click="loadJob">查询任务</el-button>
                <el-button @click="copyCurrentJob">填入当前任务</el-button>
              </el-space>
            </el-form-item>
          </el-form>

          <el-empty v-if="!purgeJob && !jobError" description="暂无任务状态" />
          <el-alert v-if="jobError" class="mb-12px" type="warning" :closable="false" show-icon :title="jobError" />

          <el-descriptions v-if="purgeJob" :column="1" border>
            <el-descriptions-item label="Job ID">{{ purgeJob.job_id }}</el-descriptions-item>
            <el-descriptions-item label="UID">{{ purgeJob.uid }}</el-descriptions-item>
            <el-descriptions-item label="状态">
              <el-tag :type="jobStatusType">{{ purgeJob.status }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="进度">{{ purgeJob.progress ?? '-' }}</el-descriptions-item>
            <el-descriptions-item label="当前步骤">{{ purgeJob.current_step || '-' }}</el-descriptions-item>
            <el-descriptions-item label="错误">{{ purgeJob.error_message || '-' }}</el-descriptions-item>
            <el-descriptions-item label="创建时间">{{ purgeJob.created_at || '-' }}</el-descriptions-item>
            <el-descriptions-item label="完成时间">{{ purgeJob.finished_at || '-' }}</el-descriptions-item>
          </el-descriptions>
        </section>
      </div>
    </div>
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: 用户物理删除
  isAffix: false
</route>

<script lang="ts" setup>
import { ElMessage } from 'element-plus';
import { confirmHighRiskAction } from '@/utils/highRiskAction';
import {
  userPurgeDelete,
  userPurgeJobGet,
  userPurgePreviewGet,
  type AdminUserPurgeJob,
  type AdminUserPurgePreview
} from '@/api/userPurge';

interface CountRow {
  label: string;
  value: number | string;
}

interface RiskRow {
  level: 'blocker' | 'warning';
  message: string;
}

const queryForm = reactive({
  uid: ''
});

const purgeForm = reactive({
  confirm_uid: ''
});

const jobQueryForm = reactive({
  job_id: ''
});

const purgePreview = ref<AdminUserPurgePreview | null>(null);
const purgeJob = ref<AdminUserPurgeJob | null>(null);
const previewLoading = ref(false);
const purgeLoading = ref(false);
const jobLoading = ref(false);
const previewError = ref('');
const jobError = ref('');

const countLabels: Record<string, string> = {
  created_groups: '用户创建群',
  group_messages: '群消息',
  personal_messages: '单聊消息',
  minio_objects: 'MinIO 文件',
  devices: '登录设备',
  friends: '好友关系',
  reports: '举报记录'
};

const countRows = computed<CountRow[]>(() => {
  const counts = purgePreview.value?.counts || {};
  return Object.entries(counts).map(([key, value]) => ({
    label: countLabels[key] || key,
    value: value ?? 0
  }));
});

const riskRows = computed<RiskRow[]>(() => {
  const blockers = purgePreview.value?.blockers || [];
  const warnings = purgePreview.value?.warnings || [];
  return [
    ...blockers.map(message => ({ level: 'blocker' as const, message })),
    ...warnings.map(message => ({ level: 'warning' as const, message }))
  ];
});

const canSubmitPurge = computed(() => {
  return Boolean(purgePreview.value?.uid && purgeForm.confirm_uid && purgeForm.confirm_uid === purgePreview.value.uid);
});

const jobStatusType = computed(() => {
  const status = purgeJob.value?.status;
  if (status === 'succeeded') return 'success';
  if (status === 'failed' || status === 'cancelled') return 'danger';
  if (status === 'running') return 'warning';
  return 'info';
});

const toUnwiredMessage = (err: any, fallback: string) => {
  return err?.status === 404 ? '接口未接入' : err?.msg || fallback;
};

const loadPreview = () => {
  if (!queryForm.uid) {
    ElMessage.error('请输入用户 UID');
    return;
  }

  previewLoading.value = true;
  previewError.value = '';
  purgePreview.value = null;
  purgeJob.value = null;
  purgeForm.confirm_uid = '';

  userPurgePreviewGet(queryForm.uid)
    .then(res => {
      purgePreview.value = res;
      if (!purgePreview.value.uid) {
        purgePreview.value.uid = queryForm.uid;
      }
    })
    .catch(err => {
      previewError.value = toUnwiredMessage(err, '删除预览加载失败');
      ElMessage.error(previewError.value);
    })
    .finally(() => {
      previewLoading.value = false;
    });
};

const resetPreview = () => {
  queryForm.uid = '';
  purgeForm.confirm_uid = '';
  previewError.value = '';
  jobError.value = '';
  purgePreview.value = null;
  purgeJob.value = null;
};

const submitPurge = () => {
  if (!purgePreview.value?.uid) {
    ElMessage.error('请先查询删除预览');
    return;
  }
  if (purgeForm.confirm_uid !== purgePreview.value.uid) {
    ElMessage.error('确认 UID 必须与目标 UID 完全一致');
    return;
  }

  confirmHighRiskAction(
    '物理删除用户',
    `确认物理删除用户 ${purgePreview.value.name || purgePreview.value.uid} 吗？删除后必须允许同手机号重新注册。`
  )
    .then(({ reason }) => {
      purgeLoading.value = true;
      return userPurgeDelete(purgePreview.value!.uid, {
        confirm_uid: purgeForm.confirm_uid,
        reason
      });
    })
    .then(res => {
      purgeJob.value = res;
      jobQueryForm.job_id = purgeJob.value.job_id || '';
      ElMessage.success('物理删除任务已提交');
    })
    .catch(err => {
      if (err !== 'cancel') ElMessage.error(toUnwiredMessage(err, '物理删除提交失败'));
    })
    .finally(() => {
      purgeLoading.value = false;
    });
};

const loadJob = () => {
  if (!jobQueryForm.job_id) {
    ElMessage.error('请输入 Job ID');
    return;
  }

  jobLoading.value = true;
  jobError.value = '';

  userPurgeJobGet(jobQueryForm.job_id)
    .then(res => {
      purgeJob.value = res;
    })
    .catch(err => {
      jobError.value = toUnwiredMessage(err, '任务状态加载失败');
      ElMessage.error(jobError.value);
    })
    .finally(() => {
      jobLoading.value = false;
    });
};

const copyCurrentJob = () => {
  if (!purgeJob.value?.job_id) {
    ElMessage.info('当前没有可填入的任务');
    return;
  }
  jobQueryForm.job_id = purgeJob.value.job_id;
};
</script>

<style lang="scss" scoped>
.bd-title {
  border-bottom: 1px solid var(--el-card-border-color);
}

.purge-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(360px, 0.85fr);
  gap: 12px;
  padding: 12px;
  overflow: auto;
}

.purge-panel {
  min-width: 0;
  padding: 12px;
  border: 1px solid var(--el-border-color-light);
  border-radius: 4px;
}

.section-title {
  margin-bottom: 12px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.section-title.compact {
  margin-top: 16px;
}

.preview-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

@media (max-width: 960px) {
  .purge-layout {
    grid-template-columns: 1fr;
  }
}
</style>
