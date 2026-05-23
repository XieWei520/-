<template>
  <bd-page class="message-audit-table flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">{{ title }}</p>
        </div>
        <el-space>
          <el-button v-if="mode === 'personal'" @click="openRouteDevices">查看会话设备</el-button>
          <el-button type="primary" :loading="loadTable" @click="getTableList">刷新</el-button>
        </el-space>
      </div>

      <el-alert
        v-if="missingRequiredParams"
        class="m-12px mb-0"
        type="info"
        :closable="false"
        show-icon
        title="请选择用户或会话后再查看聊天记录"
      />

      <el-alert
        class="m-12px mb-0"
        type="warning"
        :closable="false"
        show-icon
        title="消息审计筛选依赖后端支持 sender_uid、target_id、message_type、device_id、start_at、end_at；删除消息必须提交 reason 并写入操作审计。"
      />

      <el-form :model="queryFrom" inline class="filter-bar">
        <el-form-item label="关键词">
          <el-input v-model="queryFrom.keyword" class="!w-180px" clearable placeholder="发送者 / 消息内容" />
        </el-form-item>
        <el-form-item label="发送者">
          <el-input v-model="queryFrom.sender_uid" class="!w-180px" clearable placeholder="sender_uid" />
        </el-form-item>
        <el-form-item :label="mode === 'group' ? '群ID' : '会话对象'">
          <el-input v-model="queryFrom.target_id" class="!w-180px" clearable placeholder="target_id" />
        </el-form-item>
        <el-form-item label="消息类型">
          <el-select v-model="queryFrom.message_type" class="!w-150px" clearable>
            <el-option label="文本" value="text" />
            <el-option label="图片" value="image" />
            <el-option label="语音" value="voice" />
            <el-option label="视频" value="video" />
            <el-option label="文件" value="file" />
            <el-option label="卡片" value="card" />
          </el-select>
        </el-form-item>
        <el-form-item label="设备">
          <el-input v-model="queryFrom.device_id" class="!w-180px" clearable placeholder="device_id" />
        </el-form-item>
        <el-form-item label="时间">
          <el-date-picker
            v-model="auditTimeRange"
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

      <div class="flex-1 overflow-hidden p-12px pt-0">
        <el-table v-loading="loadTable" :data="tableData" :border="true" style="width: 100%; height: 100%">
          <el-table-column type="index" :width="42" :align="'center'" :fixed="'left'">
            <template #header>
              <i-bd-setting class="cursor-pointer" size="16" />
            </template>
          </el-table-column>
          <el-table-column prop="message_id" label="消息编号" min-width="180" fixed="left" show-overflow-tooltip />
          <el-table-column prop="sender_name" label="发送者" width="140" show-overflow-tooltip />
          <el-table-column prop="sender" label="发送者ID" min-width="180" show-overflow-tooltip />
          <el-table-column prop="avatar" label="头像" align="center" width="90">
            <template #default="scope">
              <el-avatar :src="getAvatarUrl(scope.row)" size="48">{{ scope.row.sender_name }}</el-avatar>
            </template>
          </el-table-column>
          <el-table-column prop="target_id" :label="mode === 'group' ? '群ID' : '会话对象'" min-width="180" show-overflow-tooltip>
            <template #default="scope">
              {{ scope.row.target_id || queryFrom.target_id || queryFrom.channel_id || queryFrom.touid || '-' }}
            </template>
          </el-table-column>
          <el-table-column prop="message_type" label="消息类型" width="110">
            <template #default="scope">
              <el-tag type="info">{{ scope.row.message_type || inferMessageType(scope.row.payload) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="payload" label="消息内容" min-width="320">
            <template #default="scope">
              <span v-if="scope.row.is_encrypt === 1">[加密消息，无法查看]</span>
              <BdMsg v-else-if="scope.row.payload" :msg="scope.row.payload" />
              <span v-else>-</span>
            </template>
          </el-table-column>
          <el-table-column prop="device_id" label="设备ID" min-width="160" show-overflow-tooltip />
          <el-table-column prop="device_name" label="设备名称" width="180" show-overflow-tooltip />
          <el-table-column prop="device_model" label="设备类型" width="120" show-overflow-tooltip />
          <el-table-column prop="revoke" label="撤回" width="90">
            <template #default="scope">{{ scope.row.revoke === 1 ? '是' : '否' }}</template>
          </el-table-column>
          <el-table-column prop="is_deleted" label="删除" width="90">
            <template #default="scope">{{ scope.row.is_deleted === 1 ? '是' : '否' }}</template>
          </el-table-column>
          <el-table-column prop="created_at" label="发送时间" width="170" />
          <el-table-column prop="operation" label="操作" width="190" fixed="right">
            <template #default="scope">
              <el-space>
                <el-button type="primary" link @click="openRowDevices(scope.row)">设备</el-button>
                <el-button v-if="scope.row.is_deleted !== 1" type="danger" link @click="onDel(scope.row)">删除</el-button>
              </el-space>
            </template>
          </el-table-column>
          <template #empty>
            <el-empty :description="emptyDescription" />
          </template>
        </el-table>
      </div>

      <div class="bd-card-footer pl-12px pr-12px mb-12px flex items-center justify-between">
        <div class="footer-hint">筛选字段：sender_uid / target_id / message_type / device_id / start_at / end_at；删除提交 reason。</div>
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

    <Devices v-model:value="devicesValue" :uid="devicesUid" />
  </bd-page>
</template>

<script lang="ts" setup>
import { computed, reactive, ref, watch } from 'vue';
import { ElMessage } from 'element-plus';
import BdMsg from '@/components/BdMsg/index.vue';
import { BU_DOU_CONFIG } from '@/config';
import { confirmHighRiskAction } from '@/utils/highRiskAction';
import {
  messageDelete,
  messageRecordGet,
  messageRecordpersonalGet,
  type AdminMessageAuditQuery,
  type AdminMessageAuditRecord
} from '@/api/message';
import Devices from './Devices.vue';

const props = defineProps<{
  title: string;
  mode: 'group' | 'personal';
  channelId?: string | number | null;
  uid?: string | number | null;
  touid?: string | number | null;
}>();

const queryFrom = reactive<AdminMessageAuditQuery>({
  keyword: '',
  channel_id: props.channelId || '',
  channel_type: props.mode === 'group' ? 2 : 1,
  uid: props.uid || '',
  touid: props.touid || '',
  sender_uid: '',
  target_id: props.mode === 'group' ? String(props.channelId || '') : String(props.touid || ''),
  message_type: '',
  device_id: '',
  start_at: '',
  end_at: '',
  page_size: 15,
  page_index: 1
});

const auditTimeRange = ref<[string, string] | []>([]);
const tableData = ref<AdminMessageAuditRecord[]>([]);
const loadTable = ref(false);
const loadError = ref('');
const total = ref(0);
const devicesValue = ref(false);
const devicesUid = ref('');

const missingRequiredParams = computed(() => {
  if (props.mode === 'group') {
    return !props.channelId;
  }
  return !props.uid || !props.touid;
});

const emptyDescription = computed(() => {
  if (missingRequiredParams.value) {
    return props.mode === 'group' ? '请选择群聊后再查看消息审计记录' : '请选择两个用户后再查看单聊记录';
  }
  return loadError.value || '暂无消息审计记录';
});

const getInterfaceError = (err: any, fallback: string) => {
  return err?.status === 404 ? '接口未接入' : err?.msg || fallback;
};

const syncRouteParams = () => {
  queryFrom.channel_id = props.channelId || '';
  queryFrom.channel_type = props.mode === 'group' ? 2 : 1;
  queryFrom.uid = props.uid || '';
  queryFrom.touid = props.touid || '';
  queryFrom.target_id = props.mode === 'group' ? String(props.channelId || '') : String(props.touid || '');
};

const syncTimeRange = () => {
  queryFrom.start_at = auditTimeRange.value[0] || '';
  queryFrom.end_at = auditTimeRange.value[1] || '';
};

const getAvatarUrl = (row: AdminMessageAuditRecord) => {
  const uid = row.sender || row.sender_uid;
  return uid ? `${BU_DOU_CONFIG.APP_URL}users/${uid}/avatar` : '';
};

const inferMessageType = (payload: unknown) => {
  if (!payload) return '-';
  if (typeof payload === 'string') return 'text';
  const value = payload as Record<string, unknown>;
  return String(value.type || value.content_type || value.message_type || 'unknown');
};

const getTableList = () => {
  syncRouteParams();
  if (missingRequiredParams.value) {
    tableData.value = [];
    total.value = 0;
    loadError.value = '';
    loadTable.value = false;
    return;
  }
  syncTimeRange();
  loadTable.value = true;
  loadError.value = '';
  const request = props.mode === 'group' ? messageRecordGet : messageRecordpersonalGet;
  request(queryFrom)
    .then(res => {
      const data = res as { list?: AdminMessageAuditRecord[]; count?: number };
      tableData.value = data.list || [];
      total.value = data.count || 0;
    })
    .catch(err => {
      tableData.value = [];
      total.value = 0;
      loadError.value = getInterfaceError(err, '消息审计加载失败');
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
  queryFrom.keyword = '';
  queryFrom.sender_uid = '';
  queryFrom.target_id = props.mode === 'group' ? String(props.channelId || '') : String(props.touid || '');
  queryFrom.message_type = '';
  queryFrom.device_id = '';
  auditTimeRange.value = [];
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

const deleteMessage = (row: AdminMessageAuditRecord, reason: string) => {
  const formData =
    props.mode === 'group'
      ? {
          channel_id: props.channelId,
          channel_type: 2 as const,
          reason,
          list: [{ message_id: row.message_id, message_seq: row.message_seq }]
        }
      : {
          channel_id: props.uid,
          channel_type: 1 as const,
          from_uid: props.touid,
          reason,
          list: [{ message_id: row.message_id, message_seq: row.message_seq }]
        };

  messageDelete(formData).then((res: any) => {
    if (res.status === 200) {
      getTableList();
      ElMessage.success('删除成功');
    }
  });
};

const onDel = (row: AdminMessageAuditRecord) => {
  confirmHighRiskAction('删除消息', '确定删除此消息？删除消息属于高危操作。')
    .then(({ reason }) => {
      deleteMessage(row, reason);
    })
    .catch(() => {
      ElMessage.info('已取消');
    });
};

const openRowDevices = (row: AdminMessageAuditRecord) => {
  const uid = row.sender || row.sender_uid;
  if (!uid) {
    ElMessage.warning('无用户，不能查看设备');
    return;
  }
  devicesUid.value = uid;
  devicesValue.value = true;
};

const openRouteDevices = () => {
  if (!props.uid) {
    ElMessage.warning('无用户，不能查看设备');
    return;
  }
  devicesUid.value = String(props.uid);
  devicesValue.value = true;
};

onMounted(() => {
  getTableList();
});

watch(
  () => [props.channelId, props.uid, props.touid, props.mode],
  () => {
    getTableList();
  }
);
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
</style>
