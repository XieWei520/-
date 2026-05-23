<template>
  <div class="bd-table-toolbar">
    <div class="toolbar-left">
      <el-tag v-if="selectedCount" type="primary" effect="plain">已选 {{ selectedCount }} 项</el-tag>
      <el-tag v-else type="info" effect="plain">支持筛选、分页、列配置、导出、批量操作</el-tag>
    </div>

    <div class="toolbar-right">
      <el-button @click="$emit('refresh')">
        <el-icon>
          <i-bd-refresh />
        </el-icon>
        刷新
      </el-button>

      <el-dropdown trigger="click" :hide-on-click="false">
        <el-button>
          <el-icon>
            <i-bd-setting-config />
          </el-icon>
          列配置
        </el-button>
        <template #dropdown>
          <el-dropdown-menu>
            <el-dropdown-item v-for="column in columns" :key="column.key">
              <el-checkbox
                :model-value="modelValue.includes(column.key)"
                :disabled="modelValue.length <= 1 && modelValue.includes(column.key)"
                @change="onColumnToggle(column.key, $event)"
              >
                {{ column.label }}
              </el-checkbox>
            </el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>

      <el-button @click="$emit('export')">
        <el-icon>
          <i-bd-download />
        </el-icon>
        导出
      </el-button>

      <el-button :disabled="!selectedCount" title="批量操作暂未开放" type="warning" @click="$emit('batch')">批量操作</el-button>
    </div>
  </div>
</template>

<script setup lang="ts" name="BdTableToolbar">
interface ToolbarColumn {
  key: string;
  label: string;
}

const props = defineProps<{
  columns: ToolbarColumn[];
  modelValue: string[];
  selectedCount: number;
}>();

const emit = defineEmits<{
  (event: 'update:modelValue', value: string[]): void;
  (event: 'refresh'): void;
  (event: 'export'): void;
  (event: 'batch'): void;
}>();

const onColumnToggle = (key: string, checked: string | number | boolean) => {
  const nextValue = checked ? [...props.modelValue, key] : props.modelValue.filter(item => item !== key);
  emit('update:modelValue', nextValue);
};
</script>

<style lang="scss" scoped>
.bd-table-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 12px;
  border-bottom: 1px solid var(--el-card-border-color);

  .toolbar-left,
  .toolbar-right {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .toolbar-right {
    flex-wrap: wrap;
    justify-content: flex-end;
  }
}
</style>
