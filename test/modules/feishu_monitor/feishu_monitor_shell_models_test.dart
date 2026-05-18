import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_models.dart';

void main() {
  test('parses worker and media queue diagnostics from status json', () {
    final status = FeishuMonitorShellStatus.fromJson(<String, dynamic>{
      'shell_state': 'online',
      'capture_state': 'running',
      'login_state': 'logged_in',
      'hook_state': 'healthy',
      'runtime_url': 'https://www.feishu.cn/messenger/',
      'page_title': 'Feishu',
      'page_kind': 'messenger',
      'webview_available': true,
      'shell_mode': 'desktop_shell',
      'queue_depth': 0,
      'messages_today': 0,
      'deliveries_succeeded_today': 0,
      'deliveries_failed_today': 0,
      'last_error': '',
      'worker_id': 'worker-2',
      'probe_diagnostics': <String, dynamic>{
        'media_queue_depth': 3,
        'media_queue_oldest_wait_seconds': 45,
        'media_queue_estimated_next_delay_seconds': 60,
        'media_queue_last_skip_reason': 'image_extraction_timeout',
      },
    });

    expect(status.workerId, 'worker-2');
    expect(status.mediaQueueDepth, 3);
    expect(status.mediaQueueOldestWaitSeconds, 45);
    expect(status.mediaQueueEstimatedNextDelaySeconds, 60);
    expect(status.mediaQueueLastSkipReason, 'image_extraction_timeout');
  });
}
