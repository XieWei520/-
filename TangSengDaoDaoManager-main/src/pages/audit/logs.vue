<template>
  <bd-page class="admin-audit-log flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">操作审计</p>
        </div>
        <el-button type="primary" :loading="loadTable" @click="getTableList">刷新</el-button>
      </div>

      <el-alert
        class="m-12px mb-0"
        type="info"
        :closable="false"
        show-icon
        title="操作审计已接入 /manager/audit/logs；高危操作由后端写入审计，前端负责查询和展示。"
      />

      <div class="audit-policy">
        <el-tag type="danger">高危操作</el-tag>
        <span>必须记录 operator、action、target、before/after、reason、ip、user_agent、created_at。</span>
        <span>审计日志禁止保存 password、token、secret 等敏感字段。</span>
      </div>

      <el-form :model="queryFrom" inline class="filter-bar">
        <el-form-item label="操作人">
          <el-input v-model="queryFrom.operator_uid" class="!w-180px" clearable placeholder="operator uid" />
        </el-form-item>
        <el-form-item label="动作">
          <el-input v-model="queryFrom.action" class="!w-180px" clearable placeholder="user_purge/vip_grant" />
        </el-form-item>
        <el-form-item label="对象类型">
          <el-select v-model="queryFrom.target_type" class="!w-150px" clearable>
            <el-option label="用户" value="user" />
            <el-option label="群组" value="group" />
            <el-option label="消息" value="message" />
            <el-option label="启动策略" value="launch_policy" />
            <el-option label="VIP" value="vip" />
          </el-select>
        </el-form-item>
        <el-form-item label="对象ID">
          <el-input v-model="queryFrom.target_id" class="!w-180px" clearable placeholder="target id" />
        </el-form-item>
        <el-form-item label="时间">
          <el-date-picker
            v-model="timeRange"
            type="datetimerange"
            value-format="YYYY-MM-DD HH:mm:ss"
            start-placeholder="开始时间"
            end-placeholder="结束时间"
          />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="onSearch">查询</el-button>
          <el-button @click="onReset">重置</el-button>
        </el-form-item>
      </el-form>

      <bd-table-toolbar
        v-model="visibleColumnKeys"
        :columns="toolbarColumns"
        :selected-count="selectionData.length"
        @refresh="getTableList"
        @export="onExport"
        @batch="onBatch"
      />

      <div class="flex-1 overflow-hidden p-12px">
        <el-table
          v-loading="loadTable"
          :data="tableData"
          :border="true"
          style="width: 100%; height: 100%"
          @selection-change="onSelectionChange"
        >
          <el-table-column type="selection" width="45" fixed="left" />
          <el-table-column v-for="item in displayColumns" :key="item.prop" v-bind="item">
            <template #default="scope">
              <template v-if="item.prop === 'reason'">
                <el-tag v-if="!scope.row.reason" type="danger">缺少 reason</el-tag>
                <span v-else>{{ scope.row.reason }}</span>
              </template>
              <template v-else-if="item.prop === 'before_json' || item.prop === 'after_json'">
                <el-button type="primary" link @click="openJson(scope.row[item.prop])">查看</el-button>
              </template>
              <template v-else-if="item.prop">
                {{ scope.row[item.prop] || '-' }}
              </template>
            </template>
          </el-table-column>
          <template #empty>
            <el-empty :description="loadError || '暂无审计日志；如果后端尚未实现，请先补 /manager/audit/logs。'" />
          </template>
        </el-table>
      </div>

      <div class="bd-card-footer pl-12px pr-12px mb-12px flex items-center justify-between">
        <div class="footer-hint">导出、批量复核和审计详情签名校验为后续扩展能力。</div>
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

    <el-dialog v-model="jsonDialogVisible" title="审计快照" :width="720" :align-center="true" :draggable="true">
      <pre class="json-preview">{{ jsonPreview }}</pre>
    </el-dialog>
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: 操作审计
  isAffix: false
</route>

