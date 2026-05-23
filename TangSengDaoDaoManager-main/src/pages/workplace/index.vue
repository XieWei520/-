<template>
  <bd-page class="workplace-control flex-col">
    <div class="flex-1 el-card border-none flex-col box-border overflow-hidden">
      <div class="h-50px pl-12px pr-12px box-border flex items-center justify-between bd-title">
        <div class="bd-title-left">
          <p class="m-0 font-600">工作台总览</p>
        </div>
        <el-space>
          <el-button @click="goTo('/workplace/manage')">应用管理</el-button>
          <el-button type="primary" @click="goTo('/workplace/configuration')">工作台配置</el-button>
        </el-space>
      </div>

      <div class="flex-1 overflow-auto p-12px">
        <el-alert
          class="mb-12px"
          type="info"
          :closable="false"
          show-icon
          title="工作台已有应用、分类、Banner 和排序接口；用户侧启用模块、平台/VIP/角色可见范围仍需要后端补契约。"
        />

        <el-row :gutter="12" class="mb-12px">
          <el-col v-for="item in summaryCards" :key="item.key" :xs="24" :md="8">
            <div class="summary-card">
              <div class="summary-card__head">
                <span>{{ item.title }}</span>
                <el-tag :type="item.connected ? 'success' : 'info'">{{ item.connected ? '已接入' : '待设计' }}</el-tag>
              </div>
              <div class="summary-card__value">{{ item.value }}</div>
              <div class="summary-card__meta">{{ item.meta }}</div>
              <el-button class="mt-12px" :disabled="!item.path" type="primary" plain @click="item.path && goTo(item.path)">
                {{ item.action }}
              </el-button>
            </div>
          </el-col>
        </el-row>

        <div class="control-panel">
          <div class="control-panel__title">第三阶段 3.2 能力矩阵</div>
          <el-table :data="capabilities" border>
            <el-table-column prop="module" label="模块" width="150" />
            <el-table-column prop="scope" label="运营能力" min-width="260" />
            <el-table-column prop="endpoint" label="后端接口" min-width="260" show-overflow-tooltip />
            <el-table-column prop="status" label="状态" width="120">
              <template #default="scope">
                <el-tag :type="scope.row.status === '已接入' ? 'success' : 'info'">{{ scope.row.status }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="next" label="下一步" min-width="240" />
          </el-table>
        </div>
      </div>
    </div>
  </bd-page>
</template>

<route lang="yaml">
meta:
  title: 工作台总览
  isAffix: false
</route>

<script lang="ts" setup>
import { useRouter } from 'vue-router';

const router = useRouter();

const goTo = (path: string) => {
  router.push(path);
};

const summaryCards = [
  {
    key: 'apps',
    title: '应用管理',
    value: '应用 CRUD',
    meta: '已接入 /manager/workplace/app，可管理名称、图标、状态、描述。',
    connected: true,
    path: '/workplace/manage',
    action: '进入应用管理'
  },
  {
    key: 'banner',
    title: 'Banner 与分类',
    value: '排序已接入',
    meta: '已接入 banner/category/reorder，可维护轮播、分类和分类应用。',
    connected: true,
    path: '/workplace/configuration',
    action: '进入工作台配置'
  },
  {
    key: 'visibility',
    title: '可见范围',
    value: '待设计',
    meta: '平台、用户、角色、VIP 等可见范围需要后端新增字段和管理接口。',
    connected: false,
    path: '',
    action: '等待方案确认'
  }
];

const capabilities = [
  {
    module: '应用',
    scope: '新增、编辑、删除、启用/停用',
    endpoint: '/manager/workplace/app',
    status: '已接入',
    next: '补 API 类型和表格统一交互'
  },
  {
    module: '分类',
    scope: '分类 CRUD、分类排序、分类内应用',
    endpoint: '/manager/workplace/category, /manager/workplace/category/reorder',
    status: '已接入',
    next: '补列配置、空态和错误态'
  },
  {
    module: 'Banner',
    scope: 'Banner CRUD、拖拽排序',
    endpoint: '/manager/workplace/banner, /manager/workplace/banner/reorder',
    status: '已接入',
    next: '补可见范围字段前先保持现有排序能力'
  },
  {
    module: '模块启用',
    scope: '用户侧启用模块、全局开关',
    endpoint: '待定义',
    status: '待设计',
    next: '后端补 module_visibility 或 app_config 契约'
  },
  {
    module: '可见范围',
    scope: '全部、平台、用户、角色、VIP 等级',
    endpoint: '待定义',
    status: '待设计',
    next: '后端鉴权和审计后再开放管理按钮'
  }
];
</script>

<style lang="scss" scoped>
.bd-title {
  border-bottom: 1px solid var(--el-card-border-color);
}

.summary-card,
.control-panel {
  padding: 14px;
  background: var(--el-bg-color);
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
}

.summary-card {
  min-height: 164px;
}

.summary-card__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-weight: 600;
}

.summary-card__value {
  margin-top: 16px;
  font-size: 20px;
  font-weight: 600;
}

.summary-card__meta {
  min-height: 40px;
  margin-top: 8px;
  color: var(--el-text-color-secondary);
  line-height: 20px;
}

.control-panel__title {
  margin-bottom: 12px;
  font-weight: 600;
}
</style>
