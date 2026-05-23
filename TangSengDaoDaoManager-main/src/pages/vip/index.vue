<template>
  <bd-page class="flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">用户VIP</p>
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
        title="设置或撤销 VIP 属于高危操作，提交时必须填写 reason，并由后端写入操作审计。"
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
          <el-table-column prop="username" label="用户名" width="130" />
          <el-table-column prop="uid" label="用户ID" min-width="260" />
          <el-table-column prop="vip_level" label="VIP等级" width="110">
            <template #default="scope">
              <el-tag :type="Number(scope.row.vip_level) > 0 ? 'warning' : 'info'">
                {{ Number(scope.row.vip_level) > 0 ? `VIP ${scope.row.vip_level}` : '普通' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="vip_expire_time" label="到期时间" width="180">
            <template #default="scope">{{ scope.row.vip_expire_time || '-' }}</template>
          </el-table-column>
          <el-table-column prop="status" label="用户状态" width="90">
            <template #default="scope">{{ scope.row.status === 1 ? '正常' : '封禁' }}</template>
          </el-table-column>
          <el-table-column prop="operation" label="操作" align="center" fixed="right" width="180">
            <template #default="scope">
              <el-space>
                <el-button type="primary" @click="onGrant(scope.row)">设置VIP</el-button>
                <el-button type="danger" plain @click="onRevoke(scope.row)">撤销</el-button>
              </el-space>
            </template>
          </el-table-column>
          <template #empty>
            <el-empty description="暂无数据" />
          </template>
        </el-table>
      </div>

      <div class="bd-card-footer pl-12px pr-12px mb-12px flex items-center justify-between">
        <div class="footer-hint">VIP 授权、续期、撤销请求都会携带 reason。</div>
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
      v-model="grantDialogVisible"
      title="设置VIP"
      :width="520"
      :align-center="true"
      :close-on-click-modal="false"
      :draggable="true"
    >
      <el-form :model="grantForm" label-width="100px">
        <el-form-item label="用户">
          <el-input v-model="grantForm.name" disabled />
        </el-form-item>
        <el-form-item label="用户ID">
          <el-input v-model="grantForm.uid" disabled />
        </el-form-item>
        <el-form-item label="VIP等级">
          <el-select v-model="grantForm.vip_level" class="!w-100%">
            <el-option label="商户VIP" :value="1" />
          </el-select>
        </el-form-item>
        <el-form-item label="到期时间">
          <el-date-picker
            v-model="grantForm.vip_expire_time"
            class="!w-100%"
            type="datetime"
            value-format="YYYY-MM-DD HH:mm:ss"
            placeholder="选择到期时间"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-space>
          <el-button @click="grantDialogVisible = false">取消</el-button>
          <el-button type="primary" :loading="submitLoading" @click="submitGrant">保存</el-button>
        </el-space>
      </template>
    </el-dialog>
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: 用户VIP
  isAffix: false
</route>

<script lang="ts" setup>
import { ElMessage } from 'element-plus';
import { confirmHighRiskAction } from '@/utils/highRiskAction';
import { userListGet } from '@/api/user';
import { setVipPost } from '@/api/vip';

const tableData = ref<any[]>([]);
const loadTable = ref(false);
const total = ref(0);
const submitLoading = ref(false);

const queryFrom = reactive({
  keyword: '',
  page_size: 15,
  page_index: 1
});

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

const grantDialogVisible = ref(false);
const grantForm = reactive({
  uid: '',
  name: '',
  vip_level: 1,
  vip_expire_time: ''
});

const onGrant = (row: any) => {
  grantForm.uid = row.uid;
  grantForm.name = row.name;
  grantForm.vip_level = Number(row.vip_level) > 0 ? Number(row.vip_level) : 1;
  grantForm.vip_expire_time = row.vip_expire_time || '';
  grantDialogVisible.value = true;
};

const submitGrant = () => {
  if (!grantForm.uid) {
    ElMessage.error('请选择用户');
    return;
  }
  if (!grantForm.vip_expire_time) {
    ElMessage.error('请选择VIP到期时间');
    return;
  }

  confirmHighRiskAction('设置VIP', `确定要设置 ${grantForm.name || grantForm.uid} 的 VIP 权益吗？`)
    .then(({ reason }) => {
      submitLoading.value = true;
      return setVipPost({
        uid: grantForm.uid,
        vip_level: grantForm.vip_level,
        vip_expire_time: grantForm.vip_expire_time,
        reason
      });
    })
    .then(() => {
      ElMessage.success('VIP设置成功');
      grantDialogVisible.value = false;
      getUserList();
    })
    .catch(err => {
      if (err !== 'cancel') ElMessage.error(err?.msg || 'VIP设置失败');
    })
    .finally(() => {
      submitLoading.value = false;
    });
};

const onRevoke = (row: any) => {
  confirmHighRiskAction('撤销VIP', `确定要撤销 ${row.name || row.uid} 的 VIP 吗？`)
    .then(({ reason }) =>
      setVipPost({
        uid: row.uid,
        vip_level: 0,
        vip_expire_time: '',
        reason
      })
    )
    .then(() => {
      ElMessage.success('VIP已撤销');
      getUserList();
    })
    .catch(err => {
      if (err !== 'cancel') ElMessage.error(err?.msg || '撤销VIP失败');
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
