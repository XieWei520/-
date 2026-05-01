import 'package:wukongimfluttersdk/entity/msg.dart';

import 'message_alert_plan.dart';

typedef WebMessageAlertPlan = MessageAlertPlan;

WebMessageAlertPlan? buildWebMessageAlertPlan(
  WKMsg message, {
  required String currentUid,
}) {
  return buildMessageAlertPlan(message, currentUid: currentUid);
}

bool shouldTriggerWebMessageAlert(WKMsg message, {required String currentUid}) {
  return shouldTriggerMessageAlert(message, currentUid: currentUid);
}
