# 新功能快速上手指南

## 🚀 5 分钟了解所有新增功能

---

## 一、机器人系统 (Robot System)

### 最简单的使用方式

```dart
import 'package:wukong_im_app/wukong_robot/robot_exports.dart';

// 1. 同步机器人（应用启动时调用）
await RobotService.instance.syncRobots();

// 2. 搜索 GIF 表情
final gifs = await RobotService.instance.searchGifs(query: '开心');
// 返回结果可直接用于表情选择器

// 3. 执行机器人命令
final result = await RobotService.instance.executeCommand(
  robotId: 'weather',
  command: 'query',
  args: ['北京'],
);
```

### 在聊天中使用

```dart
// 在输入框中@机器人
TextField(
  decoration: InputDecoration(
    hintText: '@机器人 搜索...',
    suffixIcon: IconButton(
      icon: Icon(Icons.auto_awesome),
      onPressed: () async {
        final results = await RobotService.instance.query(
          robotId: 'giphy',
          query: 'funny cats',
        );
        // 显示结果
      },
    ),
  ),
)
```

---

## 二、设备管理 (Device Management)

### 添加到设置页面

```dart
import 'package:wukong_im_app/modules/settings/device_management_page.dart';

// 在设置页面添加入口
ListTile(
  leading: Icon(Icons.devices),
  title: Text('设备管理'),
  subtitle: Text('管理登录设备'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeviceManagementPage()),
    );
  },
)
```

### 编程方式使用

```dart
import 'package:wukong_im_app/service/api/device_api.dart';

// 获取所有设备
final devices = await DeviceApi.instance.getAllDevices();

// 锁定可疑设备
await DeviceApi.instance.lockDevice(suspiciousDeviceId, true);

// 一键下线所有其他设备
await DeviceApi.instance.logoutAllExceptCurrent();
```

---

## 三、搜索增强 (Enhanced Search)

### 按日期搜索

```dart
import 'package:wukong_im_app/modules/search/search_with_date_page.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SearchWithDatePage(
      channelId: 'group_123',
      channelType: 2, // 群组
    ),
  ),
);
```

### 查看聊天记录中的图片

```dart
import 'package:wukong_im_app/modules/search/search_with_img_page.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SearchWithImgPage(
      channelId: 'user_456',
    ),
  ),
);
```

### 在代码中搜索

```dart
import 'package:wukong_im_app/service/api/search_api.dart';

// 按日期范围搜索
final messages = await SearchApi.instance.searchMessagesByDate(
  channelId: 'group_123',
  channelType: 2,
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
);

// 搜索图片
final images = await SearchApi.instance.searchImages(
  channelId: 'group_123',
  limit: 50,
);

// 按成员搜索
final memberMessages = await SearchApi.instance.searchMessagesByMember(
  channelId: 'group_123',
  senderId: 'user_789',
);
```

---

## 四、聊天 UI 组件

### 功能菜单 ("+"按钮)

```dart
import 'package:wukong_im_app/wukong_uikit/chat/input_function_menu.dart';

// 简单版本 - 单个面板
InputFunctionMenu(
  onItemSelected: (item) {
    switch (item.id) {
      case 'photo_video':
        _pickImage();
        break;
      case 'camera':
        _openCamera();
        break;
      case 'location':
        _shareLocation();
        break;
      // ... 处理其他功能
    }
  },
)

// 带分页的版本
FunctionMenuPanel(
  onItemSelected: (item) {
    // 处理选择
  },
)
```

### 消息长按菜单

```dart
import 'package:wukong_im_app/wukong_uikit/chat/message_long_press_menu.dart';

// 在消息气泡上添加长按手势
GestureDetector(
  onLongPress: () async {
    final action = await showMessageLongPressMenu(
      context: context,
      position: tapPosition, // Offset(x, y)
      messageType: message.type, // 'text', 'image', etc.
      isFromMe: message.fromUid == currentUserId,
      canRecall: message.canRecall, // 是否在撤回时间内
    );
    
    if (action != null) {
      _handleMessageAction(action, message);
    }
  },
  child: MessageBubble(message: message),
)

// 处理动作
void _handleMessageAction(MessageMenuAction action, Message message) {
  switch (action) {
    case MessageMenuAction.copy:
      Clipboard.setData(ClipboardData(text: message.content));
      break;
    case MessageMenuAction.forward:
      _forwardMessage(message);
      break;
    case MessageMenuAction.reply:
      _replyToMessage(message);
      break;
    case MessageMenuAction.recall:
      _recallMessage(message);
      break;
    case MessageMenuAction.delete:
      _deleteMessage(message);
      break;
    // ...
  }
}
```

---

## 五、自定义 View

### 语音波形动画

```dart
import 'package:wukong_im_app/wukong_uikit/views/line_wave_voice_view.dart';

// 播放语音时显示波形
Row(
  children: [
    IconButton(
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      onPressed: () {
        setState(() => isPlaying = !isPlaying);
      },
    ),
    LineWaveVoiceView(
      lineCount: 25,
      lineWidth: 3,
      minHeight: 4,
      maxHeight: 30,
      color: Theme.of(context).primaryColor,
      isPlaying: isPlaying,
    ),
    SizedBox(width: 8),
    Text(formatDuration(duration)),
  ],
)
```

### 录音界面

