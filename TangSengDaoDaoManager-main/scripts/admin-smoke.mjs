import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = process.cwd();
const failures = [];

function read(path) {
  return readFileSync(join(root, path), 'utf8');
}

function assert(condition, message) {
  if (!condition) {
    failures.push(message);
  }
}

function walkFiles(dir) {
  const base = join(root, dir);
  const files = [];
  for (const entry of readdirSync(base)) {
    const full = join(base, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      files.push(...walkFiles(relative(root, full)));
    } else {
      files.push(relative(root, full));
    }
  }
  return files;
}

const viteConfig = read('vite.config.ts');
assert(
  viteConfig.includes("base: getAdminBasePath()") || viteConfig.includes('base: getAdminBasePath()'),
  'vite.config.ts must set base to getAdminBasePath()'
);

const routerConfig = read('src/router/index.ts');
assert(
  routerConfig.includes('createWebHistory(import.meta.env.BASE_URL)'),
  'router must use createWebHistory(import.meta.env.BASE_URL)'
);

const configIndex = read('src/config/index.ts');
assert(configIndex.includes('APP_BASE_PATH'), 'src/config/index.ts must export APP_BASE_PATH');
assert(configIndex.includes('normalizeApiBaseUrl'), 'src/config/index.ts must normalize APP_URL');

const nginxTemplate = read('nginx.conf.template');
assert(nginxTemplate.includes('location /admin/'), 'nginx.conf.template must serve /admin/');
assert(nginxTemplate.includes('try_files $uri $uri/ /admin/index.html'), 'nginx template must support /admin/ deep-link refresh');

const defaultConf = read('default.conf');
assert(defaultConf.includes('location /admin/'), 'default.conf must serve /admin/');
assert(defaultConf.includes('try_files $uri $uri/ /admin/index.html'), 'default.conf must support /admin/ deep-link refresh');

const dockerfile = read('Dockerfile');
assert(
  dockerfile.includes('/usr/share/nginx/html/admin'),
  'Dockerfile must copy dist into /usr/share/nginx/html/admin for /admin/ deployment'
);

