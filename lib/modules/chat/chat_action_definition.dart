enum ChatActionId {
  chooseImage,
  captureImage,
  chooseFile,
  sendLocation,
  chooseCard,
  composeRichText,
  audioCall,
  videoCall,
  groupCall,
}

class ChatActionDefinition {
  const ChatActionDefinition({
    required this.id,
    required this.functionSid,
    required this.label,
  });

  final ChatActionId id;
  final String functionSid;
  final String label;
}

const ChatActionDefinition chatChooseImageAction = ChatActionDefinition(
  id: ChatActionId.chooseImage,
  functionSid: 'chooseImg',
  label: '\u56fe\u7247',
);

const ChatActionDefinition chatCaptureImageAction = ChatActionDefinition(
  id: ChatActionId.captureImage,
  functionSid: 'captureImg',
  label: '\u62cd\u7167',
);

const ChatActionDefinition chatChooseFileAction = ChatActionDefinition(
  id: ChatActionId.chooseFile,
  functionSid: 'chooseFile',
  label: '\u6587\u4ef6',
);

const ChatActionDefinition chatSendLocationAction = ChatActionDefinition(
  id: ChatActionId.sendLocation,
  functionSid: 'sendLocation',
  label: '\u4f4d\u7f6e',
);

const ChatActionDefinition chatChooseCardAction = ChatActionDefinition(
  id: ChatActionId.chooseCard,
  functionSid: 'chooseCard',
  label: '\u540d\u7247',
);

const ChatActionDefinition chatComposeRichTextAction = ChatActionDefinition(
  id: ChatActionId.composeRichText,
  functionSid: 'composeRichText',
  label: '\u5bcc\u6587\u672c',
);

const ChatActionDefinition chatAudioCallAction = ChatActionDefinition(
  id: ChatActionId.audioCall,
  functionSid: 'audioCall',
  label: '\u8bed\u97f3\u901a\u8bdd',
);

const ChatActionDefinition chatVideoCallAction = ChatActionDefinition(
  id: ChatActionId.videoCall,
  functionSid: 'videoCall',
  label: '\u89c6\u9891\u901a\u8bdd',
);

const ChatActionDefinition chatGroupCallAction = ChatActionDefinition(
  id: ChatActionId.groupCall,
  functionSid: 'groupCall',
  label: '\u591a\u4eba\u901a\u8bdd',
);
