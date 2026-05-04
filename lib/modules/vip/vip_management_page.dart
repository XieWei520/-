import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class VipManagementPage extends StatelessWidget {
  const VipManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WKSubPageScaffold(
      title: '管理系统',
      body: Center(
        child: Text(
          '暂无可管理内容',
          style: TextStyle(fontSize: 14, color: WKColors.color999),
        ),
      ),
    );
  }
}
