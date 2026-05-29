export type ChannelType = 1 | 2;
export type ConnectionState = 'connected' | 'connecting' | 'offline';
export type MessageKind = 'text' | 'image' | 'file' | 'voice';
export type MessageDirection = 'incoming' | 'outgoing';
export type SendStatus = 'sent' | 'sending' | 'failed';

export interface CurrentUser {
  id: string;
  name: string;
  phone: string;
  avatarText: string;
  connectionState: ConnectionState;
}

export interface Conversation {
  id: string;
  channelId: string;
  channelType: ChannelType;
  title: string;
  avatarText: string;
  lastMessage: string;
  lastMessageAt: string;
  unreadCount: number;
  muted: boolean;
}

export interface Contact {
  id: string;
  name: string;
  phone: string;
  avatarText: string;
  title: string;
  online: boolean;
}

export interface Group {
  id: string;
  name: string;
  avatarText: string;
  memberCount: number;
  description: string;
}

export interface ChatMessage {
  id: string;
  clientMsgNo?: string;
  channelId: string;
  channelType: ChannelType;
  senderId: string;
  senderName: string;
  direction: MessageDirection;
  kind: MessageKind;
  content: string;
  sentAt: string;
  status: SendStatus;
}
