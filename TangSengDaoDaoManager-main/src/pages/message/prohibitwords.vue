<template>
  <bd-page class="content-safety-policy flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">违禁词策略</p>
        </div>
        <el-space>
          <el-button @click="openHitLogDialog">命中日志</el-button>
          <el-button type="primary" @click="onAddProhitWords">新增违禁词</el-button>
        </el-space>
      </div>

      <el-alert
        class="m-12px mb-0"
        type="info"
        :closable="false"
        show-icon
        title="策略版本、发布、回滚、命中日志和词库维护已接入后端；导出和批量操作仍为后续能力。"
      />

      <div class="policy-summary">
        <div v-for="item in policySummary" :key="item.key" class="policy-summary__item">
          <div class="policy-summary__label">{{ item.label }}</div>
          <div class="policy-summary__value">{{ item.value }}</div>
          <div class="policy-summary__meta">{{ item.meta }}</div>
        </div>
      </div>

      <el-tabs v-model="activeTab" class="policy-tabs">
        <el-tab-pane label="策略版本" name="policy">
          <el-form :model="policyQuery" inline class="filter-bar">
            <el-form-item label="关键词">
              <el-input v-model="policyQuery.keyword" class="!w-180px" clearable placeholder="策略名 / 版本" />
            </el-form-item>
            <el-form-item label="分组">
              <el-input v-model="policyQuery.group" class="!w-150px" clearable placeholder="chat/group" />
            </el-form-item>
            <el-form-item label="状态">
              <el-select v-model="policyQuery.status" class="!w-150px" clearable>
                <el-option label="草稿" value="draft" />
                <el-option label="已发布" value="published" />
                <el-option label="已停用" value="disabled" />
                <el-option label="已回滚" value="rolled_back" />
              </el-select>
            </el-form-item>
            <el-form-item>
              <el-button type="primary" :loading="policyLoading" @click="onPolicySearch">查询</el-button>
              <el-button @click="onPolicyReset">重置</el-button>
            </el-form-item>
          </el-form>

          <div class="flex-1 overflow-hidden p-12px pt-0">
            <el-table v-loading="policyLoading" :data="policyTableData" :border="true" class="policy-table">
              <el-table-column prop="version" label="版本" width="140" fixed="left" />
              <el-table-column prop="name" label="策略名" min-width="160" show-overflow-tooltip />
              <el-table-column prop="group" label="分组" width="120" />
              <el-table-column prop="status" label="状态" width="120">
                <template #default="scope">
                  <el-tag :type="policyStatusType(scope.row.status)">{{ policyStatusText(scope.row.status) }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="word_count" label="词数量" width="100" />
              <el-table-column prop="hit_count" label="命中数" width="100" />
              <el-table-column prop="published_at" label="发布时间" width="170" />
              <el-table-column prop="published_by" label="发布人" width="140" />
              <el-table-column prop="operation" label="操作" width="240" fixed="right">
                <template #default="scope">
                  <el-space>
                    <el-button type="primary" link @click="publishPolicy(scope.row)">发布</el-button>
                    <el-button type="warning" link @click="rollbackPolicy(scope.row)">回滚</el-button>
                    <el-button type="primary" link @click="openHitLogDialog(scope.row.version)">命中日志</el-button>
                  </el-space>
                </template>
              </el-table-column>
                <template #empty>
                  <el-empty :description="policyLoadError || '暂无策略版本'" />
                </template>
            </el-table>
          </div>
        </el-tab-pane>

        <el-tab-pane label="词库列表" name="words">
          <div class="word-list-pane">
            <div class="word-list-pane__head">
              <el-form inline>
                <el-form-item class="mb-0 !mr-16px">
                  <el-input v-model="queryFrom.search_key" placeholder="请输入违禁词" clearable />
                </el-form-item>
                <el-form-item class="mb-0 !mr-0">
                  <el-button type="primary" :loading="loadTable" @click="getTableList">查询</el-button>
                  <el-button @click="onAddProhitWords">新增违禁词</el-button>
                </el-form-item>
              </el-form>
            </div>

            <BdTableToolbar
              v-model="visibleColumnKeys"
              :columns="toolbarColumns"
              :selected-count="selectedRows.length"
              @refresh="getTableList"
              @export="onExport"
              @batch="onBatch"
            />

            <div class="word-table-wrap">
              <el-table
                v-loading="loadTable"
                :data="tableData"
                :border="true"
                style="width: 100%; height: 100%"
                @selection-change="onSelectionChange"
              >
                <el-table-column type="selection" :width="42" :align="'center'" :fixed="'left'" />
                <el-table-column type="index" :width="42" :align="'center'" :fixed="'left'">
                  <template #header>
                    <i-bd-setting class="cursor-pointer" size="16" />
                  </template>
                </el-table-column>
                <el-table-column v-for="item in displayColumns" :key="item.prop" v-bind="item">
                  <template #default="scope">
                    <template v-if="item.prop === 'is_deleted'">
                      <el-tag :type="scope.row.is_deleted === 1 ? 'danger' : 'success'">
                        {{ scope.row.is_deleted === 1 ? '已删除' : '启用中' }}
                      </el-tag>
                    </template>
                    <template v-else-if="item.prop === 'operation'">
                      <el-button :type="scope.row.is_deleted === 0 ? 'danger' : 'warning'" @click="onDel(scope.row)">
                        {{ scope.row.is_deleted === 0 ? '删除' : '恢复' }}
                      </el-button>
                    </template>
                    <template v-else-if="item.prop">
                      {{ scope.row[item.prop] || '-' }}
                    </template>
                  </template>
                </el-table-column>
                <template #empty>
                  <el-empty description="暂无数据" />
                </template>
              </el-table>
            </div>

            <div class="bd-card-footer pl-12px pr-12px mb-12px flex items-center justify-between">
              <div class="word-footer-hint">发布、回滚和批量操作必须写入后端操作审计。</div>
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
        </el-tab-pane>
      </el-tabs>
    </div>

    <bd-prohit-words v-model:value="prohitWordsValue" @ok="okSand" />

    <el-dialog
      v-model="hitLogDialogVisible"
      class="forbidden-word-hit-log"
      title="违禁词命中日志"
      :width="960"
      :align-center="true"
      :draggable="true"
      @open="getHitLogList"
    >
      <el-form :model="hitLogQuery" inline class="hit-log-filter">
        <el-form-item label="版本">
          <el-input v-model="hitLogQuery.policy_version" class="!w-140px" clearable />
        </el-form-item>
        <el-form-item label="用户">
          <el-input v-model="hitLogQuery.uid" class="!w-160px" clearable placeholder="uid" />
        </el-form-item>
        <el-form-item label="关键词">
          <el-input v-model="hitLogQuery.keyword" class="!w-160px" clearable />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="hitLogLoading" @click="onHitLogSearch">查询</el-button>
        </el-form-item>
      </el-form>

      <el-table v-loading="hitLogLoading" :data="hitLogTableData" :border="true" height="420">
        <el-table-column prop="created_at" label="时间" width="170" />
        <el-table-column prop="policy_version" label="版本" width="120" />
        <el-table-column prop="group" label="分组" width="100" />
        <el-table-column prop="word" label="命中词" width="120" />
        <el-table-column prop="uid" label="用户" min-width="160" show-overflow-tooltip />
        <el-table-column prop="target_type" label="对象" width="100" />
        <el-table-column prop="target_id" label="对象ID" min-width="160" show-overflow-tooltip />
        <el-table-column prop="action" label="动作" width="100" />
        <el-table-column prop="content_preview" label="内容摘要" min-width="220" show-overflow-tooltip />
        <template #empty>
          <el-empty :description="hitLogLoadError || '暂无命中日志'" />
        </template>
      </el-table>

      <template #footer>
        <div class="dialog-footer">
          <span>{{ hitLogLoadError || `共 ${hitLogTotal} 条` }}</span>
          <el-pagination
            v-model:current-page="hitLogQuery.page_index"
            v-model:page-size="hitLogQuery.page_size"
            :page-sizes="[15, 30, 50]"
            :background="true"
            layout="sizes, prev, pager, next"
            :total="hitLogTotal"
            @size-change="onHitLogSizeChange"
            @current-change="onHitLogCurrentChange"
          />
        </div>
      </template>
    </el-dialog>
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: 违禁词策略
  isAffix: false
</route>

<script lang="ts" setup>
import { computed, reactive, ref, watch } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import BdTableToolbar from '@/components/BdTableToolbar/index.vue';
import {
  messageForbiddenWordHitLogsGet,
  messageForbiddenWordPoliciesGet,
  messageForbiddenWordPolicyPublishPost,
  messageForbiddenWordPolicyRollbackPost,
  messageProhibitWordsDelete,
  messageProhibitWordsGet,
  type AdminForbiddenWordHitLogQuery,
  type AdminForbiddenWordHitLogRecord,
  type AdminForbiddenWordPolicyQuery,
  type AdminForbiddenWordPolicyRecord
} from '@/api/message';

interface ProhibitWordRecord {
  id: string | number;
  content: string;
  is_deleted: number;
  created_at?: string;
}

interface WordColumn {
  prop: keyof ProhibitWordRecord | 'operation';
  label: string;
  width?: number;
  minWidth?: number;
  align?: 'left' | 'center' | 'right';
  fixed?: 'left' | 'right';
}

const activeTab = ref('policy');
const policyLoading = ref(false);
const policyLoadError = ref('');
const policyTotal = ref(0);
const policyTableData = ref<AdminForbiddenWordPolicyRecord[]>([]);
const policyVersion = computed(() => policyTableData.value.find(item => item.status === 'published')?.version || '-');

const policyQuery = reactive<AdminForbiddenWordPolicyQuery>({
  page_size: 15,
  page_index: 1,
  keyword: '',
  group: '',
  status: '',
  version: ''
});

const queryFrom = reactive({
  search_key: '',
  page_size: 15,
  page_index: 1
});

const tableData = ref<ProhibitWordRecord[]>([]);
const loadTable = ref(false);
const selectedRows = ref<ProhibitWordRecord[]>([]);
const total = ref(0);
const prohitWordsValue = ref(false);

const hitLogDialogVisible = ref(false);
const hitLogLoading = ref(false);
const hitLogLoadError = ref('');
const hitLogTotal = ref(0);
const hitLogTableData = ref<AdminForbiddenWordHitLogRecord[]>([]);
const hitLogQuery = reactive<AdminForbiddenWordHitLogQuery>({
  page_size: 15,
  page_index: 1,
  keyword: '',
  group: '',
  policy_version: '',
  uid: '',
  target_id: '',
  start_at: '',
  end_at: ''
});

const wordColumns: WordColumn[] = [
  { prop: 'content', label: '违禁词', minWidth: 220 },
  { prop: 'is_deleted', label: '状态', width: 120, align: 'center' },
  { prop: 'created_at', label: '创建时间', width: 180 },
  { prop: 'operation', label: '操作', align: 'center', fixed: 'right', width: 120 }
];

const toolbarColumns = computed(() =>
  wordColumns
    .filter(item => item.prop !== 'operation')
    .map(item => ({ key: String(item.prop), label: item.label || String(item.prop) }))
);
const visibleColumnKeys = ref<string[]>(toolbarColumns.value.map(item => item.key));
const displayColumns = computed(() =>
  wordColumns.filter(item => item.prop === 'operation' || visibleColumnKeys.value.includes(String(item.prop)))
);

const policySummary = computed(() => [
  {
    key: 'published',
    label: '当前发布版本',
    value: policyVersion.value,
    meta: policyLoadError.value || '/manager/message/prohibit_word_policies'
  },
  {
    key: 'policies',
    label: '策略版本数',
    value: String(policyTotal.value || policyTableData.value.length),
    meta: '分组、版本、发布、回滚'
  },
    {
      key: 'hitLogs',
      label: '命中日志',
      value: hitLogLoadError.value ? '加载失败' : String(hitLogTotal.value),
      meta: '/manager/message/prohibit_word_hit_logs'
    }
  ]);

watch(
  toolbarColumns,
  columns => {
    if (!visibleColumnKeys.value.length) visibleColumnKeys.value = columns.map(item => item.key);
  },
  { immediate: true }
);

const getInterfaceError = (err: any, fallback: string) => {
  return err?.status === 404 ? '接口未接入' : err?.msg || fallback;
};

const policyStatusText = (status: string) => {
  const statusMap: Record<string, string> = {
    draft: '草稿',
    published: '已发布',
    disabled: '已停用',
    rolled_back: '已回滚'
  };
  return statusMap[status] || status || '-';
};

const policyStatusType = (status: string) => {
  const typeMap: Record<string, 'success' | 'warning' | 'info' | 'danger'> = {
    draft: 'info',
    published: 'success',
    disabled: 'danger',
    rolled_back: 'warning'
  };
  return typeMap[status] || 'info';
};

const getPolicyList = () => {
  policyLoading.value = true;
  policyLoadError.value = '';
  messageForbiddenWordPoliciesGet(policyQuery)
    .then(res => {
      const data = res as { list?: AdminForbiddenWordPolicyRecord[]; count?: number };
      policyTableData.value = data.list || [];
      policyTotal.value = data.count || 0;
    })
    .catch(err => {
      policyTableData.value = [];
      policyTotal.value = 0;
      policyLoadError.value = getInterfaceError(err, '策略版本加载失败');
      ElMessage.error(policyLoadError.value);
    })
    .finally(() => {
      policyLoading.value = false;
    });
};

const onPolicySearch = () => {
  policyQuery.page_index = 1;
  getPolicyList();
};

const onPolicyReset = () => {
  policyQuery.keyword = '';
  policyQuery.group = '';
  policyQuery.status = '';
  policyQuery.version = '';
  onPolicySearch();
};

const promptPolicyReason = (title: string, inputPlaceholder: string) => {
  return ElMessageBox.prompt(inputPlaceholder, title, {
    confirmButtonText: '确认',
    cancelButtonText: '取消',
    inputType: 'textarea',
    inputValidator: value => Boolean(value?.trim()),
    inputErrorMessage: '必须填写操作原因，后端审计需要 reason'
  });
};

const publishPolicy = (row: AdminForbiddenWordPolicyRecord) => {
  promptPolicyReason(`发布策略 ${row.version}`, '请输入发布原因')
    .then(({ value }) =>
      messageForbiddenWordPolicyPublishPost({
        version: row.version,
        reason: value.trim()
      })
    )
    .then(() => {
      ElMessage.success('发布成功');
      getPolicyList();
    })
    .catch(err => {
      if (err !== 'cancel') ElMessage.error(getInterfaceError(err, '发布失败'));
    });
};

const rollbackPolicy = (row: AdminForbiddenWordPolicyRecord) => {
  promptPolicyReason(`回滚到 ${row.version}`, '请输入回滚原因')
    .then(({ value }) =>
      messageForbiddenWordPolicyRollbackPost({
        target_version: row.version,
        reason: value.trim()
      })
    )
    .then(() => {
      ElMessage.success('回滚成功');
      getPolicyList();
    })
    .catch(err => {
      if (err !== 'cancel') ElMessage.error(getInterfaceError(err, '回滚失败'));
    });
};

const getTableList = () => {
  loadTable.value = true;
  messageProhibitWordsGet(queryFrom)
    .then(res => {
      const data = res as { list?: ProhibitWordRecord[]; count?: number };
      tableData.value = data.list || [];
      total.value = data.count || 0;
    })
    .catch(err => {
      tableData.value = [];
      total.value = 0;
      ElMessage.error(getInterfaceError(err, '违禁词列表加载失败'));
    })
    .finally(() => {
      loadTable.value = false;
    });
};

const onSelectionChange = (rows: ProhibitWordRecord[]) => {
  selectedRows.value = rows;
};

const onExport = () => {
  ElMessage.info('导出暂未开放');
};

const onBatch = () => {
  ElMessageBox.confirm(`已选择 ${selectedRows.value.length} 条违禁词，批量操作暂未开放。`, '批量操作', {
    confirmButtonText: '知道了',
    showCancelButton: false,
    closeOnClickModal: false,
    type: 'warning'
  });
};

const onSizeChange = (size: number) => {
  queryFrom.page_size = size;
  getTableList();
};

const onCurrentChange = (current: number) => {
  queryFrom.page_index = current;
  getTableList();
};

const onAddProhitWords = () => {
  prohitWordsValue.value = true;
};

const okSand = () => {
  getTableList();
};

const prohitWordsDel = (item: ProhibitWordRecord) => {
  const formData = {
    is_deleted: item.is_deleted === 1 ? 0 : 1,
    id: item.id
  };
  const msg = item.is_deleted === 0 ? '删除违禁词成功' : '恢复违禁词成功';
  messageProhibitWordsDelete(formData).then((res: any) => {
    if (res.status === 200) {
      getTableList();
      ElMessage.success(msg);
    }
  });
};

const onDel = (item: ProhibitWordRecord) => {
  const title = item.is_deleted === 0 ? '删除违禁词' : '恢复违禁词';
  const content = item.is_deleted === 0 ? `确定要删除违禁词 [${item.content}] 吗？` : `确定要恢复违禁词 [${item.content}] 吗？`;
  ElMessageBox.confirm(content, title, {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    closeOnClickModal: false,
    type: 'warning'
  })
    .then(() => {
      prohitWordsDel(item);
    })
    .catch(() => {
      ElMessage.info('已取消');
    });
};

const openHitLogDialog = (version = '') => {
  hitLogQuery.policy_version = version;
  hitLogQuery.page_index = 1;
  hitLogDialogVisible.value = true;
};

const getHitLogList = () => {
  if (!hitLogDialogVisible.value) return;
  hitLogLoading.value = true;
  hitLogLoadError.value = '';
  messageForbiddenWordHitLogsGet(hitLogQuery)
    .then(res => {
      const data = res as { list?: AdminForbiddenWordHitLogRecord[]; count?: number };
      hitLogTableData.value = data.list || [];
      hitLogTotal.value = data.count || 0;
    })
    .catch(err => {
      hitLogTableData.value = [];
      hitLogTotal.value = 0;
      hitLogLoadError.value = getInterfaceError(err, '命中日志加载失败');
      ElMessage.error(hitLogLoadError.value);
    })
    .finally(() => {
      hitLogLoading.value = false;
    });
};

const onHitLogSearch = () => {
  hitLogQuery.page_index = 1;
  getHitLogList();
};

const onHitLogSizeChange = (size: number) => {
  hitLogQuery.page_size = size;
  getHitLogList();
};

const onHitLogCurrentChange = (current: number) => {
  hitLogQuery.page_index = current;
  getHitLogList();
};

onMounted(() => {
  getPolicyList();
  getTableList();
});
</script>

<style lang="scss" scoped>
.bd-title {
  border-bottom: 1px solid var(--el-card-border-color);
}

.policy-summary {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  padding: 12px;
}

.policy-summary__item {
  min-height: 92px;
  padding: 12px;
  background: var(--el-bg-color);
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
}

.policy-summary__label,
.policy-summary__meta,
.word-footer-hint {
  color: var(--el-text-color-secondary);
}

.policy-summary__value {
  margin-top: 10px;
  font-size: 22px;
  font-weight: 600;
}

.policy-summary__meta {
  margin-top: 6px;
  font-size: 12px;
}

.policy-tabs {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  padding: 0 12px 12px;
}

.filter-bar,
.hit-log-filter {
  padding: 12px 0 0;
}

.policy-table {
  width: 100%;
  height: 420px;
}

.word-list-pane {
  display: flex;
  height: 100%;
  min-height: 0;
  flex-direction: column;
}

.word-list-pane__head {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  padding: 0 0 10px;
}

.word-table-wrap {
  flex: 1;
  min-height: 360px;
  overflow: hidden;
}

.dialog-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

@media (max-width: 900px) {
  .policy-summary {
    grid-template-columns: 1fr;
  }
}
</style>