```dart
import 'package:wukong_im_app/wukong_uikit/views/record_audio_view.dart';

// 全屏录音界面
showModalBottomSheet(
  context: context,
  isFullScreen: true,
  backgroundColor: Colors.transparent,
  builder: (context) => RecordAudioView(
    onRecordStart: () {
      print('开始录音');
    },
    onRecordComplete: (duration) {
      print('录音完成：$duration');
      // 发送录音消息
    },
    onRecordCancel: () {
      print('取消录音');
    },
    maxDurationSeconds: 60,
    minDurationSeconds: 1,
  ),
);
```

---

## 六、加密模块 (高级用法)

> **2026-04-16 审计更正**
> 本节旧示例仅代表早期占位脚手架，并非可直接落地的生产接入方式。可审计
> 开源服务端与 `/opt/wukongim-prod/src` 都未注册
> `/v1/user/signal/getkey`、`/v1/user/signal/uploadkeys`、
> `/v1/message/encrypt/send`、`/v1/message/encrypt/ack`，且 Flutter 当前
> 聊天收发运行时没有活跃路径在调用这些接口。

### 端到端加密消息

```dart
import 'package:wukong_im_app/wukong_crypto/crypto_exports.dart';

// 1. 获取对方密钥
final signalData = await CryptoApi.instance.getUserSignalKey();

// 2. 使用 Signal 协议建立会话（需要额外集成加密库）
// ... session establishment code ...

// 3. 发送加密消息
await CryptoApi.instance.sendEncryptedMessage(
  targetUid: 'user_123',
  encryptedPayload: encryptedContent,
  messageType: 'text',
);

// 4. 确认收到消息
await CryptoApi.instance.acknowledgeEncryptedMessage(
  messageId: msgId,
  senderUid: senderId,
);
```

---

## 七、API 快速参考

### GroupApi 新方法

```dart
import 'package:wukong_im_app/service/api/group_api.dart';

// 邀请成员
await GroupApi.instance.inviteMembers(groupNo, ['user1', 'user2']);

// 申请加群
await GroupApi.instance.joinGroup(groupNo, reason: '朋友邀请');

// 设置管理员
await GroupApi.instance.setGroupAdmin(groupNo, userId, true);

// 全员禁言
await GroupApi.instance.setGroupMute(groupNo, true);

// 转让群主
await GroupApi.instance.transferGroupOwner(groupNo, newOwnerId);

// 解散群组
await GroupApi.instance.dismissGroup(groupNo);
```

### RobotApi 直接调用

```dart
import 'package:wukong_im_app/service/api/robot_api.dart';

// 同步机器人
final robots = await RobotApi.instance.syncRobots(['giphy', 'weather']);

// 内联查询
final result = await RobotApi.instance.inlineQuery(
  robotId: 'giphy',
  query: 'celebration',
  channelId: 'group_123',
);

// 获取机器人详情
final robot = await RobotApi.instance.getRobotDetail('giphy');

// 添加/移除机器人
await RobotApi.instance.addRobot('giphy');
await RobotApi.instance.removeRobot('giphy');
```

---

## 八、完整示例：聊天页面集成

```dart
import 'package:flutter/material.dart';
import 'package:wukong_im_app/wukong_robot/robot_exports.dart';
import 'package:wukong_im_app/wukong_uikit/chat/input_function_menu.dart';
import 'package:wukong_im_app/wukong_uikit/chat/message_long_press_menu.dart';

class ChatPage extends StatefulWidget {
  final String channelId;
  
  const ChatPage({super.key, required this.channelId});
  
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _showFunctionMenu = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('聊天')),
      body: Column(
        children: [
          // 消息列表
          Expanded(child: MessageListView()),
          
          // 功能菜单
          if (_showFunctionMenu)
            FunctionMenuPanel(
              onItemSelected: (item) {
                setState(() => _showFunctionMenu = false);
                _handleFunctionItem(item);
              },
            ),
          
          // 输入区域
          _buildInputArea(),
        ],
      ),
    );
  }
  
  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          // "+"按钮
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            onPressed: () {
              setState(() => _showFunctionMenu = !_showFunctionMenu);
            },
          ),
          
          // 输入框
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: '发消息...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          
          // 表情按钮
          IconButton(
            icon: Icon(Icons.sentiment_satisfied),
            onPressed: () {
              // 打开表情选择器
            },
          ),
        ],
      ),
    );
  }
  
  void _handleFunctionItem(FunctionMenuItem item) {
    switch (item.id) {
      case 'photo_video':
        _pickFromGallery();
        break;
      case 'camera':
        _openCamera();
        break;
      case 'gif':
        _searchGif();
        break;
      // ...
    }
  }
  
  Future<void> _searchGif() async {
    final gifs = await RobotService.instance.searchGifs(query: 'hello');
    // 显示 GIF 选择器
  }
}
```

---

## 九、常见问题

### Q: 如何配置自己的机器人？
A: 需要在服务器端配置机器人服务，然后在客户端调用 `RobotApi.instance.syncRobots()` 同步。

### Q: 设备管理为什么看不到某些设备？
A: 确保用户已登录，并且后端 API 正常返回设备列表。

### Q: 搜索结果为空怎么办？
A: 检查 `channelId`是否正确，以及该频道下是否有对应类型的消息。

### Q: 长按菜单不显示？
A: 确保传入了正确的 `position`参数（相对于屏幕的坐标）。

---

## 十、下一步

建议按以下顺序继续完善：

1. **集成到现有页面** - 将新组件添加到实际使用的页面中
2. **单元测试** - 为新功能编写测试
3. **UI 打磨** - 根据实际使用反馈调整样式
4. **性能优化** - 特别是图片和 GIF 的缓存

---

祝您使用愉快！🎉
