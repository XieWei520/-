import type { ChatMessage, Contact, Conversation, CurrentUser, Group, MessageKind } from '../models/im';

const baseTimestamp = Date.UTC(2026, 4, 29, 8, 0, 0);

export const fakeCurrentUser: CurrentUser = {
  id: 'u-current',
  name: '吴小空',
  phone: '13800138000',
  avatarText: '吴',
  connectionState: 'connected',
};

export const fakeConversations: Conversation[] = [
  {
    id: 'conv-delivery',
    channelId: 'g-delivery',
    channelType: 2,
    title: '产品交付群',
    avatarText: '交',
    lastMessage: '今天的验收清单已同步，请大家确认。',
    lastMessageAt: '09:48',
    unreadCount: 3,
    muted: false,
  },
  {
    id: 'conv-customer-a',
    channelId: 'u-customer-a',
    channelType: 1,
    title: '客户 A',
    avatarText: 'A',
    lastMessage: '合同附件我已经收到了。',
    lastMessageAt: '昨天',
    unreadCount: 0,
    muted: false,
  },
  {
    id: 'conv-ops',
    channelId: 'g-ops',
    channelType: 2,
    title: '运维通知',
    avatarText: '运',
    lastMessage: '今晚 22:00 进行例行巡检。',
    lastMessageAt: '周三',
    unreadCount: 1,
    muted: true,
  },
];

export const fakeContacts: Contact[] = [
  {
    id: 'u-customer-a',
    name: '客户 A',
    phone: '13900139001',
    avatarText: 'A',
    title: '采购负责人',
    online: true,
  },
  {
    id: 'u-li',
    name: '李明',
    phone: '13700137002',
    avatarText: '李',
    title: '产品经理',
    online: true,
  },
  {
    id: 'u-chen',
    name: '陈晨',
    phone: '13600136003',
    avatarText: '陈',
    title: '运维工程师',
    online: false,
  },
];

export const fakeGroups: Group[] = [
  {
    id: 'g-delivery',
    name: '产品交付群',
    avatarText: '交',
    memberCount: 12,
    description: '项目交付、验收和变更沟通',
  },
  {
    id: 'g-ops',
    name: '运维通知',
    avatarText: '运',
    memberCount: 8,
    description: '系统巡检、发布和告警同步',
  },
];

const textSamples = [
  '收到，我会在今天下午更新进度。',
  '请确认最新版本的交付范围。',
  '会议纪要已经放到共享目录。',
  '这个问题需要后端同学一起看一下。',
  '我先拉一版测试数据给大家验证。',
];

const kindSamples: MessageKind[] = ['text', 'image', 'file', 'voice'];

function contentFor(kind: MessageKind, index: number): string {
  if (kind === 'image') {
    return `现场截图 ${String(index + 1).padStart(2, '0')}`;
  }

  if (kind === 'file') {
    return `交付文档-${String(index + 1).padStart(2, '0')}.pdf`;
  }

  if (kind === 'voice') {
    return `${8 + (index % 24)} 秒语音`;
  }

  return textSamples[index % textSamples.length];
}

export function buildFakeMessages(channelId: string): ChatMessage[] {
  const conversation = fakeConversations.find((item) => item.channelId === channelId);
  const channelType = conversation?.channelType ?? 1;

  return Array.from({ length: 80 }, (_, index) => {
    const direction = index % 3 === 0 ? 'outgoing' : 'incoming';
    const kind = kindSamples[index % kindSamples.length];
    const sentAt = new Date(baseTimestamp + index * 90_000).toISOString();

    return {
      id: `${channelId}-${index + 1}`,
      channelId,
      channelType,
      senderId: direction === 'outgoing' ? fakeCurrentUser.id : `u-fake-${index % 5}`,
      senderName: direction === 'outgoing' ? fakeCurrentUser.name : ['李明', '客户 A', '陈晨'][index % 3],
      direction,
      kind,
      content: contentFor(kind, index),
      sentAt,
      status: index % 29 === 0 ? 'failed' : 'sent',
    };
  });
}
