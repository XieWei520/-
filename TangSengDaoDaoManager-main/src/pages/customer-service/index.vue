<template>
  <bd-page class="flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">客服人员设置</p>
        </div>
        <div class="flex items-center h-50px">
          <el-form inline>
            <el-form-item class="mb-0 !mr-16px">
              <el-input v-model="queryFrom.keyword" placeholder="uid/手机号/用户名" clearable />
            </el-form-item>
            <el-form-item class="mb-0 !mr-0">
              <el-button type="primary" @click="getUserList">查询</el-button>
            </el-form-item>
          </el-form>
        </div>
      </div>

      <el-alert
        class="m-12px mb-0"
        type="warning"
        :closable="false"
        show-icon
        title="客服设置、默认客服切换、移除客服属于高危操作，提交时必须填写 reason，并由后端写入操作审计。"
      />

      <div class="flex-1 overflow-hidden p-12px">
        <el-table v-loading="loadTable" :data="tableData" :border="true" style="width: 100%; height: 100%">
          <el-table-column type="index" :width="42" :align="'center'" :fixed="'left'">
            <template #header>
              <i-bd-setting class="cursor-pointer" size="16" />
            </template>
          </el-table-column>
          <el-table-column prop="name" label="昵称" fixed="left" width="140" />
          <el-table-column prop="phone" label="手机号" width="130" />
          <el-table-column prop="uid" label="用户ID" min-width="260" />
          <el-table-column prop="is_customer_service" label="客服状态" width="120">
            <template #default="scope">
              <el-tag :type="isCustomerService(scope.row) ? 'success' : 'info'">
                {{ isCustomerService(scope.row) ? '已设置' : '未设置' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="is_default_customer_service" label="默认客服" width="120">
            <template #default="scope">{{ isDefaultCustomerService(scope.row) ? '是' : '否' }}</template>
          </el-table-column>
          <el-table-column prop="customer_service_rank" label="排序" width="100">
            <template #default="scope">{{ scope.row.customer_service_rank || '-' }}</template>
          </el-table-column>
          <el-table-column prop="status" label="用户状态" width="90">
            <template #default="scope">{{ scope.row.status === 1 ? '正常' : '封禁' }}</template>
          </el-table-column>
          <el-table-column prop="operation" label="操作" align="center" fixed="right" width="260">
            <template #default="scope">
              <el-space>
                <el-button type="primary" @click="setStaff(scope.row, true, false)">设为客服</el-button>
                <el-button type="warning" plain @click="setStaff(scope.row, true, true)">设为默认</el-button>
                <el-button type="danger" plain @click="setStaff(scope.row, false, false)">移除</el-button>
              </el-space>
            </template>
          </el-table-column>
          <template #empty>
            <el-empty description="暂无数据" />
          </template>
        </el-table>
      </div>

      <div class="bd-card-footer pl-12px pr-12px mb-12px flex items-center justify-between">
        <div class="footer-hint">客服设置请求都会携带 reason。</div>
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
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: 客服人员设置
  isAffix: false
</route>

<script lang="ts" setup>
import { ElMessage } from 'element-plus';
import { confirmHighRiskAction } from '@/utils/highRiskAction';
import { userListGet } from '@/api/user';
import { setCustomerServicePost } from '@/api/customerService';

const tableData = ref<any[]>([]);
const loadTable = ref(false);
const total = ref(0);

const queryFrom = reactive({
  keyword: '',
  page_size: 15,
  page_index: 1
});

const isCustomerService = (row: any) => row.is_customer_service === true || row.is_customer_service === 1;
const isDefaultCustomerService = (row: any) => row.is_default_customer_service === true || row.is_default_customer_service === 1;

const getUserList = () => {
  loadTable.value = true;
  userListGet(queryFrom)
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
  getUserList();
};

const onCurrentChange = (current: number) => {
  queryFrom.page_index = current;
  getUserList();
};

const setStaff = (row: any, enabled: boolean, isDefault: boolean) => {
  const actionText = !enabled ? '移除客服身份' : isDefault ? '设为默认客服' : '设为客服';
  confirmHighRiskAction(actionText, `确定要将 ${row.name || row.uid} ${actionText} 吗？`)
    .then(({ reason }) =>
      setCustomerServicePost({
        uid: row.uid,
        enabled,
        is_default: isDefault,
        reason
      })
    )
    .then(() => {
      ElMessage.success(`${actionText}成功`);
      getUserList();
    })
    .catch(err => {
      if (err !== 'cancel') ElMessage.error(err?.msg || `${actionText}失败`);
    });
};

onMounted(() => {
  getUserList();
});
</script>

<style lang="scss" scoped>
.bd-title {
  border-bottom: 1px solid var(--el-card-border-color);
}

.footer-hint {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}
</style>
