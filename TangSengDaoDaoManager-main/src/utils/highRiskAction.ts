import { ElMessageBox } from 'element-plus';

export interface HighRiskActionPayload {
  reason: string;
}

const SENSITIVE_FIELD_PATTERN = /(password|token|secret)/i;

export const assertAuditSnapshotIsSafe = (value: Record<string, unknown>) => {
  const keys = Object.keys(value);
  const unsafeKey = keys.find(key => SENSITIVE_FIELD_PATTERN.test(key));
  if (unsafeKey) {
    throw new Error(`Audit snapshot contains sensitive field: ${unsafeKey}`);
  }
};

export const confirmHighRiskAction = (title: string, message: string): Promise<HighRiskActionPayload> => {
  return ElMessageBox.prompt(`${message}\n\n请填写操作原因，后端审计必须保存 reason。`, title, {
    confirmButtonText: '确认',
    cancelButtonText: '取消',
    inputType: 'textarea',
    inputPlaceholder: '请输入操作原因',
    inputValidator: value => Boolean(value?.trim()),
    inputErrorMessage: '高危操作必须填写原因'
  }).then(({ value }) => ({
    reason: value.trim()
  }));
};
