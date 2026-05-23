<template>
  <bd-page class="app-version-policy flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">APP 版本策略</p>
        </div>
        <el-space>
          <el-button @click="goLaunchPolicy">启动策略预览</el-button>
          <el-button type="primary" @click="onAppVersionAdd">新增版本</el-button>
        </el-space>
      </div>

      <div class="policy-summary">
        <div class="summary-item">
          <span class="summary-label">强制更新</span>
          <strong>{{ forceCount }}</strong>
        </div>
        <div class="summary-item">
          <span class="summary-label">可选更新</span>
          <strong>{{ optionalCount }}</strong>
        </div>
        <div class="summary-item">
          <span class="summary-label">已启用</span>
          <strong>{{ enabledCount }}</strong>
        </div>
        <div class="summary-item summary-note">
          客户端启动时读取 /app/launch-policy。Build 低于最低 Build 会触发强更，低于最新 Build 会触发可选更新。
        </div>
      </div>

      <el-form :model="queryFrom" inline class="filter-bar">
        <el-form-item label="平台">
          <el-select v-model="queryFrom.os" class="!w-140px" clearable>
            <el-option label="Android" value="android" />
            <el-option label="Windows" value="windows" />
            <el-option label="iOS" value="ios" />
            <el-option label="Mac" value="mac" />
            <el-option label="Linux" value="linx" />
          </el-select>
        </el-form-item>
        <el-form-item label="更新类型">
          <el-select v-model="queryFrom.is_force" class="!w-140px" clearable>
            <el-option label="强制更新" :value="1" />
            <el-option label="可选更新" :value="0" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="queryFrom.enabled" class="!w-120px" clearable>
            <el-option label="启用" :value="1" />
            <el-option label="停用" :value="0" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="onSearch">查询</el-button>
          <el-button @click="onReset">重置</el-button>
        </el-form-item>
      </el-form>

      <bd-table-toolbar
        v-model="visibleColumnKeys"
        :columns="toolbarColumns"
        :selected-count="0"
        @refresh="getTableList"
        @export="onExport"
        @batch="onBatch"
      />

      <div class="flex-1 overflow-hidden p-12px">
        <el-table v-loading="loadTable" :data="tableData" :border="true" style="width: 100%; height: 100%">
          <el-table-column type="index" :width="48" align="center" fixed="left" />
          <el-table-column
            v-for="item in displayColumns"
            :key="item.prop"
            v-bind="item"
            :show-overflow-tooltip="item.showOverflowTooltip"
          >
            <template #default="scope">
              <template v-if="item.prop === 'is_force'">
                <el-tag :type="isForce(scope.row) ? 'danger' : 'warning'">
                  {{ isForce(scope.row) ? '强制更新' : '可选更新' }}
                </el-tag>
              </template>
              <template v-else-if="item.prop === 'enabled'">
                <el-tag :type="isEnabled(scope.row) ? 'success' : 'info'">
                  {{ isEnabled(scope.row) ? '启用' : '停用' }}
                </el-tag>
              </template>
              <template v-else-if="item.formatter">
                {{ item.formatter(scope.row) }}
              </template>
              <template v-else-if="item.prop">
                {{ scope.row[item.prop] || '-' }}
              </template>
            </template>
          </el-table-column>
          <template #empty>
            <el-empty :description="loadError || '暂无 APP 版本策略'" />
          </template>
        </el-table>
      </div>

      <div class="bd-card-footer pl-12px pr-12px mb-12px flex items-center justify-between">
        <div class="footer-hint">发布、停用、回滚和操作审计需要后端新增管理接口；当前仅接入已确认的列表和新增版本接口。</div>
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

    <bd-app-version v-model:value="appVersionAddValue" @ok="onAppVersionOk" />
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: APP 版本策略
  isAffix: false
</route>

<script lang="ts" setup>
import { ElMessage } from 'element-plus';
import { useRouter } from 'vue-router';
import { commonAppversionListGet, type AppVersionListQuery, type AppVersionRecord } from '@/api/tool';

interface AppVersionColumn {
  prop: keyof AppVersionRecord;
  label: string;
  width?: number;
  minWidth?: number;
  fixed?: 'left' | 'right';
  showOverflowTooltip?: boolean;
  formatter?: (row: AppVersionRecord) => string | number;
}

