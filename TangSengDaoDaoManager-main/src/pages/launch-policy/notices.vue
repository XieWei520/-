<template>
  <bd-page class="flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">弹窗公告</p>
        </div>
        <div class="flex items-center h-50px">
          <el-button type="primary" @click="onAdd">新增公告</el-button>
        </div>
      </div>
      <div class="flex-1 overflow-hidden p-12px">
        <el-table v-loading="loadTable" :data="tableData" :border="true" style="width: 100%; height: 100%">
          <el-table-column type="index" :width="42" :align="'center'" :fixed="'left'">
            <template #header>
              <i-bd-setting class="cursor-pointer" size="16" />
            </template>
          </el-table-column>
          <el-table-column prop="title" label="标题" fixed="left" width="180" />
          <el-table-column prop="content" label="内容" min-width="260" show-overflow-tooltip />
          <el-table-column prop="platforms" label="平台" width="160">
            <template #default="scope">
              {{ formatPlatforms(scope.row.platforms) }}
            </template>
          </el-table-column>
          <el-table-column prop="frequency" label="展示频率" width="120">
            <template #default="scope">
              {{ frequencyText(scope.row.frequency) }}
            </template>
          </el-table-column>
          <el-table-column prop="enabled" label="状态" width="90">
            <template #default="scope">
              <el-tag :type="scope.row.enabled ? 'success' : 'info'">
                {{ scope.row.enabled ? '启用' : '停用' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="startAt" label="开始时间" width="170">
            <template #default="scope">
              {{ scope.row.startAt || '-' }}
            </template>
          </el-table-column>
          <el-table-column prop="endAt" label="结束时间" width="170">
            <template #default="scope">
              {{ scope.row.endAt || '-' }}
            </template>
          </el-table-column>
          <el-table-column prop="operation" label="操作" align="center" fixed="right" width="120">
            <template #default="scope">
              <el-button type="primary" @click="onEdit(scope.row)">编辑</el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>
      <div class="bd-card-footer pl-12px pr-12px mb-12px flex items-center justify-between">
        <div></div>
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

    <el-dialog
      v-model="dialogVisible"
      :title="formData.id ? '编辑公告' : '新增公告'"
      :width="680"
      :align-center="true"
      :close-on-click-modal="false"
      :draggable="true"
    >
      <el-form :model="formData" label-width="110px">
        <el-form-item label="标题">
          <el-input v-model="formData.title" maxlength="80" show-word-limit />
        </el-form-item>
        <el-form-item label="内容">
          <el-input
            v-model="formData.content"
            type="textarea"
            :autosize="{ minRows: 5, maxRows: 8 }"
            maxlength="1000"
            show-word-limit
          />
        </el-form-item>
        <el-form-item label="图片地址">
          <el-input v-model="formData.image_url" placeholder="可选，客户端支持时展示" />
        </el-form-item>
        <el-form-item label="平台">
          <el-checkbox-group v-model="formData.platforms">
            <el-checkbox label="all">全部</el-checkbox>
            <el-checkbox label="android">Android</el-checkbox>
            <el-checkbox label="windows">Windows</el-checkbox>
          </el-checkbox-group>
        </el-form-item>
        <el-form-item label="展示频率">
          <el-radio-group v-model="formData.frequency">
            <el-radio label="every_start">每次启动</el-radio>
            <el-radio label="daily">每天一次</el-radio>
            <el-radio label="once">只展示一次</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="状态">
          <el-radio-group v-model="formData.enabled">
            <el-radio :label="1">启用</el-radio>
            <el-radio :label="0">停用</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="开始时间">
          <el-date-picker
            v-model="formData.start_at"
            class="!w-100%"
            type="datetime"
            value-format="YYYY-MM-DD HH:mm:ss"
            placeholder="不填表示立即开始"
          />
        </el-form-item>
        <el-form-item label="结束时间">
          <el-date-picker
            v-model="formData.end_at"
            class="!w-100%"
            type="datetime"
            value-format="YYYY-MM-DD HH:mm:ss"
            placeholder="不填表示长期有效"
          />
        </el-form-item>
        <el-form-item label="操作原因">
          <el-input
            v-model="formData.reason"
            type="textarea"
            :autosize="{ minRows: 2, maxRows: 4 }"
            maxlength="500"
            show-word-limit
            placeholder="必填，后端会写入操作审计"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-space>
          <el-button @click="dialogVisible = false">取消</el-button>
          <el-button type="primary" :loading="submitLoading" @click="submitNotice">保存</el-button>
        </el-space>
      </template>
    </el-dialog>
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: 弹窗公告
  isAffix: false
</route>

<script lang="ts" setup>
import { ElMessage } from 'element-plus';
import {
  startupNoticeCreatePost,
  startupNoticeListGet,
  startupNoticeUpdatePut,
  type StartupNoticeRequest
} from '@/api/launchPolicy';

const tableData = ref<any[]>([]);
const loadTable = ref(false);
const submitLoading = ref(false);
const total = ref(0);

const queryFrom = reactive({
  page_size: 15,
  page_index: 1
});

const defaultForm = () => ({
  id: '',
  title: '',
  content: '',
  image_url: '',
  platforms: ['all'],
  frequency: 'once',
  enabled: 1,
  start_at: '',
  end_at: '',
  reason: ''
});

const formData = reactive(defaultForm());
const dialogVisible = ref(false);

const formatPlatforms = (platforms: string[] | string) => {
  if (Array.isArray(platforms)) {
    return platforms.length ? platforms.join(', ') : 'all';
  }
  return platforms || 'all';
};

const frequencyText = (frequency: string) => {
  const map: Record<string, string> = {
    every_start: '每次启动',
    daily: '每天一次',
    once: '只展示一次'
  };
  return map[frequency] || frequency || '-';
};

const normalizeEnabled = (enabled: unknown) => {
  return enabled === true || enabled === 1 ? 1 : 0;
};

const getNoticeList = () => {
  loadTable.value = true;
  startupNoticeListGet(queryFrom)
    .then((res: any) => {
      tableData.value = res.list || [];
      total.value = res.count || 0;
    })
    .finally(() => {
      loadTable.value = false;
    });
};

const onSizeChange = (size: number) => {
  queryFrom.page_size = size;
  getNoticeList();
};

const onCurrentChange = (current: number) => {
  queryFrom.page_index = current;
  getNoticeList();
};

const resetForm = () => {
  Object.assign(formData, defaultForm());
};

const onAdd = () => {
  resetForm();
  dialogVisible.value = true;
};

const onEdit = (row: any) => {
  Object.assign(formData, {
    id: row.id || row.notice_id || '',
    title: row.title || '',
    content: row.content || '',
    image_url: row.imageUrl || row.image_url || '',
    platforms: Array.isArray(row.platforms) && row.platforms.length ? row.platforms : ['all'],
    frequency: row.frequency || 'once',
    enabled: normalizeEnabled(row.enabled),
    start_at: row.startAt || row.start_at || '',
    end_at: row.endAt || row.end_at || '',
    reason: ''
  });
  dialogVisible.value = true;
};

const buildRequest = (): StartupNoticeRequest => {
  const platforms = formData.platforms.includes('all') ? ['all'] : formData.platforms;
  return {
    title: formData.title,
    content: formData.content,
    image_url: formData.image_url,
    platforms,
    frequency: formData.frequency,
    enabled: formData.enabled,
    start_at: formData.start_at,
    end_at: formData.end_at,
    reason: formData.reason.trim()
  };
};

const submitNotice = () => {
  if (!formData.title.trim()) {
    ElMessage.error('请输入公告标题');
    return;
  }
  if (!formData.content.trim()) {
    ElMessage.error('请输入公告内容');
    return;
  }
  if (!formData.platforms.length) {
    ElMessage.error('请选择平台');
    return;
  }
  if (!formData.reason.trim()) {
    ElMessage.error('请输入操作原因');
    return;
  }

  submitLoading.value = true;
  const req = buildRequest();
  const action = formData.id ? startupNoticeUpdatePut(formData.id, req) : startupNoticeCreatePost(req);
  action
    .then(() => {
      ElMessage.success('保存成功');
      dialogVisible.value = false;
      getNoticeList();
    })
    .catch(err => {
      ElMessage.error(err?.msg || '保存失败');
    })
    .finally(() => {
      submitLoading.value = false;
    });
};

onMounted(() => {
  getNoticeList();
});
</script>

<style lang="scss" scoped>
.bd-title {
  border-bottom: 1px solid var(--el-card-border-color);
}
</style>