<script lang="ts" setup>
import { ElMessage } from 'element-plus';
import { adminAuditLogsGet, type AdminAuditLogQuery, type AdminAuditLogRecord } from '@/api/audit';

interface AuditColumn {
  prop: keyof AdminAuditLogRecord;
  label: string;
  width?: number;
  minWidth?: number;
  fixed?: 'left' | 'right';
  showOverflowTooltip?: boolean;
}

const queryFrom = reactive<AdminAuditLogQuery>({
  page_size: 15,
  page_index: 1,
  operator_uid: '',
  action: '',
  target_type: '',
  target_id: '',
  start_at: '',
  end_at: ''
});

const timeRange = ref<[string, string] | []>([]);
const tableData = ref<AdminAuditLogRecord[]>([]);
const selectionData = ref<AdminAuditLogRecord[]>([]);
const loadTable = ref(false);
const loadError = ref('');
const total = ref(0);
const jsonDialogVisible = ref(false);
const jsonPreview = ref('');

const columns: AuditColumn[] = [
  { prop: 'created_at', label: '时间', width: 170, fixed: 'left' },
  { prop: 'operator_name', label: '操作人', width: 140 },
  { prop: 'operator_uid', label: '操作人ID', minWidth: 180, showOverflowTooltip: true },
  { prop: 'action', label: '动作', width: 160 },
  { prop: 'target_type', label: '对象类型', width: 120 },
  { prop: 'target_id', label: '对象ID', minWidth: 180, showOverflowTooltip: true },
  { prop: 'reason', label: 'reason', minWidth: 220, showOverflowTooltip: true },
  { prop: 'before_json', label: 'before', width: 100 },
  { prop: 'after_json', label: 'after', width: 100 },
  { prop: 'ip', label: 'IP', width: 140 },
  { prop: 'user_agent', label: 'User-Agent', minWidth: 220, showOverflowTooltip: true }
];

const toolbarColumns = columns.map(item => ({
  key: String(item.prop),
  label: item.label
}));
const visibleColumnKeys = ref(columns.map(item => String(item.prop)));
const displayColumns = computed(() => columns.filter(item => visibleColumnKeys.value.includes(String(item.prop))));

const syncTimeRange = () => {
  queryFrom.start_at = timeRange.value[0] || '';
  queryFrom.end_at = timeRange.value[1] || '';
};

const getTableList = () => {
  syncTimeRange();
  loadTable.value = true;
  loadError.value = '';
  adminAuditLogsGet(queryFrom)
    .then(res => {
      const data = res as { list?: AdminAuditLogRecord[]; count?: number };
      tableData.value = data.list || [];
      total.value = data.count || 0;
    })
    .catch(err => {
      tableData.value = [];
      total.value = 0;
      loadError.value = err?.status === 404 ? '接口未接入' : err?.msg || '审计日志加载失败';
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
  queryFrom.operator_uid = '';
  queryFrom.action = '';
  queryFrom.target_type = '';
  queryFrom.target_id = '';
  timeRange.value = [];
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

const onSelectionChange = (rows: AdminAuditLogRecord[]) => {
  selectionData.value = rows;
};

const onExport = () => {
  ElMessage.info('审计导出暂未开放');
};

const onBatch = () => {
  ElMessage.info('批量复核暂未开放');
};

const openJson = (value: AdminAuditLogRecord['before_json'] | AdminAuditLogRecord['after_json']) => {
  jsonPreview.value = typeof value === 'string' ? value : JSON.stringify(value || {}, null, 2);
  jsonDialogVisible.value = true;
};

onMounted(() => {
  getTableList();
});
</script>

<style lang="scss" scoped>
.bd-title {
  border-bottom: 1px solid var(--el-card-border-color);
}

.audit-policy {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px;
  color: var(--el-text-color-secondary);
  border-bottom: 1px solid var(--el-card-border-color);
}

.filter-bar {
  padding: 12px 12px 0;
}

.footer-hint {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.json-preview {
  max-height: 520px;
  padding: 12px;
  overflow: auto;
  background: var(--el-fill-color-lighter);
  border-radius: 4px;
}
</style>