const router = useRouter();
const tableData = ref<AppVersionRecord[]>([]);
const loadTable = ref(false);
const loadError = ref('');
const total = ref(0);

const queryFrom = reactive<AppVersionListQuery>({
  page_size: 15,
  page_index: 1,
  os: '',
  is_force: '',
  enabled: ''
});

const columns: AppVersionColumn[] = [
  { prop: 'os', label: '平台', width: 120, fixed: 'left' },
  { prop: 'app_version', label: '版本号', width: 130 },
  { prop: 'build_number', label: '最新 Build', width: 120, formatter: row => row.build_number ?? '-' },
  { prop: 'minimum_version', label: '最低版本', width: 130, formatter: row => row.minimum_version || '-' },
  { prop: 'minimum_build_number', label: '最低 Build', width: 120, formatter: row => row.minimum_build_number ?? '-' },
  { prop: 'is_force', label: '更新类型', width: 120 },
  { prop: 'enabled', label: '状态', width: 90 },
  { prop: 'title', label: '标题', width: 180, formatter: row => row.title || '-' },
  { prop: 'update_desc', label: '更新说明', minWidth: 240, showOverflowTooltip: true, formatter: row => row.update_desc || '-' },
  {
    prop: 'download_url',
    label: '下载地址',
    minWidth: 220,
    showOverflowTooltip: true,
    formatter: row => row.download_url || '-'
  },
  { prop: 'created_at', label: '创建时间', width: 170, formatter: row => row.created_at || '-' }
];

const toolbarColumns = columns.map(item => ({
  key: String(item.prop),
  label: item.label
}));
const visibleColumnKeys = ref(columns.map(item => String(item.prop)));
const displayColumns = computed(() => columns.filter(item => visibleColumnKeys.value.includes(String(item.prop))));

const isForce = (row: AppVersionRecord) => row.is_force === true || row.is_force === 1;
const isEnabled = (row: AppVersionRecord) => row.enabled !== false && row.enabled !== 0;

const forceCount = computed(() => tableData.value.filter(isForce).length);
const optionalCount = computed(() => tableData.value.filter(item => !isForce(item)).length);
const enabledCount = computed(() => tableData.value.filter(isEnabled).length);

const getTableList = () => {
  loadTable.value = true;
  loadError.value = '';
  commonAppversionListGet(queryFrom)
    .then(res => {
      const data = res as { list?: AppVersionRecord[]; count?: number };
      tableData.value = data.list || [];
      total.value = data.count || 0;
    })
    .catch(err => {
      tableData.value = [];
      total.value = 0;
      loadError.value = err?.msg || 'APP 版本策略加载失败';
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
  queryFrom.os = '';
  queryFrom.is_force = '';
  queryFrom.enabled = '';
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

const appVersionAddValue = ref(false);
const onAppVersionAdd = () => {
  appVersionAddValue.value = true;
};

const onAppVersionOk = () => {
  getTableList();
};

const goLaunchPolicy = () => {
  router.push('/launch-policy/index');
};

const onExport = () => {
  ElMessage.info('导出暂未开放');
};

const onBatch = () => {
  ElMessage.info('批量操作暂未开放');
};

onMounted(() => {
  getTableList();
});
</script>

<style lang="scss" scoped>
.bd-title {
  border-bottom: 1px solid var(--el-card-border-color);
}

.policy-summary {
  display: grid;
  grid-template-columns: repeat(3, minmax(120px, 180px)) minmax(260px, 1fr);
  gap: 12px;
  padding: 12px;
  border-bottom: 1px solid var(--el-card-border-color);
}

.summary-item {
  padding: 10px 12px;
  background: var(--el-fill-color-lighter);
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;

  strong {
    display: block;
    margin-top: 4px;
    font-size: 22px;
    color: var(--el-text-color-primary);
  }
}

.summary-label,
.summary-note,
.footer-hint {
  color: var(--el-text-color-secondary);
}

.summary-note {
  line-height: 22px;
}

.filter-bar {
  padding: 12px 12px 0;
}

.footer-hint {
  font-size: 12px;
}

@media (max-width: 960px) {
  .policy-summary {
    grid-template-columns: 1fr;
  }
}
</style>
