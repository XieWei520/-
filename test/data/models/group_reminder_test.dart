import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group_reminder.dart';

void main() {
  test('GroupReminder parses response payload', () {
    final reminder = GroupReminder.fromJson({
      'id': 12,
      'group_no': 'g1',
      'title': '周会提醒',
      'content': '请提交进度',
      'creator_uid': 'u1',
      'creator_name': 'Alice',
      'remind_at': 1710000000,
      'triggered_at': 1710000300,
      'completed_at': 0,
      'status': 0,
      'triggered': true,
      'all_done': false,
      'done': true,
      'overdue': true,
      'total_count': 2,
      'done_count': 1,
      'assignees': [
        {'uid': 'u1', 'name': 'Alice', 'done': true},
        {'uid': 'u2', 'name': 'Bob', 'done': false},
      ],
    });

    expect(reminder.id, 12);
    expect(reminder.groupNo, 'g1');
    expect(reminder.triggered, isTrue);
    expect(reminder.done, isTrue);
    expect(reminder.assignees.length, 2);
    expect(reminder.assignees.first.done, isTrue);
  });

  test('GroupReminderPayload parses reminder data', () {
    final payload = GroupReminderPayload.fromReminderData({
      'kind': 'group_reminder',
      'group_reminder_id': 18,
      'group_no': 'g2',
      'title': '发版检查',
      'content': '确认日志和监控',
      'creator_uid': 'u9',
      'creator_name': 'Chris',
      'remind_at': 1710001000,
      'assignee_uids': ['u9', 'u8'],
    });

    expect(payload, isNotNull);
    expect(payload!.reminderId, 18);
    expect(payload.groupNo, 'g2');
    expect(payload.assigneeUids, ['u9', 'u8']);
  });

  test('GroupReminder exposes editable state for scheduled reminders', () {
    final reminder = GroupReminder.fromJson({
      'id': 9,
      'group_no': 'g2',
      'title': '发版检查',
      'content': '',
      'creator_uid': 'u9',
      'creator_name': 'Chris',
      'remind_at': 1710001000,
      'triggered_at': 0,
      'completed_at': 0,
      'status': 0,
      'triggered': false,
      'all_done': false,
      'done': false,
      'overdue': false,
      'total_count': 2,
      'done_count': 0,
      'assignees': [
        {'uid': 'u9', 'name': 'Chris', 'done': false},
        {'uid': 'u8', 'name': 'Daisy', 'done': false},
      ],
    });

    expect(reminder.isEditable, isTrue);
    expect(reminder.canManage('u9'), isTrue);
    expect(reminder.canManage('u8'), isFalse);
    expect(reminder.assigneeUids, {'u9', 'u8'});
  });

  test('GroupReminder is not editable after trigger or completion', () {
    final triggeredReminder = GroupReminder.fromJson({
      'id': 11,
      'group_no': 'g3',
      'title': '上线巡检',
      'content': '',
      'creator_uid': 'u1',
      'creator_name': 'Alice',
      'remind_at': 1710002000,
      'triggered_at': 1710002600,
      'completed_at': 0,
      'status': 0,
      'triggered': true,
      'all_done': false,
      'done': false,
      'overdue': true,
      'total_count': 1,
      'done_count': 0,
      'assignees': [
        {'uid': 'u1', 'name': 'Alice', 'done': false},
      ],
    });
    final completedReminder = GroupReminder.fromJson({
      'id': 12,
      'group_no': 'g3',
      'title': '复盘会议',
      'content': '',
      'creator_uid': 'u1',
      'creator_name': 'Alice',
      'remind_at': 1710002000,
      'triggered_at': 1710002600,
      'completed_at': 1710002800,
      'status': 1,
      'triggered': true,
      'all_done': true,
      'done': true,
      'overdue': false,
      'total_count': 1,
      'done_count': 1,
      'assignees': [
        {'uid': 'u1', 'name': 'Alice', 'done': true},
      ],
    });

    expect(triggeredReminder.isEditable, isFalse);
    expect(triggeredReminder.canManage('u1'), isFalse);
    expect(completedReminder.isEditable, isFalse);
    expect(completedReminder.canManage('u1'), isFalse);
  });
}
