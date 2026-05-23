<template>
  <bd-page class="report-moderation flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">{{ title }}</p>
        </div>
        <el-button type="primary" :loading="loadTable" @click="getTableList">刷新</el-button>
      </div>

      <el-form :model="queryFrom" inline class="filter-bar">
        <el-form-item label="关键词">
          <el-input v-model="queryFrom.keyword" class="!w-180px" clearable placeholder="举报人 / 对象ID" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="queryFrom.status" class="!w-150px" clearable>
            <el-option label="待处理" value="pending" />
            <el-option label="已处理" value="processed" />
            <el-option label="已驳回" value="rejected" />
            <el-option label="已封禁" value="banned" />
          </el-select>
        </el-form-item>
        <el-form-item label="处理人">
          <el-input v-model="queryFrom.handler_uid" class="!w-180px" clearable placeholder="handler uid" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="onSearch">查询</el-button>
          <el-button @click="onReset">重置</el-button>
        </el-form-item>
      </el-form>

      <div class="flex-1 overflow-hidden p-12px pt-0">
        <el-table v-loading="loadTable" :data="tableData" :border="true" style="width: 100%; height: 100%">
          <el-table-column type="index" :width="42" :align="'center'" :fixed="'left'">
            <template #header>
              <i-bd-setting class="cursor-pointer" size="16" />
            </template>
          </el-table-column>
          <el-table-column prop="name" label="举报人" width="140" show-overflow-tooltip />
          <el-table-column prop="uid" label="举报人ID" min-width="160" show-overflow-tooltip />
          <el-table-column prop="channel_name" :label="targetNameLabel" width="180" show-overflow-tooltip />
          <el-table-column prop="channel_avatar" :label="targetAvatarLabel" align="center" width="110">
            <template #default="scope">
              <el-avatar :src="getAvatarUrl(scope.row)" size="54">{{ scope.row.channel_name }}</el-avatar>
            </template>
          </el-table-column>
          <el-table-column prop="channel_id" :label="targetIdLabel" min-width="180" show-overflow-tooltip />
          <el-table-column prop="status" label="处理状态" width="110">
            <template #default="scope">
              <el-tag :type="statusType(scope.row.status)">{{ statusText(scope.row.status) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="category_name" label="举报原因" min-width="160" show-overflow-tooltip />
          <el-table-column prop="remark" label="举报说明" min-width="180" show-overflow-tooltip />
          <el-table-column prop="handler_name" label="处理人" width="130" show-overflow-tooltip />
          <el-table-column prop="handle_remark" label="处理备注" min-width="180" show-overflow-tooltip />
          <el-table-column prop="handled_at" label="处理时间" width="170" />
          <el-table-column prop="create_at" label="举报时间" width="170" />
          <el-table-column prop="operation" label="操作" width="220" fixed="right">
            <template #default="scope">
              <el-space>
                <el-button type="primary" link @click="openHandleDialog(scope.row, 'processed')">处理</el-button>
                <el-button type="warning" link @click="openHandleDialog(scope.row, 'rejected')">驳回</el-button>
                <el-button type="danger" link @click="openHandleDialog(scope.row, 'banned')">封禁</el-button>
              </el-space>
            </template>
          </el-table-column>
          <template #empty>
            <el-empty :description="loadError || '暂无举报记录'" />
          </template>
        </el-table>
      </div>

      <div class="bd-card-footer pl-12px pr-12px mb-12px flex items-center justify-between">
        <div class="footer-hint">状态：pending / processed / rejected / banned；处理动作必须写入操作审计。</div>
        <el-pagination
          v-model:current-page="queryFrom.page_index"
          v-model:page-size="queryFrom.page_size"
          :page-sizes="[15, 20, 30, 50, 100]"
          :background="true"
          layout="total, sizes, prev, pager, next, jumper"
          :total="total"
          @size-change="onSizeChange"
          @current-change="onCurrentChange"
        />
      </div>
    </div>

    <el-dialog v-model="handleDialogVisible" :title="handleDialogTitle" :width="560" :align-center="true" :draggable="true">
      <el-form :model="handleForm" label-width="88px">
        <el-form-item label="处理对象">
          <el-input :model-value="currentReport?.channel_name || currentReport?.channel_id || '-'" disabled />
        </el-form-item>
        <el-form-item label="处理动作">
          <el-select v-model="handleForm.action" class="w-full">
            <el-option label="已处理" value="processed" />
            <el-option label="驳回" value="rejected" />
            <el-option label="封禁" value="banned" />
          </el-select>
        </el-form-item>
        <el-form-item label="联动封禁">
          <el-switch v-model="handleForm.ban_target" :disabled="handleForm.action !== 'banned'" />
        </el-form-item>
        <el-form-item label="处理备注">
          <el-input
            v-model="handleForm.handle_remark"
            :rows="4"
            type="textarea"
            placeholder="请输入处理原因，后端审计需要 handle_remark"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-space>
          <el-button @click="handleDialogVisible = false">取消</el-button>
          <el-button type="primary" :loading="handleLoading" @click="submitHandle">确认</el-button>
        </el-space>
      </template>
    </el-dialog>
  </bd-page>
</template>

<script lang="ts" setup>
import { computed, reactive, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { BU_DOU_CONFIG } from '@/config';
import {
  reportHandlePost,
  reportListGet,
  type AdminReportHandlePayload,
  type AdminReportQuery,
  type AdminReportRecord
} from '@/api/report';

const props = defineProps<{
  title: string;
  channelType: '1' | '2';
  targetKind: 'user' | 'group';
}>();

const queryFrom = reactive<AdminReportQuery>({
  channel_type: props.channelType,
  page_size: 15,
  page_index: 1,
  status: '',
  keyword: '',
  handler_uid: ''
});

const tableData = ref<AdminReportRecord[]>([]);
const loadTable = ref(false);
const loadError = ref('');
const total = ref(0);
const handleDialogVisible = ref(false);
const handleLoading = ref(false);
const currentReport = ref<AdminReportRecord | null>(null);
const handleForm = reactive<Omit<AdminReportHandlePayload, 'report_id' | 'channel_type'>>({
  action: 'processed',
  handle_remark: '',
  ban_target: false
});

const targetNameLabel = computed(() => (props.targetKind === 'user' ? '被举报用户' : '被举报群'));
const targetAvatarLabel = computed(() => (props.targetKind === 'user' ? '用户头像' : '群头像'));
const targetIdLabel = computed(() => (props.targetKind === 'user' ? '被举报用户ID' : '被举报群ID'));
const handleDialogTitle = computed(() => {
  const actionMap: Record<AdminReportHandlePayload['action'], string> = {
    processed: '处理举报',
    rejected: '驳回举报',
    banned: '封禁对象'
  };
  return actionMap[handleForm.action];
});

const getInterfaceError = (err: any, fallback: string) => {
  return err?.status === 404 ? '接口未接入' : err?.msg || fallback;
};

const reportIdOf = (row: AdminReportRecord) =>
  row.report_id || row.id || `${row.channel_type || props.channelType}:${row.channel_id}:${row.uid}`;

const channelTypeNumber = computed(() => Number(props.channelType) as 1 | 2);

const statusText = (status?: string) => {
  const statusMap: Record<string, string> = {
    pending: '待处理',
    processed: '已处理',
    rejected: '已驳回',
    banned: '已封禁'
  };
  return statusMap[status || 'pending'] || status || '待处理';
};

const statusType = (status?: string) => {
  const typeMap: Record<string, 'info' | 'success' | 'warning' | 'danger'> = {
    pending: 'info',
    processed: 'success',
    rejected: 'warning',
    banned: 'danger'
  };
  return typeMap[status || 'pending'] || 'info';
};

const getAvatarUrl = (row: AdminReportRecord) => {
  if (!row.channel_id) return '';
  const path = props.targetKind === 'user' ? 'users' : 'groups';
  return `${BU_DOU_CONFIG.APP_URL}${path}/${row.channel_id}/avatar`;
};

const getTableList = () => {
  loadTable.value = true;
  loadError.value = '';
  reportListGet(queryFrom)
    .then(res => {
      const data = res as { list?: AdminReportRecord[]; count?: number };
      tableData.value = data.list || [];
      total.value = data.count || 0;
    })
    .catch(err => {
      tableData.value = [];
      total.value = 0;
      loadError.value = getInterfaceError(err, '举报列表加载失败');
      ElMessage.error(loadError.value);
    })
    .finally(() => {
      loadTable.value = false;
    });
};

const onSearch = () => {
  queryFrom.page_index = 1;
  getTableList();
};

const onReset = () => {
  queryFrom.status = '';
  queryFrom.keyword = '';
  queryFrom.handler_uid = '';
  onSearch();
};

const onSizeChange = (size: number) => {
  queryFrom.page_size = size;
  getTableList();
};

const onCurrentChange = (current: number) => {
  queryFrom.page_index = current;
  getTableList();
};

const openHandleDialog = (row: AdminReportRecord, action: AdminReportHandlePayload['action']) => {
  currentReport.value = row;
  handleForm.action = action;
  handleForm.ban_target = action === 'banned';
  handleForm.handle_remark = '';
  handleDialogVisible.value = true;
};

const submitHandle = () => {
  if (!currentReport.value) return;
  if (!handleForm.handle_remark.trim()) {
    ElMessage.warning('请填写处理备注');
    return;
  }

  handleLoading.value = true;
  reportHandlePost({
    report_id: reportIdOf(currentReport.value),
    channel_type: channelTypeNumber.value,
    action: handleForm.action,
    handle_remark: handleForm.handle_remark.trim(),
    ban_target: handleForm.action === 'banned' ? handleForm.ban_target : false
  })
    .then(() => {
      ElMessage.success('处理成功');
      handleDialogVisible.value = false;
      getTableList();
    })
    .catch(err => {
      ElMessage.error(getInterfaceError(err, '举报处理失败'));
    })
    .finally(() => {
      handleLoading.value = false;
    });
};

onMounted(() => {
  getTableList();
});
</script>

<style lang="scss" scoped>
.bd-title {
  border-bottom: 1px solid var(--el-card-border-color);
}

.filter-bar {
  padding: 12px 12px 0;
}

.footer-hint {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.w-full {
  width: 100%;
}
</style>
