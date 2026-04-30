import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class ErrorLogsPage extends StatelessWidget {
  const ErrorLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WKSubPageScaffold(
      title: '错误日志',
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '当前平台不支持读取本地错误日志。',
            style: TextStyle(color: WKColors.color999),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