const apiFiles = walkFiles('src/api').filter(file => /\.(ts|tsx)$/.test(file));
for (const file of apiFiles) {
  const source = read(file);
  const badLiteral = source.match(/url:\s*['"`](manager|common|statistics|file)\//);
  if (badLiteral) {
    failures.push(`${file} has API url without leading slash: ${badLiteral[0]}`);
  }
}

const menuIndex = read('src/menu/index.ts');
const expectedMenuSnippets = [
  "menuItem('/operation', 'operation', '运营'",
  "menuItem('/users', 'users', '用户'",
  "menuItem('/groups', 'groups', '群组'",
  "menuItem('/content-safety', 'contentSafety', '内容安全'",
  "menuItem('/system', 'system', '系统配置'",
  "menuItem('/monitoring', 'monitoring', '监控运维'",
  "menuItem('/home'",
  "menuItem('/user/userlist'",
  "menuItem('/group/grouplist'",
  "menuItem('/message/prohibitwords'",
  "menuItem('/report/user'",
  "menuItem('/setting/currencysetting'",
  "menuItem('/monitoring/health'"
];

for (const snippet of expectedMenuSnippets) {
  assert(menuIndex.includes(snippet), `src/menu/index.ts must include menu snippet: ${snippet}`);
}

const layoutColumns = read('src/layouts/components/LayoutColumns.vue');
assert(
  layoutColumns.includes('findTopMenuByPath'),
  'LayoutColumns.vue must resolve the active top menu recursively after menu regrouping'
);

const homeDashboard = read('src/pages/home/index.vue');
const expectedDashboardSnippets = [
  'operation-dashboard',
  'dashboardOverviewGet',
  '今日注册',
  '今日建群',
  '在线用户',
  '今日活跃',
  '消息量',
  '连接成功率',
  '暂无样本',
  '近 7 天',
  'reportListGet',
  'startupNoticeListGet',
  'commonAppversionListGet'
];

for (const snippet of expectedDashboardSnippets) {
  assert(homeDashboard.includes(snippet), `src/pages/home/index.vue must include dashboard snippet: ${snippet}`);
}
assert(!homeDashboard.includes('待设计'), 'src/pages/home/index.vue must not keep dashboard placeholder: 待设计');
assert(!homeDashboard.includes('待接入'), 'src/pages/home/index.vue must not keep dashboard placeholder: 待接入');

const tableToolbar = read('src/components/BdTableToolbar/index.vue');
const userListPage = read('src/pages/user/userlist.vue');
const prohibitWordsPage = read('src/pages/message/prohibitwords.vue');
const messageApi = read('src/api/message.ts');
const reportApi = read('src/api/report.ts');
const reportUserPage = read('src/pages/report/user.vue');
const reportGroupPage = read('src/pages/report/group.vue');
const reportModerationComponent = read('src/pages/report/components/ReportModeration.vue');
const messageRecordPage = read('src/pages/message/record.vue');
const messageRecordPersonalPage = read('src/pages/message/recordpersonal.vue');
const messageAuditComponent = read('src/pages/message/components/MessageAuditTable.vue');
const highRiskActionUtil = read('src/utils/highRiskAction.ts');
const vipApi = read('src/api/vip.ts');
const customerServiceApi = read('src/api/customerService.ts');
const vipPage = read('src/pages/vip/index.vue');
const customerServicePage = read('src/pages/customer-service/index.vue');
const launchPolicyPage = read('src/pages/launch-policy/index.vue');
const appUpdatePage = read('src/pages/tool/appupdate.vue');
const workplacePage = read('src/pages/workplace/index.vue');
const auditApi = read('src/api/audit.ts');
const auditPage = read('src/pages/audit/logs.vue');
const packageJson = JSON.parse(read('package.json'));
const userPurgeApiPath = 'src/api/userPurge.ts';
const userPurgePagePath = 'src/pages/user/purge.vue';
const expectedTableSnippets = [
  'BdTableToolbar',
  'visibleColumnKeys',
  'displayColumns',
  'type="selection"',
  '@selection-change',
  '<template #empty>'
];

for (const snippet of expectedTableSnippets) {
  assert(userListPage.includes(snippet), `src/pages/user/userlist.vue must include table standard snippet: ${snippet}`);
  assert(
    prohibitWordsPage.includes(snippet),
    `src/pages/message/prohibitwords.vue must include table standard snippet: ${snippet}`
  );
}

const expectedProhibitWordPolicyApiSnippets = [
  'AdminForbiddenWordPolicyQuery',
  'AdminForbiddenWordHitLogRecord',
  'messageForbiddenWordPoliciesGet',
  'messageForbiddenWordPolicyPublishPost',
  'messageForbiddenWordPolicyRollbackPost',
  'messageForbiddenWordHitLogsGet',
  '/manager/message/prohibit_word_policies',
  '/manager/message/prohibit_word_hit_logs'
];

for (const snippet of expectedProhibitWordPolicyApiSnippets) {
  assert(messageApi.includes(snippet), `src/api/message.ts must include forbidden-word policy snippet: ${snippet}`);
}

const expectedProhibitWordPolicyPageSnippets = [
  'content-safety-policy',
  'policyVersion',
  'hitLogDialogVisible',
  'messageForbiddenWordPoliciesGet',
  'messageForbiddenWordPolicyPublishPost',
  'messageForbiddenWordPolicyRollbackPost',
  'messageForbiddenWordHitLogsGet',
  'forbidden-word-hit-log',
  '暂未开放'
];

for (const snippet of expectedProhibitWordPolicyPageSnippets) {
  assert(
    prohibitWordsPage.includes(snippet),
    `src/pages/message/prohibitwords.vue must include forbidden-word policy snippet: ${snippet}`
  );
}

for (const snippet of ['列配置', '导出', '批量操作', '暂未开放']) {
  assert(tableToolbar.includes(snippet), `BdTableToolbar must include table toolbar snippet: ${snippet}`);
}

const expectedReportModerationApiSnippets = [
  'AdminReportQuery',
  'AdminReportRecord',
  'AdminReportHandlePayload',
  'reportHandlePost',
  '/manager/report/handle'
];

for (const snippet of expectedReportModerationApiSnippets) {
  assert(reportApi.includes(snippet), `src/api/report.ts must include report moderation snippet: ${snippet}`);
}

const expectedReportModerationPageSnippets = [
  'report-moderation',
  'handleDialogVisible',
  'reportHandlePost',
  'pending',
  'processed',
  'rejected',
  'banned',
  'handler_name',
  'handle_remark'
];

for (const snippet of expectedReportModerationPageSnippets) {
  assert(
    reportModerationComponent.includes(snippet),
    `src/pages/report/components/ReportModeration.vue must include report moderation snippet: ${snippet}`
  );
}

assert(reportUserPage.includes('ReportModeration'), 'src/pages/report/user.vue must use ReportModeration');
assert(reportGroupPage.includes('ReportModeration'), 'src/pages/report/group.vue must use ReportModeration');

const expectedMessageAuditApiSnippets = [
  'AdminMessageAuditQuery',
  'AdminMessageAuditRecord',
  'sender_uid',
  'target_id',
  'message_type',
  'device_id',
  'start_at',
  'end_at'
];

for (const snippet of expectedMessageAuditApiSnippets) {
  assert(messageApi.includes(snippet), `src/api/message.ts must include message audit snippet: ${snippet}`);
}

const expectedMessageAuditPageSnippets = [
  'message-audit-table',
  'auditTimeRange',
  'message_type',
  'device_id',
  'sender_uid',
  'target_id',
  'start_at',
  'end_at',
  '接口未接入'
];

for (const snippet of expectedMessageAuditPageSnippets) {
  assert(
    messageAuditComponent.includes(snippet),
    `src/pages/message/components/MessageAuditTable.vue must include message audit snippet: ${snippet}`
  );
}

assert(messageRecordPage.includes('MessageAuditTable'), 'src/pages/message/record.vue must use MessageAuditTable');
assert(
  messageRecordPersonalPage.includes('MessageAuditTable'),
  'src/pages/message/recordpersonal.vue must use MessageAuditTable'
);

const expectedHighRiskActionSnippets = [
  'confirmHighRiskAction',
  'HighRiskActionPayload',
  'reason',
  'password',
  'token',
  'secret'
];

for (const snippet of expectedHighRiskActionSnippets) {
  assert(highRiskActionUtil.includes(snippet), `src/utils/highRiskAction.ts must include high-risk snippet: ${snippet}`);
}

const expectedHighRiskApiSnippets = ['reason'];
for (const snippet of expectedHighRiskApiSnippets) {
  assert(messageApi.includes(snippet), `src/api/message.ts must include high-risk audit snippet: ${snippet}`);
  assert(vipApi.includes(snippet), `src/api/vip.ts must include high-risk audit snippet: ${snippet}`);
  assert(customerServiceApi.includes(snippet), `src/api/customerService.ts must include high-risk audit snippet: ${snippet}`);
}

const expectedHighRiskPageSnippets = ['confirmHighRiskAction', 'reason'];
for (const snippet of expectedHighRiskPageSnippets) {
  assert(
    messageAuditComponent.includes(snippet),
    `src/pages/message/components/MessageAuditTable.vue must include high-risk snippet: ${snippet}`
  );
  assert(vipPage.includes(snippet), `src/pages/vip/index.vue must include high-risk snippet: ${snippet}`);
  assert(
    customerServicePage.includes(snippet),
    `src/pages/customer-service/index.vue must include high-risk snippet: ${snippet}`
  );
}

const expectedLaunchPolicySnippets = [
  'launch-policy-control',
  '/app/launch-policy',
  'maintenance-mode',
  'getAppconfigGet',
  'maintenanceEnabled',
  '配置维护模式',
  '/tool/appupdate',
  '/launch-policy/notices'
];

for (const snippet of expectedLaunchPolicySnippets) {
  assert(
    launchPolicyPage.includes(snippet),
    `src/pages/launch-policy/index.vue must include launch policy snippet: ${snippet}`
  );
}

assert(
  menuIndex.includes("menuItem('/launch-policy'"),
  'src/menu/index.ts must expose the launch policy control center route'
);

const expectedAppVersionSnippets = [
  'app-version-policy',
  'APP 版本策略',
  '强制更新',
  '可选更新',
  '最低 Build',
  '/app/launch-policy',
  '导出暂未开放'
];

for (const snippet of expectedAppVersionSnippets) {
  assert(appUpdatePage.includes(snippet), `src/pages/tool/appupdate.vue must include app version snippet: ${snippet}`);
}

const expectedWorkplaceSnippets = [
  'workplace-control',
  '工作台总览',
  '第三阶段 3.2 能力矩阵',
  '/manager/workplace/app',
  '/manager/workplace/banner',
  '可见范围',
  '待设计'
];

for (const snippet of expectedWorkplaceSnippets) {
  assert(workplacePage.includes(snippet), `src/pages/workplace/index.vue must include workplace snippet: ${snippet}`);
}

assert(menuIndex.includes("menuItem('/workplace'"), 'src/menu/index.ts must expose workplace overview route');

const expectedAuditSnippets = [
  '/manager/audit/logs',
  'AdminAuditLogQuery',
  'AdminAuditLogRecord'
];

for (const snippet of expectedAuditSnippets) {
  assert(auditApi.includes(snippet), `src/api/audit.ts must include audit API snippet: ${snippet}`);
}

const expectedAuditPageSnippets = [
  'admin-audit-log',
  '操作审计',
  '高危操作',
  'reason',
  '暂未开放',
  'password',
  'token',
  'secret'
];

for (const snippet of expectedAuditPageSnippets) {
  assert(auditPage.includes(snippet), `src/pages/audit/logs.vue must include audit page snippet: ${snippet}`);
}

assert(menuIndex.includes("menuItem('/audit/logs'"), 'src/menu/index.ts must expose audit logs route');

assert(existsSync(join(root, userPurgeApiPath)), 'src/api/userPurge.ts must exist for user physical purge contract');
assert(existsSync(join(root, userPurgePagePath)), 'src/pages/user/purge.vue must exist for user physical purge operations');

if (existsSync(join(root, userPurgeApiPath))) {
  const userPurgeApi = read(userPurgeApiPath);
  const expectedUserPurgeApiSnippets = [
    'AdminUserPurgePreview',
    'AdminUserPurgeRequest',
    'AdminUserPurgeJob',
    'userPurgePreviewGet',
    'userPurgeDelete',
    'userPurgeJobGet',
    '/manager/users/',
    '/purge-preview',
    '/purge-jobs/'
  ];

  for (const snippet of expectedUserPurgeApiSnippets) {
    assert(userPurgeApi.includes(snippet), `${userPurgeApiPath} must include user purge API snippet: ${snippet}`);
  }
}

if (existsSync(join(root, userPurgePagePath))) {
  const userPurgePage = read(userPurgePagePath);
  const expectedUserPurgePageSnippets = [
    'user-purge-control',
    'purgePreview',
    'userPurgePreviewGet',
    'userPurgeDelete',
    'userPurgeJobGet',
    'confirmHighRiskAction',
    'reason',
    '接口未接入'
  ];

  for (const snippet of expectedUserPurgePageSnippets) {
    assert(userPurgePage.includes(snippet), `${userPurgePagePath} must include user purge page snippet: ${snippet}`);
  }
}

assert(menuIndex.includes("menuItem('/user/purge'"), 'src/menu/index.ts must expose user physical purge route');

const backendProbePath = 'scripts/admin-backend-probe.mjs';
const backendProbeTestPath = 'scripts/admin-backend-probe.test.mjs';
assert(existsSync(join(root, backendProbePath)), 'scripts/admin-backend-probe.mjs must exist for Phase 5 backend contract probing');
assert(
  existsSync(join(root, backendProbeTestPath)),
  'scripts/admin-backend-probe.test.mjs must cover backend probe contract helpers'
);
assert(
  packageJson.scripts?.['probe:admin-backend'] === 'node scripts/admin-backend-probe.mjs',
  'package.json must expose probe:admin-backend'
);
assert(
  packageJson.scripts?.['test:probe'] === 'node --test scripts/admin-backend-probe.test.mjs',
  'package.json must expose test:probe'
);

if (existsSync(join(root, backendProbePath))) {
  const backendProbe = read(backendProbePath);
  const expectedBackendProbeSnippets = [
    'ADMIN_API_BASE_URL',
    'ADMIN_TOKEN',
    'ADMIN_PROBE_MUTATIONS',
    'auth-required',
    'reason-required',
    'paged-list',
    'purge-preview',
    'purge-job',
    'response contract failed',
    '/manager/audit/logs',
    '/manager/message/prohibit_word_policies',
    '/manager/message/prohibit_word_hit_logs',
    '/manager/report/handle',
    '/manager/message/record',
    '/manager/message/recordpersonal',
    '/manager/message',
    '/manager/user/set_vip',
    '/manager/user/set_customer_service',
    '/manager/users/',
    '/purge-preview',
    '/purge-jobs/',
    '/purge',
    'GET',
    'OPTIONS'
  ];

  for (const snippet of expectedBackendProbeSnippets) {
    assert(backendProbe.includes(snippet), `${backendProbePath} must include backend probe snippet: ${snippet}`);
  }
}

const distIndex = read('dist/index.html');
assert(distIndex.includes('/admin/static/'), 'dist/index.html must reference assets under /admin/static/');
assert(!distIndex.includes('href="/static/'), 'dist/index.html must not reference root /static assets');
assert(!distIndex.includes('src="/static/'), 'dist/index.html must not reference root /static assets');

if (failures.length) {
  console.error('Admin smoke checks failed:');
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log('Admin smoke checks passed.');
